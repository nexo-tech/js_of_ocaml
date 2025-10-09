(* Test that all primitives from PRIMITIVES.md are covered *)

open Js_of_ocaml_compiler.Stdlib
module Lua_link = Lua_of_ocaml_compiler__Lua_link

(* List of all 70 primitives from PRIMITIVES.md *)
let all_primitives =
  [ (* Global/Registry (1) *)
    "caml_register_global"
    (* Integer Comparison (3) *)
  ; "caml_int_compare"
  ; "caml_int32_compare"
  ; "caml_nativeint_compare"
    (* Float Operations (1) *)
  ; "caml_float_compare"
    (* String Operations (6) *)
  ; "caml_string_compare"
  ; "caml_string_get"
  ; "caml_string_set"
  ; "caml_string_unsafe_set"
  ; "caml_create_string"
  ; "caml_blit_string"
    (* Bytes Operations (7) *)
  ; "caml_bytes_get"
  ; "caml_bytes_set"
  ; "caml_bytes_unsafe_set"
  ; "caml_create_bytes"
  ; "caml_fill_bytes"
  ; "caml_blit_bytes"
    (* Array Operations (11) *)
  ; "caml_array_set"
  ; "caml_array_unsafe_set"
  ; "caml_make_vect"
  ; "caml_array_make"
  ; "caml_make_float_vect"
  ; "caml_floatarray_create"
  ; "caml_array_sub"
  ; "caml_array_append"
  ; "caml_array_concat"
  ; "caml_array_blit"
  ; "caml_array_fill"
    (* Float Array Operations (2) *)
  ; "caml_floatarray_set"
  ; "caml_floatarray_unsafe_set"
    (* Reference Operations (1) *)
  ; "caml_ref_set"
    (* I/O Channel Operations (30) *)
  ; "caml_ml_open_descriptor_in"
  ; "caml_ml_open_descriptor_in_with_flags"
  ; "caml_ml_open_descriptor_out"
  ; "caml_ml_open_descriptor_out_with_flags"
  ; "caml_ml_out_channels_list"
  ; "caml_ml_flush"
  ; "caml_ml_output"
  ; "caml_ml_output_bytes"
  ; "caml_ml_output_char"
  ; "caml_ml_output_int"
  ; "caml_ml_input"
  ; "caml_ml_input_char"
  ; "caml_ml_input_int"
  ; "caml_ml_input_scan_line"
  ; "caml_ml_close_channel"
  ; "caml_ml_channel_size"
  ; "caml_ml_channel_size_64"
  ; "caml_ml_set_binary_mode"
  ; "caml_ml_is_binary_mode"
  ; "caml_ml_set_buffered"
  ; "caml_ml_is_buffered"
  ; "caml_ml_set_channel_name"
  ; "caml_channel_descriptor"
  ; "caml_ml_pos_in"
  ; "caml_ml_pos_in_64"
  ; "caml_ml_pos_out"
  ; "caml_ml_pos_out_64"
  ; "caml_ml_seek_in"
  ; "caml_ml_seek_in_64"
  ; "caml_ml_seek_out"
  ; "caml_ml_seek_out_64"
    (* Marshal Operations (3) *)
  ; "caml_output_value"
  ; "caml_input_value"
  ; "caml_input_value_to_outside_heap"
    (* System Operations (2) *)
  ; "caml_sys_open"
  ; "caml_sys_close"
    (* Weak Reference Operations (3) *)
  ; "caml_weak_create"
  ; "caml_weak_set"
  ; "caml_weak_get"
    (* Special/Internal (2) *)
  ; "caml_closure"
  ; "caml_special"
  ]

let%expect_test "all primitives count check" =
  (* Verify we have exactly 72 primitives (PRIMITIVES.md says 70 but has count errors) *)
  Printf.printf "Total primitives: %d\n" (List.length all_primitives);
  [%expect {| Total primitives: 72 |}]

let%expect_test "all primitives are resolvable via linking system" =
  (* Load runtime modules from runtime/lua *)
  (* Tests run from _build/.sandbox/.../default/compiler/tests-lua, so go up 6 levels *)
  let runtime_dir = "../../../../../../runtime/lua" in
  let fragments = Lua_link.load_runtime_dir runtime_dir in

  Printf.printf "Loaded %d runtime fragments\n" (List.length fragments);

  (* Try to resolve each primitive *)
  let resolvable = ref [] in
  let unresolvable = ref [] in

  List.iter
    ~f:(fun prim ->
      match Lua_link.find_primitive_implementation prim fragments with
      | Some (frag, func) ->
          resolvable := (prim, frag.name, func) :: !resolvable
      | None -> unresolvable := prim :: !unresolvable)
    all_primitives;

  (* Report statistics *)
  Printf.printf "Resolvable: %d/%d primitives\n"
    (List.length !resolvable)
    (List.length all_primitives);
  Printf.printf "Unresolvable: %d/%d primitives\n"
    (List.length !unresolvable)
    (List.length all_primitives);

  (* List unresolvable primitives *)
  if List.length !unresolvable > 0
  then begin
    Printf.printf "\nUnresolvable primitives:\n";
    List.iter ~f:(fun p -> Printf.printf "  - %s\n" p) (List.rev !unresolvable)
  end;

  (* Note: This test is expected to fail initially as not all primitives
     are implemented yet. As we implement more runtime modules with proper
     Export directives and naming conventions, this count will increase. *)
  [%expect
    {|
    Loaded 88 runtime fragments
    Resolvable: 19/72 primitives
    Unresolvable: 53/72 primitives

    Unresolvable primitives:
      - caml_register_global
      - caml_string_compare
      - caml_string_get
      - caml_string_set
      - caml_string_unsafe_set
      - caml_create_string
      - caml_blit_string
      - caml_bytes_get
      - caml_bytes_set
      - caml_bytes_unsafe_set
      - caml_create_bytes
      - caml_fill_bytes
      - caml_blit_bytes
      - caml_make_vect
      - caml_make_float_vect
      - caml_floatarray_create
      - caml_floatarray_set
      - caml_floatarray_unsafe_set
      - caml_ref_set
      - caml_ml_open_descriptor_in
      - caml_ml_open_descriptor_in_with_flags
      - caml_ml_open_descriptor_out
      - caml_ml_open_descriptor_out_with_flags
      - caml_ml_out_channels_list
      - caml_ml_flush
      - caml_ml_output
      - caml_ml_output_bytes
      - caml_ml_output_char
      - caml_ml_output_int
      - caml_ml_input
      - caml_ml_input_char
      - caml_ml_input_int
      - caml_ml_input_scan_line
      - caml_ml_close_channel
      - caml_ml_channel_size
      - caml_ml_channel_size_64
      - caml_ml_set_binary_mode
      - caml_ml_is_binary_mode
      - caml_ml_set_buffered
      - caml_ml_is_buffered
      - caml_ml_set_channel_name
      - caml_channel_descriptor
      - caml_ml_pos_in
      - caml_ml_pos_in_64
      - caml_ml_pos_out
      - caml_ml_pos_out_64
      - caml_ml_seek_in
      - caml_ml_seek_in_64
      - caml_ml_seek_out
      - caml_ml_seek_out_64
      - caml_output_value
      - caml_input_value
      - caml_input_value_to_outside_heap
    |}]

let%expect_test "show resolvable primitives with their implementations" =
  (* Load runtime modules *)
  let runtime_dir = "../../../../../../runtime/lua" in
  let fragments = Lua_link.load_runtime_dir runtime_dir in

  (* Collect resolvable primitives *)
  let resolvable = ref [] in
  List.iter
    ~f:(fun prim ->
      match Lua_link.find_primitive_implementation prim fragments with
      | Some (frag, func) -> resolvable := (prim, frag.name, func) :: !resolvable
      | None -> ())
    all_primitives;

  (* Sort by primitive name *)
  let sorted =
    List.sort ~cmp:(fun (p1, _, _) (p2, _, _) -> String.compare p1 p2) !resolvable
  in

  (* Print resolvable primitives *)
  Printf.printf "Resolvable primitives (%d):\n" (List.length sorted);
  List.iter
    ~f:(fun (prim, module_name, func_name) ->
      Printf.printf "  %s -> %s.%s\n" prim module_name func_name)
    sorted;

  [%expect
    {|
    Resolvable primitives (19):
      caml_array_append -> array.append
      caml_array_blit -> array.blit
      caml_array_concat -> array.concat
      caml_array_fill -> array.fill
      caml_array_make -> array.make
      caml_array_set -> array.set
      caml_array_sub -> array.sub
      caml_array_unsafe_set -> array.unsafe_set
      caml_closure -> core.closure
      caml_float_compare -> float.compare
      caml_int32_compare -> compare.int_compare
      caml_int_compare -> compare.int_compare
      caml_nativeint_compare -> compare.int_compare
      caml_special -> core.special
      caml_sys_close -> sys.close
      caml_sys_open -> sys.open
      caml_weak_create -> weak.create
      caml_weak_get -> weak.get
      caml_weak_set -> weak.set
    |}]
