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

open! Stdlib

(** Lua Reserved Words and Identifier Handling

    This module provides utilities for safely handling OCaml identifiers
    when generating Lua code. It handles:
    - Lua keywords that cannot be used as identifiers
    - Lua standard library globals that should be avoided
    - Name mangling to make OCaml identifiers safe for Lua
*)

(** Set of Lua keywords that are strictly reserved *)
let keywords =
  List.fold_left
    ~f:(fun acc x -> StringSet.add x acc)
    ~init:StringSet.empty
    [ (* Lua 5.1+ keywords *)
      "and"
    ; "break"
    ; "do"
    ; "else"
    ; "elseif"
    ; "end"
    ; "false"
    ; "for"
    ; "function"
    ; "goto" (* Lua 5.2+ *)
    ; "if"
    ; "in"
    ; "local"
    ; "nil"
    ; "not"
    ; "or"
    ; "repeat"
    ; "return"
    ; "then"
    ; "true"
    ; "until"
    ; "while"
    ]

(** Set of Lua standard library globals that should be avoided for safety *)
let standard_globals =
  List.fold_left
    ~f:(fun acc x -> StringSet.add x acc)
    ~init:StringSet.empty
    [ (* Basic functions *)
      "_G"
    ; "_VERSION"
    ; "assert"
    ; "collectgarbage"
    ; "dofile"
    ; "error"
    ; "getmetatable"
    ; "ipairs"
    ; "load"
    ; "loadfile"
    ; "next"
    ; "pairs"
    ; "pcall"
    ; "print"
    ; "rawequal"
    ; "rawget"
    ; "rawlen"
    ; "rawset"
    ; "require"
    ; "select"
    ; "setmetatable"
    ; "tonumber"
    ; "tostring"
    ; "type"
    ; "xpcall"
    ; (* Standard libraries *)
      "coroutine"
    ; "debug"
    ; "io"
    ; "math"
    ; "os"
    ; "package"
    ; "string"
    ; "table"
    ; "utf8" (* Lua 5.3+ *)
    ; (* Commonly provided globals in LuaJIT *)
      "bit"
    ; "jit"
    ; "ffi"
    ]

(** Check if an identifier is a Lua keyword *)
let is_keyword s = StringSet.mem s keywords

(** Check if an identifier is a Lua standard global *)
let is_standard_global s = StringSet.mem s standard_globals

(** Check if an identifier is reserved (keyword or standard global) *)
let is_reserved s = is_keyword s || is_standard_global s

(** Check if a character is valid as the first character of a Lua identifier *)
let is_valid_first_char c =
  match c with
  | 'a' .. 'z' | 'A' .. 'Z' | '_' -> true
  | _ -> false

(** Check if a character is valid in a Lua identifier *)
let is_valid_identifier_char c =
  match c with
  | 'a' .. 'z' | 'A' .. 'Z' | '_' | '0' .. '9' -> true
  | _ -> false

(** Check if a string is a valid Lua identifier (syntactically) *)
let is_valid_identifier s =
  String.length s > 0
  && is_valid_first_char s.[0]
  && String.for_all ~f:is_valid_identifier_char s

(** Mangle a single invalid character to a valid Lua identifier sequence *)
let mangle_char c =
  match c with
  | '$' -> "__dollar__"
  | '@' -> "__at__"
  | '.' -> "__dot__"
  | '-' -> "__dash__"
  | '+' -> "__plus__"
  | '*' -> "__star__"
  | '/' -> "__slash__"
  | '\\' -> "__backslash__"
  | '!' -> "__bang__"
  | '?' -> "__question__"
  | '<' -> "__lt__"
  | '>' -> "__gt__"
  | '=' -> "__eq__"
  | '&' -> "__amp__"
  | '|' -> "__pipe__"
  | '^' -> "__caret__"
  | '~' -> "__tilde__"
  | '%' -> "__percent__"
  | '#' -> "__hash__"
  | ':' -> "__colon__"
  | ';' -> "__semi__"
  | ',' -> "__comma__"
  | '\'' -> "__quote__"
  | '"' -> "__dquote__"
  | '`' -> "__backtick__"
  | '(' -> "__lparen__"
  | ')' -> "__rparen__"
  | '[' -> "__lbrack__"
  | ']' -> "__rbrack__"
  | '{' -> "__lbrace__"
  | '}' -> "__rbrace__"
  | ' ' -> "__space__"
  | '\t' -> "__tab__"
  | '\n' -> "__newline__"
  | '\r' -> "__return__"
  | _ ->
      (* For any other character, use hex encoding *)
      Printf.sprintf "__x%02x__" (Char.code c)

(** Mangle an identifier to make it safe for Lua

    Strategy:
    1. If the identifier is a Lua keyword or standard global, prefix with "_"
    2. If the identifier contains invalid characters, replace them with mangled sequences
    3. If the identifier starts with a digit, prefix with "_"
*)
let mangle_name name =
  if String.length name = 0
  then "_empty_"
  else
    (* First check if it's reserved *)
    let name =
      if is_reserved name
      then "_" ^ name
      else name
    in
    (* Check if it needs character mangling *)
    if is_valid_identifier name
    then name
    else
      (* Need to mangle invalid characters *)
      let buf = Buffer.create (String.length name * 2) in
      (* If starts with a digit, add prefix *)
      (match name.[0] with
      | '0' .. '9' -> Buffer.add_string buf "_"
      | _ -> ());
      String.iter
        ~f:(fun c ->
          if is_valid_identifier_char c
          then Buffer.add_char buf c
          else Buffer.add_string buf (mangle_char c))
        name;
      Buffer.contents buf

(** Safely create a Lua identifier from an OCaml identifier *)
let safe_identifier s = mangle_name s

(** Create a fresh identifier by appending a numeric suffix *)
let fresh_identifier base n =
  let mangled_base = mangle_name base in
  Printf.sprintf "%s_%d" mangled_base n
