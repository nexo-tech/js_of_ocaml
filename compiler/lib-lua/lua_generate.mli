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

val generate_last_with_program : context -> Code.program -> Code.last -> Lua_ast.stat list
(** Generate Lua statement(s) from Code last with program context for inline blocks
    @param context Code generation context
    @param program Full program for block lookup
    @param last IR terminator
    @return List of Lua statements *)

val generate_block_with_program : context -> Code.program -> Code.block -> Lua_ast.stat list
(** Generate Lua block with program context for inline conditionals
    @param context Code generation context
    @param program Full program for block lookup
    @param block IR block
    @return List of Lua statements *)

val generate : debug:bool -> Code.program -> Lua_ast.stat list
(** [generate ~debug program] generates Lua code from an OCaml IR program.
    @param debug Enable debug output in generated code
    @param program OCaml intermediate representation
    @return List of Lua statements *)

val generate_to_string : debug:bool -> Code.program -> string
(** [generate_to_string ~debug program] generates Lua code and converts to string.
    @param debug Enable debug output
    @param program OCaml IR program
    @return Lua code as string *)
