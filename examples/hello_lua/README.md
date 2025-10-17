# Hello Lua Example

This example demonstrates compiling OCaml bytecode to Lua using lua_of_ocaml.

## Building

```bash
dune build hello.bc.lua
```

This will:
1. Compile `hello.ml` to OCaml bytecode (`hello.bc`)
2. Use `lua_of_ocaml` to compile the bytecode to Lua (`hello.bc.lua`)

## Output

The generated Lua file will be at `_build/default/hello.bc.lua` (approximately 15KB).

## Dune Integration

The `dune` file shows how to integrate lua_of_ocaml compilation:

```dune
(executable
 (name hello)
 (modes byte))

(rule
 (targets hello.bc.lua)
 (deps hello.bc)
 (action
  (run %{bin:lua_of_ocaml} compile %{deps} -o %{targets})))

(alias
 (name default)
 (deps hello.bc.lua))
```

The key elements are:
- `(modes byte)` ensures bytecode compilation
- `(rule ...)` defines the lua_of_ocaml compilation step
- `(alias default ...)` makes the Lua file part of the default build target
