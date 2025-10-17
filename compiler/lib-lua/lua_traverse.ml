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

(** Lua AST Traversal

    This module provides visitor classes for traversing Lua AST.
    Modeled after compiler/lib/js_traverse.ml for JavaScript AST.

    Key differences from JavaScript:
    - Simpler scoping (only function and block scopes, no var/let/const)
    - No classes, imports, exports
    - No destructuring patterns
    - Simpler overall structure

    Reference: compiler/lib/js_traverse.ml:458-700 (iter class)
*)

open! Js_of_ocaml_compiler.Stdlib
module L = Lua_of_ocaml_compiler__Lua_ast

(** {2 Iterator Interface} *)

(** Base iterator interface for visiting Lua AST nodes *)
class type iterator = object
  method ident : L.ident -> unit
  method expression : L.expr -> unit
  method expression_list : L.expr list -> unit
  method table_field : L.table_field -> unit
  method statement : L.stat -> unit
  method statements : L.block -> unit
  method program : L.program -> unit
end

(** {2 Base Iterator Implementation} *)

(** Generic Lua AST iterator

    Visits all nodes in a Lua AST. Subclasses can override specific methods
    to customize behavior (e.g., collect variables, transform AST, etc.)

    Pattern follows js_traverse.ml:458-700 (iter class).
*)
class iter : iterator =
  object (m)
    method ident (_name : L.ident) = ()

    method expression (e : L.expr) =
      match e with
      | L.Nil -> ()
      | L.Bool _ -> ()
      | L.Number _ -> ()
      | L.String _ -> ()
      | L.Ident name -> m#ident name
      | L.Index (e1, e2) ->
          m#expression e1;
          m#expression e2
      | L.Dot (e, _field) ->
          m#expression e
          (* Note: field is an ident but not a variable reference, it's a table key *)
      | L.Table fields ->
          List.iter fields ~f:m#table_field
      | L.BinOp (_op, e1, e2) ->
          m#expression e1;
          m#expression e2
      | L.UnOp (_op, e) ->
          m#expression e
      | L.Call (func, args) ->
          m#expression func;
          m#expression_list args
      | L.Method_call (obj, _method, args) ->
          m#expression obj;
          (* Note: method name is not a variable reference *)
          m#expression_list args
      | L.Function (_params, _has_vararg, body) ->
          (* Note: params are identifiers but they're declarations, not references *)
          (* Subclasses (like fast_freevar) will override to handle scope *)
          m#statements body
      | L.Vararg -> ()

    method expression_list (exprs : L.expr list) =
      List.iter exprs ~f:m#expression

    method table_field (field : L.table_field) =
      match field with
      | L.Array_field e -> m#expression e
      | L.Rec_field (_name, e) ->
          (* Note: name is a table key, not a variable reference *)
          m#expression e
      | L.General_field (key, value) ->
          m#expression key;
          m#expression value

    method statement (s : L.stat) =
      match s with
      | L.Local (_names, exprs_opt) ->
          (* Note: names are declarations, not references *)
          (* Subclasses will handle scope *)
          (match exprs_opt with
          | None -> ()
          | Some exprs -> m#expression_list exprs)
      | L.Assign (targets, exprs) ->
          m#expression_list targets;
          m#expression_list exprs
      | L.Function_decl (_name, _params, _has_vararg, body) ->
          (* Note: name and params are declarations *)
          (* Subclasses will handle scope *)
          m#statements body
      | L.Local_function (_name, _params, _has_vararg, body) ->
          (* Note: name and params are declarations *)
          (* Subclasses will handle scope *)
          m#statements body
      | L.If (cond, then_block, else_block_opt) ->
          m#expression cond;
          m#statements then_block;
          (match else_block_opt with
          | None -> ()
          | Some else_block -> m#statements else_block)
      | L.While (cond, body) ->
          m#expression cond;
          m#statements body
      | L.Repeat (body, cond) ->
          m#statements body;
          m#expression cond
      | L.For_num (_var, start, limit, step_opt, body) ->
          (* Note: var is a declaration *)
          (* Subclasses will handle scope *)
          m#expression start;
          m#expression limit;
          (match step_opt with
          | None -> ()
          | Some step -> m#expression step);
          m#statements body
      | L.For_in (_vars, exprs, body) ->
          (* Note: vars are declarations *)
          (* Subclasses will handle scope *)
          m#expression_list exprs;
          m#statements body
      | L.Break -> ()
      | L.Return exprs -> m#expression_list exprs
      | L.Goto _label -> ()
      | L.Label _label -> ()
      | L.Call_stat e -> m#expression e
      | L.Block block -> m#statements block
      | L.Comment _ -> ()
      | L.Raw _ ->
          (* Raw Lua code - can't traverse into it *)
          ()
      | L.Location_hint _ -> ()

    method statements (block : L.block) =
      List.iter block ~f:m#statement

    method program (p : L.program) =
      m#statements p
  end

(** {2 Free Variable Collection} *)

(** Scan a block to find all variables declared in that scope

    Handles:
    - local declarations
    - function parameters
    - local function names
    - for loop variables

    Modeled after js_traverse.ml:1212-1333 (declared helper).

    @param params Function parameters (if in function scope)
    @param body Block to scan for declarations
    @return Set of declared variable names in this scope
*)
let declared (params : L.ident list) (body : L.block) : StringSet.t =
  let declared_names = ref StringSet.empty in
  let decl_var name = declared_names := StringSet.add name !declared_names in

  (* Add function parameters to declared set *)
  List.iter params ~f:decl_var;

  (* Scan statements for declarations *)
  let rec scan_statement (s : L.stat) =
    match s with
    | L.Local (names, _exprs_opt) ->
        (* local x, y = ... *)
        List.iter names ~f:decl_var
    | L.Local_function (name, _params, _has_vararg, _body) ->
        (* local function foo(...) ... end *)
        decl_var name
    | L.Function_decl (name, _params, _has_vararg, _body) ->
        (* function foo(...) ... end *)
        decl_var name
    | L.For_num (var, _start, _limit, _step_opt, _body) ->
        (* for i = 1, 10 do ... end *)
        decl_var var
    | L.For_in (vars, _exprs, _body) ->
        (* for k, v in pairs(t) do ... end *)
        List.iter vars ~f:decl_var
    | L.Block block ->
        (* do ... end - nested block, scan recursively *)
        List.iter block ~f:scan_statement
    | L.If (_cond, then_block, else_block_opt) ->
        (* Scan both branches *)
        List.iter then_block ~f:scan_statement;
        (match else_block_opt with
        | None -> ()
        | Some else_block -> List.iter else_block ~f:scan_statement)
    | L.While (_cond, body) ->
        List.iter body ~f:scan_statement
    | L.Repeat (body, _cond) ->
        List.iter body ~f:scan_statement
    | _ ->
        (* Other statements don't declare variables *)
        ()
  in

  List.iter body ~f:scan_statement;
  !declared_names

(** Collect free variables from a Lua program

    Modeled after js_traverse.ml:1335-1468 (fast_freevar class).

    Algorithm:
    1. Start with empty decl set (declared variables)
    2. For each scope (function/block):
       - Find all declarations in that scope
       - Create new traverser with decl = old_decl ∪ new_declarations
       - Traverse scope with updated traverser
    3. For each identifier reference:
       - If in decl → bound variable (skip)
       - If not in decl → free variable (collect it)

    @param f Callback function called for each free variable
    @return Unit (side effect: calls f for each free variable)
*)
class fast_freevar f =
  object (m)
    inherit iter as super

    (** Set of declared variables in current scope *)
    val decl = StringSet.empty

    (** Update scope with new declarations

        Creates a new traverser object with updated decl set.
        This is the key pattern from js_traverse.ml:1341-1343.

        @param params Function parameters (if entering function scope)
        @param body Block to scan for local declarations
        @return New traverser object with updated decl set
    *)
    method private update_state (params : L.ident list) (body : L.block) =
      let new_declarations = declared params body in
      let declared_names = StringSet.union decl new_declarations in
      {<decl = declared_names>}

    (** Override ident to check if it's free

        Modeled after js_traverse.ml:1345-1348.

        @param name Identifier name
    *)
    method ident (name : L.ident) : unit =
      if not (StringSet.mem name decl) then f name

    (** Override expression to handle function definitions

        Function definitions create new scopes.
        Modeled after js_traverse.ml:1367-1374.
    *)
    method expression (e : L.expr) =
      match e with
      | L.Function (params, _has_vararg, body) ->
          (* Create new scope with params declared *)
          let m' = m#update_state params body in
          m'#statements body
      | _ -> super#expression e

    (** Override statement to handle scope-creating statements

        Modeled after js_traverse.ml:1381-1467.
    *)
    method statement (s : L.stat) =
      match s with
      | L.Function_decl (name, params, _has_vararg, body) ->
          (* Declare function name in current scope *)
          m#ident name;
          (* Function body has new scope with params *)
          let m' = m#update_state params body in
          m'#statements body
      | L.Local_function (_name, params, _has_vararg, body) ->
          (* Local function: name is declared in current scope *)
          (* Note: name is already in decl via declared() scan *)
          (* Function body has new scope with params *)
          let m' = m#update_state params body in
          m'#statements body
      | L.Block block ->
          (* do ... end block creates new scope *)
          let m' = m#update_state [] block in
          m'#statements block
      | L.For_num (var, start, limit, step_opt, body) ->
          (* Evaluate expressions in current scope *)
          m#expression start;
          m#expression limit;
          (match step_opt with
          | None -> ()
          | Some step -> m#expression step);
          (* for variable is declared in loop body scope *)
          let m' = m#update_state [var] body in
          m'#statements body
      | L.For_in (vars, exprs, body) ->
          (* Evaluate iterator expressions in current scope *)
          m#expression_list exprs;
          (* Loop variables are declared in loop body scope *)
          let m' = m#update_state vars body in
          m'#statements body
      | L.Local (_names, exprs_opt) ->
          (* local x, y = expr1, expr2 *)
          (* Evaluate expressions in current scope (before declaration takes effect) *)
          (* Note: names are already in decl via declared() scan *)
          (match exprs_opt with
          | None -> ()
          | Some exprs -> m#expression_list exprs)
      | _ -> super#statement s

    (** Override program to start with module-level scope *)
    method program (p : L.program) =
      let m' = m#update_state [] p in
      m'#statements p
  end

(** Collect all free variables from a Lua program

    @param lua_ast Lua AST (program)
    @return StringSet of all free variable names
*)
let collect_free_vars (lua_ast : L.program) : StringSet.t =
  let free = ref StringSet.empty in
  let visitor = new fast_freevar (fun s -> free := StringSet.add s !free) in
  visitor#program lua_ast;
  !free
