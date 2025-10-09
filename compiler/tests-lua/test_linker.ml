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

(* Test suite for lua_link.ml linker functionality *)

(* Access the wrapped module *)
module Lua_link = struct
  include Lua_of_ocaml_compiler__Lua_link
end

(* Helper to print option *)
let print_option = function
  | Some s -> print_endline s
  | None -> print_endline "None"

(* Test parse_provides with single function - basic case *)
let%expect_test "parse provides comment - single function" =
  let result = Lua_link.parse_provides "--Provides: caml_array_make" in
  print_option result;
  [%expect {| caml_array_make |}]

(* Test parse_provides with whitespace handling *)
let%expect_test "parse provides comment - whitespace handling" =
  let result = Lua_link.parse_provides "--Provides:   caml_test_func  " in
  print_option result;
  [%expect {| caml_test_func |}]

(* Test parse_provides with no space after colon *)
let%expect_test "parse provides comment - no space after colon" =
  let result = Lua_link.parse_provides "--Provides:caml_foo" in
  print_option result;
  [%expect {| caml_foo |}]

(* Test parse_provides with regular comment (should return None) *)
let%expect_test "parse provides comment - not provides line" =
  let result = Lua_link.parse_provides "-- Regular comment" in
  print_option result;
  [%expect {| None |}]

(* Test parse_provides with empty provides *)
let%expect_test "parse provides comment - empty symbol" =
  let result = Lua_link.parse_provides "--Provides:   " in
  print_option result;
  [%expect {| None |}]

(* Test parse_provides with old format (should return None) *)
let%expect_test "parse provides comment - old format rejected" =
  let result = Lua_link.parse_provides "--// Provides: caml_foo" in
  print_option result;
  [%expect {| None |}]

(* Test parse_requires with single dependency *)
let%expect_test "parse requires comment - single dependency" =
  let result = Lua_link.parse_requires "--Requires: caml_make_vect" in
  print_endline (String.concat ", " result);
  [%expect {| caml_make_vect |}]

(* Test parse_requires with multiple dependencies *)
let%expect_test "parse requires comment - multiple dependencies" =
  let result = Lua_link.parse_requires "--Requires: caml_foo, caml_bar" in
  print_endline (String.concat ", " result);
  [%expect {| caml_foo, caml_bar |}]

(* Test parse_requires with whitespace *)
let%expect_test "parse requires comment - whitespace handling" =
  let result =
    Lua_link.parse_requires "--Requires:  caml_a ,  caml_b  , caml_c  "
  in
  print_endline (String.concat ", " result);
  [%expect {| caml_a, caml_b, caml_c |}]

(* Test parse_requires with old format (should return empty) *)
let%expect_test "parse requires comment - old format rejected" =
  let result = Lua_link.parse_requires "--// Requires: caml_foo" in
  print_endline
    (if List.length result = 0 then "EMPTY" else String.concat ", " result);
  [%expect {| EMPTY |}]

(* Test parse_fragment_header with simple function *)
let%expect_test "parse fragment header - simple function" =
  let code =
    "--Provides: caml_test\n\
     function caml_test()\n\
    \  return 42\n\
     end\n"
  in
  let frag = Lua_link.parse_fragment_header ~name:"test" code in
  print_endline ("name: " ^ frag.name);
  print_endline ("provides: " ^ String.concat ", " frag.provides);
  print_endline ("requires: " ^ String.concat ", " frag.requires);
  [%expect {|
    name: test
    provides: caml_test
    requires: |}]

(* Test parse_fragment_header with multiple provides *)
let%expect_test "parse fragment header - multiple provides" =
  let code =
    "--Provides: caml_array_make\n\
     --Provides: caml_array_get\n\
     --Requires: caml_make_vect\n\
     function caml_array_make(n, v)\n\
    \  return {}\n\
     end\n\
     function caml_array_get(arr, idx)\n\
    \  return arr[idx]\n\
     end\n"
  in
  let frag = Lua_link.parse_fragment_header ~name:"array" code in
  print_endline ("name: " ^ frag.name);
  print_endline ("provides: " ^ String.concat ", " frag.provides);
  print_endline ("requires: " ^ String.concat ", " frag.requires);
  [%expect {|
    name: array
    provides: caml_array_make, caml_array_get
    requires: caml_make_vect |}]

(* Test parse_fragment_header with no provides (defaults to name) *)
let%expect_test "parse fragment header - no provides defaults to name" =
  let code = "-- Just a comment\nfunction foo() end\n" in
  let frag = Lua_link.parse_fragment_header ~name:"default_name" code in
  print_endline ("provides: " ^ String.concat ", " frag.provides);
  [%expect {| provides: default_name |}]

(* Test parse_fragment_header stops at non-comment *)
let%expect_test "parse fragment header - stops at non-comment" =
  let code =
    "--Provides: caml_foo\n\
     function caml_foo() end\n\
     --Provides: caml_bar\n"
  in
  let frag = Lua_link.parse_fragment_header ~name:"test" code in
  print_endline ("provides: " ^ String.concat ", " frag.provides);
  [%expect {| provides: caml_foo |}]

(* Test parse_fragment_header with mixed old/new format *)
let%expect_test "parse fragment header - mixed formats" =
  let code =
    "--Provides: caml_new_func\n\
     --// Provides: old_func\n\
     --Requires: caml_dep\n\
     function caml_new_func() end\n"
  in
  let frag = Lua_link.parse_fragment_header ~name:"test" code in
  print_endline ("provides: " ^ String.concat ", " frag.provides);
  print_endline ("requires: " ^ String.concat ", " frag.requires);
  [%expect {|
    provides: caml_new_func
    requires: caml_dep |}]
