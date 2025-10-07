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

(** Lua code pretty printer

    This module converts Lua AST to formatted Lua code.
    Based on the pattern from compiler/lib/js_output.ml.
*)

open Lua_ast

(** {2 Output Context} *)

(** Output context for managing indentation and buffer *)
type context =
  { mutable indent : int  (** Current indentation level *)
  ; mutable col : int  (** Current column position *)
  ; mutable line : int  (** Current line number *)
  ; buffer : Buffer.t  (** Output buffer *)
  }

(** Create a new output context *)
let make_context () =
  { indent = 0; col = 0; line = 1; buffer = Buffer.create 1024 }

(** Get the output string from context *)
let get_output ctx = Buffer.contents ctx.buffer

(** {2 Basic Output Functions} *)

(** Output a string *)
let output_string ctx s =
  Buffer.add_string ctx.buffer s;
  ctx.col <- ctx.col + String.length s

(** Output a character *)
let output_char ctx c =
  Buffer.add_char ctx.buffer c;
  ctx.col <- ctx.col + 1

(** Output a newline and reset column *)
let newline ctx =
  Buffer.add_char ctx.buffer '\n';
  ctx.line <- ctx.line + 1;
  ctx.col <- 0

(** Output indentation (2 spaces per level) *)
let output_indent ctx =
  for _ = 1 to ctx.indent * 2 do
    Buffer.add_char ctx.buffer ' ';
    ctx.col <- ctx.col + 1
  done

(** Increase indentation level *)
let indent ctx = ctx.indent <- ctx.indent + 1

(** Decrease indentation level *)
let unindent ctx = ctx.indent <- ctx.indent - 1

(** {2 Operator Precedence} *)

(** Lua operator precedence levels (higher = tighter binding)
    Based on Lua 5.1+ reference manual:
    1: or
    2: and
    3: <, >, <=, >=, ~=, ==
    4: ..
    5: +, -
    6: *, /, %
    7: unary (not, #, -, ~)
    8: ^
*)

let precedence_of_binop = function
  | Or -> 1
  | And -> 2
  | Eq | Neq | Lt | Le | Gt | Ge -> 3
  | Concat -> 4
  | Add | Sub -> 5
  | Mul | Div | IDiv | Mod -> 6
  | Pow -> 8
  | BAnd | BOr | BXor | Shl | Shr -> 3

let precedence_of_unop = function
  | Not | Neg | BNot | Len -> 7

(** {2 Expression Output} *)

(** Output expression with precedence-aware parenthesization *)
let rec output_expr ctx prec expr =
  match expr with
  | Nil -> output_string ctx "nil"
  | Bool true -> output_string ctx "true"
  | Bool false -> output_string ctx "false"
  | Number n -> output_string ctx n
  | String s -> output_string_literal ctx s
  | Ident id -> output_string ctx id
  | Vararg -> output_string ctx "..."
  | Index (tbl, key) ->
      output_expr ctx 100 tbl;
      output_char ctx '[';
      output_expr ctx 0 key;
      output_char ctx ']'
  | Dot (obj, field) ->
      output_expr ctx 100 obj;
      output_char ctx '.';
      output_string ctx field
  | Table fields -> output_table ctx fields
  | BinOp (op, e1, e2) -> output_binop ctx prec op e1 e2
  | UnOp (op, e) -> output_unop ctx prec op e
  | Call (f, args) -> output_call ctx f args
  | Method_call (obj, method_name, args) -> output_method_call ctx obj method_name args
  | Function (params, has_vararg, body) -> output_function ctx params has_vararg body

(** Output string literal with proper escaping *)
and output_string_literal ctx s =
  output_char ctx '"';
  String.iter
    (fun c ->
      match c with
      | '"' -> output_string ctx "\\\""
      | '\\' -> output_string ctx "\\\\"
      | '\n' -> output_string ctx "\\n"
      | '\r' -> output_string ctx "\\r"
      | '\t' -> output_string ctx "\\t"
      | c -> output_char ctx c)
    s;
  output_char ctx '"'

(** Output table constructor *)
and output_table ctx fields =
  output_char ctx '{';
  output_table_fields ctx fields;
  output_char ctx '}'

and output_table_fields ctx = function
  | [] -> ()
  | [ field ] -> output_table_field ctx field
  | field :: rest ->
      output_table_field ctx field;
      output_string ctx ", ";
      output_table_fields ctx rest

and output_table_field ctx = function
  | Array_field e -> output_expr ctx 0 e
  | Rec_field (name, value) ->
      output_string ctx name;
      output_string ctx " = ";
      output_expr ctx 0 value
  | General_field (key, value) ->
      output_char ctx '[';
      output_expr ctx 0 key;
      output_string ctx "] = ";
      output_expr ctx 0 value

(** Output binary operation with parenthesization *)
and output_binop ctx prec op e1 e2 =
  let op_prec = precedence_of_binop op in
  let needs_paren = prec > op_prec in
  if needs_paren then output_char ctx '(';
  output_expr ctx op_prec e1;
  output_char ctx ' ';
  output_string ctx (string_of_binop op);
  output_char ctx ' ';
  output_expr ctx (op_prec + 1) e2;
  if needs_paren then output_char ctx ')'

(** Output unary operation with parenthesization *)
and output_unop ctx prec op e =
  let op_prec = precedence_of_unop op in
  let needs_paren = prec > op_prec in
  if needs_paren then output_char ctx '(';
  output_string ctx (string_of_unop op);
  (match op with
  | Not -> output_char ctx ' '
  | _ -> ());
  output_expr ctx (op_prec + 1) e;
  if needs_paren then output_char ctx ')'

(** Output function call *)
and output_call ctx f args =
  output_expr ctx 100 f;
  output_char ctx '(';
  output_expr_list ctx args;
  output_char ctx ')'

(** Output method call *)
and output_method_call ctx obj method_name args =
  output_expr ctx 100 obj;
  output_char ctx ':';
  output_string ctx method_name;
  output_char ctx '(';
  output_expr_list ctx args;
  output_char ctx ')'

(** Output function expression *)
and output_function ctx params has_vararg body =
  output_string ctx "function(";
  output_param_list ctx params has_vararg;
  output_char ctx ')';
  newline ctx;
  indent ctx;
  output_block_internal ctx body;
  unindent ctx;
  output_indent ctx;
  output_string ctx "end"

(** Output parameter list *)
and output_param_list ctx params has_vararg =
  match params, has_vararg with
  | [], false -> ()
  | [], true -> output_string ctx "..."
  | params, false -> output_ident_list ctx params
  | params, true ->
      output_ident_list ctx params;
      output_string ctx ", ..."

(** Output list of expressions *)
and output_expr_list ctx = function
  | [] -> ()
  | [ e ] -> output_expr ctx 0 e
  | e :: rest ->
      output_expr ctx 0 e;
      output_string ctx ", ";
      output_expr_list ctx rest

(** Output list of identifiers *)
and output_ident_list ctx = function
  | [] -> ()
  | [ id ] -> output_string ctx id
  | id :: rest ->
      output_string ctx id;
      output_string ctx ", ";
      output_ident_list ctx rest

(** Convert binary operator to string *)
and string_of_binop = function
  | Add -> "+"
  | Sub -> "-"
  | Mul -> "*"
  | Div -> "/"
  | IDiv -> "//"
  | Mod -> "%"
  | Pow -> "^"
  | Concat -> ".."
  | Eq -> "=="
  | Neq -> "~="
  | Lt -> "<"
  | Le -> "<="
  | Gt -> ">"
  | Ge -> ">="
  | And -> "and"
  | Or -> "or"
  | BAnd -> "&"
  | BOr -> "|"
  | BXor -> "~"
  | Shl -> "<<"
  | Shr -> ">>"

(** Convert unary operator to string *)
and string_of_unop = function
  | Not -> "not"
  | Neg -> "-"
  | BNot -> "~"
  | Len -> "#"

(** {2 Statement Output} *)

(** Internal helper for outputting blocks within expressions *)
and output_block_internal ctx stmts =
  List.iter
    (fun stmt ->
      output_stat ctx stmt;
      newline ctx)
    stmts

(** Output a statement with proper indentation *)
and output_stat ctx stat =
  output_indent ctx;
  match stat with
  | Local (vars, None) ->
      output_string ctx "local ";
      output_ident_list ctx vars
  | Local (vars, Some exprs) ->
      output_string ctx "local ";
      output_ident_list ctx vars;
      output_string ctx " = ";
      output_expr_list ctx exprs
  | Assign (lhs, rhs) ->
      output_expr_list ctx lhs;
      output_string ctx " = ";
      output_expr_list ctx rhs
  | Function_decl (name, params, has_vararg, body) ->
      output_string ctx "function ";
      output_string ctx name;
      output_char ctx '(';
      output_param_list ctx params has_vararg;
      output_char ctx ')';
      newline ctx;
      indent ctx;
      output_block_internal ctx body;
      unindent ctx;
      output_indent ctx;
      output_string ctx "end"
  | Local_function (name, params, has_vararg, body) ->
      output_string ctx "local function ";
      output_string ctx name;
      output_char ctx '(';
      output_param_list ctx params has_vararg;
      output_char ctx ')';
      newline ctx;
      indent ctx;
      output_block_internal ctx body;
      unindent ctx;
      output_indent ctx;
      output_string ctx "end"
  | If (cond, then_block, else_block) ->
      output_string ctx "if ";
      output_expr ctx 0 cond;
      output_string ctx " then";
      newline ctx;
      indent ctx;
      output_block_internal ctx then_block;
      unindent ctx;
      (match else_block with
      | None ->
          output_indent ctx;
          output_string ctx "end"
      | Some else_stmts ->
          output_indent ctx;
          output_string ctx "else";
          newline ctx;
          indent ctx;
          output_block_internal ctx else_stmts;
          unindent ctx;
          output_indent ctx;
          output_string ctx "end")
  | While (cond, body) ->
      output_string ctx "while ";
      output_expr ctx 0 cond;
      output_string ctx " do";
      newline ctx;
      indent ctx;
      output_block_internal ctx body;
      unindent ctx;
      output_indent ctx;
      output_string ctx "end"
  | Repeat (body, cond) ->
      output_string ctx "repeat";
      newline ctx;
      indent ctx;
      output_block_internal ctx body;
      unindent ctx;
      output_indent ctx;
      output_string ctx "until ";
      output_expr ctx 0 cond
  | For_num (var, start, limit, step, body) ->
      output_string ctx "for ";
      output_string ctx var;
      output_string ctx " = ";
      output_expr ctx 0 start;
      output_string ctx ", ";
      output_expr ctx 0 limit;
      (match step with
      | None -> ()
      | Some s ->
          output_string ctx ", ";
          output_expr ctx 0 s);
      output_string ctx " do";
      newline ctx;
      indent ctx;
      output_block_internal ctx body;
      unindent ctx;
      output_indent ctx;
      output_string ctx "end"
  | For_in (vars, exprs, body) ->
      output_string ctx "for ";
      output_ident_list ctx vars;
      output_string ctx " in ";
      output_expr_list ctx exprs;
      output_string ctx " do";
      newline ctx;
      indent ctx;
      output_block_internal ctx body;
      unindent ctx;
      output_indent ctx;
      output_string ctx "end"
  | Break -> output_string ctx "break"
  | Return exprs ->
      output_string ctx "return";
      (match exprs with
      | [] -> ()
      | _ ->
          output_char ctx ' ';
          output_expr_list ctx exprs)
  | Goto label ->
      output_string ctx "goto ";
      output_string ctx label
  | Label label ->
      output_string ctx "::";
      output_string ctx label;
      output_string ctx "::"
  | Call_stat e -> output_expr ctx 0 e
  | Block body ->
      output_string ctx "do";
      newline ctx;
      indent ctx;
      output_block_internal ctx body;
      unindent ctx;
      output_indent ctx;
      output_string ctx "end"
  | Comment text ->
      output_string ctx "-- ";
      output_string ctx text

(** Output a block (list of statements) - top-level *)
let output_block ctx stmts = output_block_internal ctx stmts

(** {2 Program Output} *)

(** Output a complete program *)
let output_program ctx program =
  output_block_internal ctx program;
  get_output ctx

(** Convert a program to a string *)
let program_to_string program =
  let ctx = make_context () in
  output_program ctx program

(** Convert an expression to a string *)
let expr_to_string e =
  let ctx = make_context () in
  output_expr ctx 0 e;
  get_output ctx

(** Convert a statement to a string *)
let stat_to_string s =
  let ctx = make_context () in
  output_stat ctx s;
  get_output ctx

(** Simple API for writing to a buffer *)
let expr buf e =
  let ctx = { indent = 0; col = 0; line = 1; buffer = buf } in
  output_expr ctx 0 e

let stat buf s =
  let ctx = { indent = 0; col = 0; line = 1; buffer = buf } in
  output_stat ctx s
