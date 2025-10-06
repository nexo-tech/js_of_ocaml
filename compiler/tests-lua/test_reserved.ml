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

(** Tests for Lua Reserved Words and Identifier Handling *)

module Lua_reserved = struct
  include Lua_of_ocaml_compiler__Lua_reserved
end

(** Test that Lua keywords are properly identified *)
let test_keywords () =
  (* All Lua keywords should be detected *)
  assert (Lua_reserved.is_keyword "and");
  assert (Lua_reserved.is_keyword "break");
  assert (Lua_reserved.is_keyword "do");
  assert (Lua_reserved.is_keyword "else");
  assert (Lua_reserved.is_keyword "elseif");
  assert (Lua_reserved.is_keyword "end");
  assert (Lua_reserved.is_keyword "false");
  assert (Lua_reserved.is_keyword "for");
  assert (Lua_reserved.is_keyword "function");
  assert (Lua_reserved.is_keyword "goto");
  assert (Lua_reserved.is_keyword "if");
  assert (Lua_reserved.is_keyword "in");
  assert (Lua_reserved.is_keyword "local");
  assert (Lua_reserved.is_keyword "nil");
  assert (Lua_reserved.is_keyword "not");
  assert (Lua_reserved.is_keyword "or");
  assert (Lua_reserved.is_keyword "repeat");
  assert (Lua_reserved.is_keyword "return");
  assert (Lua_reserved.is_keyword "then");
  assert (Lua_reserved.is_keyword "true");
  assert (Lua_reserved.is_keyword "until");
  assert (Lua_reserved.is_keyword "while");
  (* Non-keywords should not be detected *)
  assert (not (Lua_reserved.is_keyword "foo"));
  assert (not (Lua_reserved.is_keyword "bar"));
  assert (not (Lua_reserved.is_keyword "myvar"))

(** Test that Lua standard globals are properly identified *)
let test_standard_globals () =
  (* Common standard globals *)
  assert (Lua_reserved.is_standard_global "_G");
  assert (Lua_reserved.is_standard_global "assert");
  assert (Lua_reserved.is_standard_global "print");
  assert (Lua_reserved.is_standard_global "require");
  assert (Lua_reserved.is_standard_global "pairs");
  assert (Lua_reserved.is_standard_global "ipairs");
  assert (Lua_reserved.is_standard_global "tostring");
  assert (Lua_reserved.is_standard_global "tonumber");
  (* Standard library tables *)
  assert (Lua_reserved.is_standard_global "math");
  assert (Lua_reserved.is_standard_global "string");
  assert (Lua_reserved.is_standard_global "table");
  assert (Lua_reserved.is_standard_global "io");
  assert (Lua_reserved.is_standard_global "os");
  assert (Lua_reserved.is_standard_global "coroutine");
  assert (Lua_reserved.is_standard_global "debug");
  assert (Lua_reserved.is_standard_global "package");
  assert (Lua_reserved.is_standard_global "utf8");
  (* Non-globals *)
  assert (not (Lua_reserved.is_standard_global "foo"));
  assert (not (Lua_reserved.is_standard_global "myfunction"))

(** Test that reserved words are properly detected *)
let test_reserved () =
  (* Keywords are reserved *)
  assert (Lua_reserved.is_reserved "if");
  assert (Lua_reserved.is_reserved "then");
  assert (Lua_reserved.is_reserved "end");
  (* Standard globals are reserved *)
  assert (Lua_reserved.is_reserved "print");
  assert (Lua_reserved.is_reserved "math");
  assert (Lua_reserved.is_reserved "string");
  (* Non-reserved identifiers *)
  assert (not (Lua_reserved.is_reserved "foo"));
  assert (not (Lua_reserved.is_reserved "bar"));
  assert (not (Lua_reserved.is_reserved "myvar"))

(** Test identifier character validation *)
let test_identifier_chars () =
  (* Valid first characters *)
  assert (Lua_reserved.is_valid_first_char 'a');
  assert (Lua_reserved.is_valid_first_char 'z');
  assert (Lua_reserved.is_valid_first_char 'A');
  assert (Lua_reserved.is_valid_first_char 'Z');
  assert (Lua_reserved.is_valid_first_char '_');
  (* Invalid first characters *)
  assert (not (Lua_reserved.is_valid_first_char '0'));
  assert (not (Lua_reserved.is_valid_first_char '9'));
  assert (not (Lua_reserved.is_valid_first_char '$'));
  assert (not (Lua_reserved.is_valid_first_char '-'));
  (* Valid identifier characters *)
  assert (Lua_reserved.is_valid_identifier_char 'a');
  assert (Lua_reserved.is_valid_identifier_char 'Z');
  assert (Lua_reserved.is_valid_identifier_char '_');
  assert (Lua_reserved.is_valid_identifier_char '0');
  assert (Lua_reserved.is_valid_identifier_char '9');
  (* Invalid identifier characters *)
  assert (not (Lua_reserved.is_valid_identifier_char '$'));
  assert (not (Lua_reserved.is_valid_identifier_char '-'));
  assert (not (Lua_reserved.is_valid_identifier_char '.'));
  assert (not (Lua_reserved.is_valid_identifier_char ' '))

(** Test syntactic validation of identifiers *)
let test_valid_identifiers () =
  (* Valid identifiers *)
  assert (Lua_reserved.is_valid_identifier "foo");
  assert (Lua_reserved.is_valid_identifier "bar123");
  assert (Lua_reserved.is_valid_identifier "_test");
  assert (Lua_reserved.is_valid_identifier "MyVar");
  assert (Lua_reserved.is_valid_identifier "a1b2c3");
  (* Invalid identifiers *)
  assert (not (Lua_reserved.is_valid_identifier ""));
  assert (not (Lua_reserved.is_valid_identifier "123foo"));
  assert (not (Lua_reserved.is_valid_identifier "foo-bar"));
  assert (not (Lua_reserved.is_valid_identifier "foo$bar"));
  assert (not (Lua_reserved.is_valid_identifier "foo.bar"));
  assert (not (Lua_reserved.is_valid_identifier "foo bar"))

(** Test name mangling for reserved words *)
let test_mangle_reserved () =
  (* Keywords get prefixed *)
  assert (Lua_reserved.mangle_name "if" = "_if");
  assert (Lua_reserved.mangle_name "then" = "_then");
  assert (Lua_reserved.mangle_name "end" = "_end");
  assert (Lua_reserved.mangle_name "local" = "_local");
  assert (Lua_reserved.mangle_name "function" = "_function");
  (* Standard globals get prefixed *)
  assert (Lua_reserved.mangle_name "print" = "_print");
  assert (Lua_reserved.mangle_name "math" = "_math");
  assert (Lua_reserved.mangle_name "string" = "_string");
  assert (Lua_reserved.mangle_name "require" = "_require")

(** Test name mangling for invalid characters *)
let test_mangle_chars () =
  (* Dollar signs *)
  assert (Lua_reserved.mangle_name "foo$bar" = "foo__dollar__bar");
  assert (Lua_reserved.mangle_name "$name" = "__dollar__name");
  (* Dashes *)
  assert (Lua_reserved.mangle_name "foo-bar" = "foo__dash__bar");
  (* Dots *)
  assert (Lua_reserved.mangle_name "foo.bar" = "foo__dot__bar");
  (* Special characters *)
  assert (Lua_reserved.mangle_name "foo@bar" = "foo__at__bar");
  assert (Lua_reserved.mangle_name "foo+bar" = "foo__plus__bar");
  assert (Lua_reserved.mangle_name "foo*bar" = "foo__star__bar");
  (* Starting with digit *)
  assert (Lua_reserved.mangle_name "123foo" = "_123foo");
  assert (Lua_reserved.mangle_name "9test" = "_9test")

(** Test name mangling for valid identifiers *)
let test_mangle_valid () =
  (* Valid non-reserved identifiers should not be changed *)
  assert (Lua_reserved.mangle_name "foo" = "foo");
  assert (Lua_reserved.mangle_name "bar123" = "bar123");
  assert (Lua_reserved.mangle_name "_test" = "_test");
  assert (Lua_reserved.mangle_name "MyVar" = "MyVar");
  assert (Lua_reserved.mangle_name "a1b2c3" = "a1b2c3")

(** Test edge cases *)
let test_edge_cases () =
  (* Empty string *)
  assert (Lua_reserved.mangle_name "" = "_empty_");
  (* Multiple special characters *)
  assert (Lua_reserved.mangle_name "foo$bar.baz" = "foo__dollar__bar__dot__baz");
  (* Reserved word with special chars (reserved check happens first) *)
  assert (Lua_reserved.mangle_name "if" = "_if")

(** Test safe identifier creation *)
let test_safe_identifier () =
  (* Should behave like mangle_name *)
  assert (Lua_reserved.safe_identifier "foo" = "foo");
  assert (Lua_reserved.safe_identifier "if" = "_if");
  assert (Lua_reserved.safe_identifier "foo$bar" = "foo__dollar__bar");
  assert (Lua_reserved.safe_identifier "123test" = "_123test")

(** Test fresh identifier generation *)
let test_fresh_identifier () =
  (* Should append numeric suffix and mangle *)
  assert (Lua_reserved.fresh_identifier "tmp" 0 = "tmp_0");
  assert (Lua_reserved.fresh_identifier "tmp" 1 = "tmp_1");
  assert (Lua_reserved.fresh_identifier "tmp" 99 = "tmp_99");
  (* Should mangle the base if needed *)
  assert (Lua_reserved.fresh_identifier "if" 0 = "_if_0");
  assert (Lua_reserved.fresh_identifier "foo$bar" 1 = "foo__dollar__bar_1")

(** Test OCaml stdlib names can be safely used *)
let test_ocaml_stdlib_names () =
  (* Common OCaml stdlib module names *)
  let stdlib_names =
    [ "List"
    ; "Array"
    ; "String"
    ; "Bytes"
    ; "Hashtbl"
    ; "Map"
    ; "Set"
    ; "Queue"
    ; "Stack"
    ; "Buffer"
    ; "Printf"
    ; "Format"
    ; "Sys"
    ; "Unix"
    ; "Filename"
    ; "Pervasives"
    ; "Option"
    ; "Result"
    ; "Int"
    ; "Float"
    ; "Bool"
    ; "Char"
    ]
  in
  (* All should be mangled to valid Lua identifiers *)
  List.iter
    (fun name ->
      let mangled = Lua_reserved.mangle_name name in
      assert (Lua_reserved.is_valid_identifier mangled))
    stdlib_names;
  (* Most should not conflict with Lua reserved words (Lua is case-sensitive) *)
  assert (Lua_reserved.mangle_name "List" = "List");
  assert (Lua_reserved.mangle_name "Array" = "Array");
  assert (Lua_reserved.mangle_name "Hashtbl" = "Hashtbl");
  assert (Lua_reserved.mangle_name "String" = "String");
  (* lowercase "string" conflicts with Lua standard global *)
  assert (Lua_reserved.mangle_name "string" = "_string")

(** Run all tests *)
let () =
  test_keywords ();
  test_standard_globals ();
  test_reserved ();
  test_identifier_chars ();
  test_valid_identifiers ();
  test_mangle_reserved ();
  test_mangle_chars ();
  test_mangle_valid ();
  test_edge_cases ();
  test_safe_identifier ();
  test_fresh_identifier ();
  test_ocaml_stdlib_names ();
  print_endline "All reserved word tests passed!"
