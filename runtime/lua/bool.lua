--Provides: caml_to_bool
-- Convert Lua boolean/truthy value to OCaml boolean (integer 1 or 0)
-- Matches js_of_ocaml's bool helper: let bool e = J.ECond (e, one, zero)
function caml_to_bool(b)
  if b then
    return 1
  else
    return 0
  end
end
