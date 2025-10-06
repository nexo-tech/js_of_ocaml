# Lua Runtime

This directory contains the Lua runtime for lua_of_ocaml.

The runtime implements OCaml primitives and standard library functions in Lua,
enabling compiled OCaml bytecode to execute in Lua environments.

## Structure

- `core.lua` - Core runtime, module system, primitive registration
- Additional runtime modules will be added in subsequent tasks

## Compatibility

The runtime is designed to work with:
- Lua 5.1+
- Lua 5.4
- LuaJIT
- Luau (Roblox)
