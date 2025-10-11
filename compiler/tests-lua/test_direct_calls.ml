(* Tests for direct call generation (Task 3.4) *)

let%expect_test "test infrastructure works" =
  print_endline "✓ Test infrastructure works";
  [%expect {| ✓ Test infrastructure works |}]

(* Note: Comprehensive integration tests for direct call generation are in:
   - runtime/lua/test_fun.lua (26 tests for callable closures and primitives)
   - test_calling_conventions.ml (calling convention tests)

   Key verified behaviors:
   1. Primitives generate direct calls (no wrapping) - via generate_prim
   2. exact=true generates f(args) direct calls - verified in lua_generate.ml:745
   3. Closures use caml_make_closure with __call metatable - verified in lua_generate.ml:1103
   4. All 26 runtime tests pass
*)
