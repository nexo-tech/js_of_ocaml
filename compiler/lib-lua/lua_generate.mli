(* Lua_of_ocaml compiler
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)

(** Lua Code Generation from OCaml IR *)

(** Code generation context - opaque for external use *)
type context

val make_context : debug:bool -> context
(** Create a new code generation context
    @param debug Enable debug output
    @return Fresh context *)

val make_context_with_program : debug:bool -> Code.program -> context
(** Create a context with program for closure generation
    @param debug Enable debug output
    @param program Full program for closure generation
    @return Context with program *)

val var_name : context -> Code.Var.t -> string
(** Get or create Lua variable name for an IR variable
    @param context Code generation context
    @param var IR variable
    @return Lua variable name *)

val generate_constant : Code.constant -> Lua_ast.expr
(** Generate Lua expression from Code constant
    @param const IR constant
    @return Lua expression *)

val generate_prim : context -> Code.prim -> Code.prim_arg list -> Lua_ast.expr
(** Generate Lua expression from Code prim operation
    @param context Code generation context
    @param prim Primitive operation
    @param args Primitive arguments
    @return Lua expression *)

val generate_expr : context -> Code.expr -> Lua_ast.expr
(** Generate Lua expression from Code expression
    @param context Code generation context
    @param expr IR expression
    @return Lua expression *)

val generate_instr : context -> Code.instr -> Lua_ast.stat
(** Generate Lua statement from Code instruction
    @param context Code generation context
    @param instr IR instruction
    @return Lua statement *)

val generate_instrs : context -> Code.instr list -> Lua_ast.stat list
(** Generate Lua statements from a list of Code instructions
    @param context Code generation context
    @param instrs List of IR instructions
    @return List of Lua statements *)

val generate_last : context -> Code.last -> Lua_ast.stat list
(** Generate Lua statement(s) from Code last (terminator)
    @param context Code generation context
    @param last IR terminator
    @return List of Lua statements *)

val generate_block : context -> Code.block -> Lua_ast.stat list
(** Generate Lua block from Code block
    @param context Code generation context
    @param block IR block
    @return List of Lua statements *)

val generate : debug:bool -> Code.program -> Lua_ast.stat list
(** [generate ~debug program] generates Lua code from an OCaml IR program.
    This generates a standalone program with initialization code.
    @param debug Enable debug output in generated code
    @param program OCaml intermediate representation
    @return List of Lua statements *)

val generate_module_code : debug:bool -> module_name:string -> Code.program -> Lua_ast.stat list
(** [generate_module_code ~debug ~module_name program] generates Lua module code
    for separate compilation. The generated code can be loaded via require().
    @param debug Enable debug output
    @param module_name Name of the module
    @param program OCaml IR program
    @return List of Lua statements forming a module *)

val generate_to_string : debug:bool -> Code.program -> string
(** [generate_to_string ~debug program] generates Lua code and converts to string.
    @param debug Enable debug output
    @param program OCaml IR program
    @return Lua code as string *)

val debug_print_program : Code.program -> unit
(** [debug_print_program program] prints detailed IR structure to stderr
    when the "ir" debug flag is enabled. Useful for debugging execution issues.
    @param program OCaml IR program to debug *)

val collect_used_primitives : Code.program -> Stdlib.StringSet.t
(** [collect_used_primitives program] traverses the program IR to find all
    external primitives (Code.Extern) that are called. These primitives will
    need runtime implementations or wrappers. Primitives are returned with
    the caml_ prefix added if not already present.
    @param program OCaml IR program
    @return Set of primitive names (with caml_ prefix) *)

val collect_block_variables : context -> Code.program -> int -> Stdlib.StringSet.t * Stdlib.StringSet.t
(** [collect_block_variables ctx program start_addr] collects all variables
    used in reachable blocks starting from start_addr, separating them into
    defined and free variables. This is used for variable hoisting to avoid
    Lua goto/scope violations and prevent variable shadowing in nested closures.
    @param ctx Code generation context
    @param program OCaml IR program
    @param start_addr Starting block address
    @return Tuple of (defined_vars, free_vars) where:
            - defined_vars: variables assigned/defined in this closure
            - free_vars: variables used but not defined (captured from parent) *)

val compile_blocks_with_labels :
  context ->
  Code.program ->
  int ->
  ?params:Code.Var.t list ->
  ?entry_args:Code.Var.t list ->
  ?func_params:Code.Var.t list ->
  unit ->
  Lua_ast.stat list
(** [compile_blocks_with_labels ctx program start_addr ~params ~entry_args ~func_params ()] compiles IR blocks into
    Lua statements with variable hoisting and dispatch loop. Variables are hoisted
    to the beginning to avoid Lua's local limit (200 locals).
    @param ctx Code generation context
    @param program OCaml IR program
    @param start_addr Starting block address
    @param params Optional function parameters (for param copying to _V table)
    @param entry_args Optional arguments to pass to entry block (for closures)
    @param func_params Optional function parameters list (to distinguish local vs captured vars)
    @return List of Lua statements with hoisted variables and dispatch loop *)

val generate_runtime_inline : unit -> string
(** [generate_runtime_inline ()] generates the minimal runtime code needed for basic operations.
    This includes core runtime functions like caml_register_global, caml_make_closure, etc.
    @return Runtime code as a string to be prepended to generated Lua output *)
