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

(** Lua Abstract Syntax Tree

    This module defines the AST for Lua code generation.
    The design follows Lua 5.1+ syntax and mirrors the JavaScript AST structure
    from compiler/lib/javascript.ml.
*)

(** {2 Basic Types} *)

(** Lua identifier - simple string for now *)
type ident = string

(** {2 Operators} *)

(** Binary operators *)
type binop =
  (* Arithmetic operators *)
  | Add  (** + *)
  | Sub  (** - *)
  | Mul  (** * *)
  | Div  (** / *)
  | IDiv  (** // (Lua 5.3+) *)
  | Mod  (** % *)
  | Pow  (** ^ *)
  (* String operator *)
  | Concat  (** .. *)
  (* Relational operators *)
  | Eq  (** == *)
  | Neq  (** ~= *)
  | Lt  (** < *)
  | Le  (** <= *)
  | Gt  (** > *)
  | Ge  (** >= *)
  (* Logical operators *)
  | And  (** and *)
  | Or  (** or *)
  (* Bitwise operators (Lua 5.3+) *)
  | BAnd  (** & *)
  | BOr  (** | *)
  | BXor  (** ~ *)
  | Shl  (** << *)
  | Shr  (** >> *)

(** Unary operators *)
type unop =
  | Not  (** not *)
  | Neg  (** - (unary minus) *)
  | BNot  (** ~ (bitwise not, Lua 5.3+) *)
  | Len  (** # (length operator) *)

(** {2 Expressions and Table Fields} *)

(** Lua expression *)
type expr =
  (* Literals *)
  | Nil  (** nil *)
  | Bool of bool  (** true / false *)
  | Number of string  (** numeric literal stored as string like Javascript.Num *)
  | String of string  (** string literal *)
  (* Variables and access *)
  | Ident of ident  (** variable reference *)
  | Index of expr * expr  (** table[key] *)
  | Dot of expr * ident  (** table.field *)
  (* Table constructor *)
  | Table of table_field list  (** {fields} - table constructor *)
  (* Operations *)
  | BinOp of binop * expr * expr  (** binary operation *)
  | UnOp of unop * expr  (** unary operation *)
  (* Function calls *)
  | Call of expr * expr list  (** func(args) *)
  | Method_call of expr * ident * expr list  (** obj:method(args) *)
  (* Function definition *)
  | Function of ident list * bool * block  (** function(params) body end - params, has_vararg, body *)
  (* Vararg *)
  | Vararg  (** ... - vararg expression *)

(** Table field in table constructor *)
and table_field =
  | Array_field of expr  (** {expr} - array-style field *)
  | Rec_field of ident * expr  (** {name = expr} - record-style field *)
  | General_field of expr * expr  (** {[key] = value} - computed key field *)

(** {2 Statements} *)

(** Lua statement *)
and stat =
  (* Variable declarations and assignments *)
  | Local of ident list * expr list option  (** local x, y = e1, e2 *)
  | Assign of expr list * expr list  (** x, y = e1, e2 *)
  (* Function declarations *)
  | Function_decl of ident * ident list * bool * block
      (** function name(params) body end - name, params, has_vararg, body *)
  | Local_function of ident * ident list * bool * block
      (** local function name(params) body end - name, params, has_vararg, body *)
  (* Control flow *)
  | If of expr * block * block option  (** if expr then block else block end *)
  | While of expr * block  (** while expr do block end *)
  | Repeat of block * expr  (** repeat block until expr *)
  | For_num of ident * expr * expr * expr option * block
      (** for var = start, limit [, step] do block end *)
  | For_in of ident list * expr list * block
      (** for var1, var2 in exp1, exp2 do block end *)
  (* Jump statements *)
  | Break  (** break *)
  | Return of expr list  (** return e1, e2, ... *)
  | Goto of ident  (** goto label *)
  | Label of ident  (** ::label:: *)
  (* Other statements *)
  | Call_stat of expr  (** function call as statement *)
  | Block of block  (** do block end *)
  | Comment of string  (** -- comment *)
  | Location_hint of Parse_info.t  (** Debug location marker (not emitted) *)

(** Block is a list of statements *)
and block = stat list

(** Program is a block *)
type program = block

(** {2 Helper Constructors} *)

(** Nil literal *)
let nil = Nil

(** Boolean literal *)
let bool b = Bool b

(** Number literal from string *)
let number s = Number s

(** Number literal from int *)
let number_of_int n = Number (string_of_int n)

(** Number literal from float *)
let number_of_float f = Number (string_of_float f)

(** String literal *)
let string s = String s

(** Variable reference *)
let ident i = Ident i

(** Table field access *)
let dot obj field = Dot (obj, field)

(** Table index access *)
let index tbl key = Index (tbl, key)

(** Binary operation *)
let binop op e1 e2 = BinOp (op, e1, e2)

(** Unary operation *)
let unop op e = UnOp (op, e)

(** Function call *)
let call f args = Call (f, args)

(** Method call *)
let method_call obj meth args = Method_call (obj, meth, args)

(** Local variable declaration *)
let local vars exprs = Local (vars, exprs)

(** Assignment *)
let assign lhs rhs = Assign (lhs, rhs)

(** If statement *)
let if_ cond then_block else_block = If (cond, then_block, else_block)

(** While loop *)
let while_ cond body = While (cond, body)

(** Return statement *)
let return exprs = Return exprs

(** Function call statement *)
let call_stat e = Call_stat e

(** Block statement *)
let block stmts = Block stmts

(** {2 Table Constructors} *)

(** Array-style table field *)
let array_field e = Array_field e

(** Record-style table field *)
let rec_field name value = Rec_field (name, value)

(** General (computed key) table field *)
let general_field key value = General_field (key, value)

(** Table constructor *)
let table fields = Table fields

(** Empty table constructor *)
let empty_table = Table []

(** {2 Function Constructors} *)

(** Function expression *)
let function_ params has_vararg body = Function (params, has_vararg, body)

(** Function expression without vararg *)
let function_simple params body = Function (params, false, body)

(** Vararg expression *)
let vararg = Vararg

(** Function declaration statement *)
let function_decl name params has_vararg body =
  Function_decl (name, params, has_vararg, body)

(** Function declaration without vararg *)
let function_decl_simple name params body =
  Function_decl (name, params, false, body)

(** Local function declaration *)
let local_function name params has_vararg body =
  Local_function (name, params, has_vararg, body)

(** Local function declaration without vararg *)
let local_function_simple name params body =
  Local_function (name, params, false, body)

(** {2 Utility Functions} *)

(** Create a for loop with default step of 1 *)
let for_num var start limit body = For_num (var, start, limit, None, body)

(** Create a for loop with explicit step *)
let for_num_step var start limit step body =
  For_num (var, start, limit, Some step, body)

(** Create a generic for loop *)
let for_in vars exprs body = For_in (vars, exprs, body)
