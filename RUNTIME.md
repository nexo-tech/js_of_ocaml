# Lua Runtime and Interop Design

This document specifies the Lua runtime API design, OCaml-Lua interop strategy, standard library implementation, and practical examples for programming Neovim with OCaml.

## Table of Contents
1. [Runtime API Design](#runtime-api-design)
2. [OCaml-Lua Interop](#ocaml-lua-interop)
3. [Standard Library Implementation](#standard-library-implementation)
4. [Neovim Interop Examples](#neovim-interop-examples)
5. [Auto-Binding Generation](#auto-binding-generation)
6. [FFI Strategy](#ffi-strategy)

---

## Runtime API Design

### Module Organization

**Pattern**: Each OCaml primitive category gets its own Lua module

```
runtime/lua/
  core.lua              -- Module system, primitive registration
  ints.lua              -- Integer operations (32-bit semantics)
  mlBytes.lua           -- String/bytes operations
  array.lua             -- Array operations
  compare.lua           -- Polymorphic comparison
  hash.lua              -- Hashing
  io.lua                -- I/O operations
  fail.lua              -- Exception handling
  obj.lua               -- Obj module primitives
  stdlib.lua            -- OCaml stdlib primitives
  int64.lua             -- Int64 operations
  format.lua            -- Printf/scanf
  lexing.lua            -- Lexer support
  parsing.lua           -- Parser support
  gc.lua                -- GC integration
  weak.lua              -- Weak references
  lazy.lua              -- Lazy values
  effect.lua            -- Effect handlers (OCaml 5)
  domain.lua            -- Domain-local storage (OCaml 5)
  interop.lua           -- OCaml-Lua FFI (NEW)
```

### Core Module (`runtime/lua/core.lua`)

**Purpose**: Bootstrap runtime, register primitives, module loading

```lua
-- runtime/lua/core.lua
local M = {}

-- Global OCaml runtime namespace
_G._OCAML = _G._OCAML or {
  primitives = {},
  modules = {},
  version = "1.0.0"
}

-- Register a primitive function
function M.register(name, func)
  _OCAML.primitives[name] = func
end

-- Get a primitive (for generated code)
function M.get_primitive(name)
  local prim = _OCAML.primitives[name]
  if not prim then
    error("Undefined primitive: " .. name)
  end
  return prim
end

-- Register a module
function M.register_module(name, mod)
  _OCAML.modules[name] = mod
end

-- OCaml unit value
M.unit = 0

-- OCaml bool encoding
M.true_val = 1
M.false_val = 0

function M.ml_bool(lua_bool)
  return lua_bool and 1 or 0
end

function M.lua_bool(ml_bool)
  return ml_bool ~= 0
end

-- OCaml None/Some encoding
M.none = 0

function M.some(x)
  return {tag = 0, [1] = x}
end

function M.is_none(x)
  return type(x) == "number" and x == 0
end

-- Block creation helper
function M.make_block(tag, ...)
  local args = {...}
  local block = {tag = tag}
  for i, v in ipairs(args) do
    block[i] = v
  end
  return block
end

-- Check Lua version and capabilities
M.lua_version = tonumber(_VERSION:match("%d+%.%d+"))
M.has_bitops = M.lua_version >= 5.3
M.has_utf8 = M.lua_version >= 5.3

return M
```

---

## OCaml-Lua Interop

### Interop Module (`runtime/lua/interop.lua`)

**Purpose**: Bidirectional FFI between OCaml and Lua

```lua
-- runtime/lua/interop.lua
local core = require("runtime.lua.core")
local M = {}

-- Type tags for conversion
local TYPE_NIL = 0
local TYPE_BOOL = 1
local TYPE_NUMBER = 2
local TYPE_STRING = 3
local TYPE_TABLE = 4
local TYPE_FUNCTION = 5
local TYPE_USERDATA = 6

-- Convert Lua value to OCaml value
function M.of_lua(lua_val)
  local t = type(lua_val)

  if t == "nil" then
    return core.none
  elseif t == "boolean" then
    return core.ml_bool(lua_val)
  elseif t == "number" then
    -- Check if integer or float
    if math.type and math.type(lua_val) == "integer" then
      return lua_val
    else
      return lua_val  -- OCaml float
    end
  elseif t == "string" then
    return lua_val  -- OCaml string
  elseif t == "table" then
    -- Convert table to OCaml list or array
    if lua_val.tag ~= nil then
      -- Already an OCaml block
      return lua_val
    else
      -- Convert to OCaml array
      local arr = {tag = 0}
      for i, v in ipairs(lua_val) do
        arr[i - 1] = M.of_lua(v)  -- 0-indexed
      end
      return arr
    end
  elseif t == "function" then
    -- Wrap Lua function for OCaml
    return function(...)
      local args = {...}
      local lua_args = {}
      for i, arg in ipairs(args) do
        lua_args[i] = M.to_lua(arg)
      end
      local result = lua_val(table.unpack(lua_args))
      return M.of_lua(result)
    end
  else
    -- Userdata or other: wrap as abstract value
    return {tag = 255, _lua_value = lua_val}
  end
end

-- Convert OCaml value to Lua value
function M.to_lua(ml_val)
  local t = type(ml_val)

  if t == "number" then
    -- Could be int, bool, or unit
    return ml_val
  elseif t == "string" then
    return ml_val
  elseif t == "table" then
    if ml_val._lua_value then
      -- Unwrap abstract Lua value
      return ml_val._lua_value
    elseif ml_val.tag == 0 then
      -- OCaml array/tuple/record -> Lua table
      local tbl = {}
      local i = 1
      while ml_val[i - 1] ~= nil do
        tbl[i] = M.to_lua(ml_val[i - 1])
        i = i + 1
      end
      return tbl
    else
      -- Other OCaml block -> keep as is or convert
      return ml_val
    end
  elseif t == "function" then
    -- Wrap OCaml function for Lua
    return function(...)
      local args = {...}
      local ml_args = {}
      for i, arg in ipairs(args) do
        ml_args[i] = M.of_lua(arg)
      end
      local result = ml_val(table.unpack(ml_args))
      return M.to_lua(result)
    end
  else
    return ml_val
  end
end

-- Access Lua global
function M.get_global(name)
  return M.of_lua(_G[name])
end

-- Set Lua global
function M.set_global(name, ml_val)
  _G[name] = M.to_lua(ml_val)
end

-- Call Lua function
function M.call_lua(lua_fn, ...)
  local ml_args = {...}
  local lua_args = {}
  for i, arg in ipairs(ml_args) do
    lua_args[i] = M.to_lua(arg)
  end

  local lua_fn_unwrapped = M.to_lua(lua_fn)
  local result = lua_fn_unwrapped(table.unpack(lua_args))
  return M.of_lua(result)
end

-- Get table field
function M.get_field(tbl, key)
  local lua_tbl = M.to_lua(tbl)
  local lua_key = M.to_lua(key)
  return M.of_lua(lua_tbl[lua_key])
end

-- Set table field
function M.set_field(tbl, key, value)
  local lua_tbl = M.to_lua(tbl)
  local lua_key = M.to_lua(key)
  local lua_value = M.to_lua(value)
  lua_tbl[lua_key] = lua_value
  return core.unit
end

-- Create Lua table
function M.create_table()
  return M.of_lua({})
end

-- Require Lua module
function M.require_module(name)
  return M.of_lua(require(M.to_lua(name)))
end

core.register("lua_of_lua", M.of_lua)
core.register("lua_to_lua", M.to_lua)
core.register("lua_get_global", M.get_global)
core.register("lua_set_global", M.set_global)
core.register("lua_call", M.call_lua)
core.register("lua_get_field", M.get_field)
core.register("lua_set_field", M.set_field)
core.register("lua_create_table", M.create_table)
core.register("lua_require", M.require_module)

return M
```

### OCaml Interop API (`lib/lua_of_ocaml/lua.ml`)

**Purpose**: Type-safe OCaml API for Lua interop

```ocaml
(* lib/lua_of_ocaml/lua.ml *)

(** {1 Lua FFI for OCaml} *)

type lua_value
(** Abstract type for Lua values *)

type 'a t = lua_value
(** Type-safe wrapper for Lua values *)

(** {2 Type Conversions} *)

external of_lua : lua_value -> 'a = "lua_of_lua"
(** Convert Lua value to OCaml value (unsafe) *)

external to_lua : 'a -> lua_value = "lua_to_lua"
(** Convert OCaml value to Lua value *)

(** {2 Global Access} *)

external get_global : string -> lua_value = "lua_get_global"
(** Get Lua global variable *)

external set_global : string -> lua_value -> unit = "lua_set_global"
(** Set Lua global variable *)

let get_global_int name =
  of_lua (get_global name)

let get_global_string name =
  of_lua (get_global name)

(** {2 Function Calls} *)

external call : lua_value -> lua_value array -> lua_value = "lua_call"
(** Call Lua function with arguments *)

let call0 fn =
  of_lua (call (to_lua fn) [||])

let call1 fn arg1 =
  of_lua (call (to_lua fn) [| to_lua arg1 |])

let call2 fn arg1 arg2 =
  of_lua (call (to_lua fn) [| to_lua arg1; to_lua arg2 |])

let call3 fn arg1 arg2 arg3 =
  of_lua (call (to_lua fn) [| to_lua arg1; to_lua arg2; to_lua arg3 |])

let calln fn args =
  of_lua (call (to_lua fn) (Array.map to_lua args))

(** {2 Table Operations} *)

external get_field : lua_value -> lua_value -> lua_value = "lua_get_field"
(** Get table field *)

external set_field : lua_value -> lua_value -> lua_value -> unit = "lua_set_field"
(** Set table field *)

external create_table : unit -> lua_value = "lua_create_table"
(** Create empty Lua table *)

let get tbl key =
  of_lua (get_field (to_lua tbl) (to_lua key))

let set tbl key value =
  set_field (to_lua tbl) (to_lua key) (to_lua value)

let ( .%{} ) tbl key = get tbl key
let ( .%{}<- ) tbl key value = set tbl key value

(** {2 Module Loading} *)

external require : string -> lua_value = "lua_require"
(** Require Lua module *)

(** {2 Method Calls} *)

let method_call obj method_name args =
  let tbl = to_lua obj in
  let method_fn = get_field tbl (to_lua method_name) in
  of_lua (call method_fn (Array.concat [[| tbl |]; Array.map to_lua args]))

let method0 obj name =
  method_call obj name [||]

let method1 obj name arg1 =
  method_call obj name [| arg1 |]

let method2 obj name arg1 arg2 =
  method_call obj name [| arg1; arg2 |]

(** {2 Type-Safe Wrappers} *)

module type S = sig
  type t
  val of_lua : lua_value -> t
  val to_lua : t -> lua_value
end

module Int : S with type t = int = struct
  type t = int
  let of_lua = of_lua
  let to_lua = to_lua
end

module String : S with type t = string = struct
  type t = string
  let of_lua = of_lua
  let to_lua = to_lua
end

module Bool : S with type t = bool = struct
  type t = bool
  let of_lua = of_lua
  let to_lua = to_lua
end

module List (E : S) : S with type t = E.t list = struct
  type t = E.t list

  let of_lua lv =
    let arr : lua_value = of_lua lv in
    let rec build i acc =
      try
        let elem = get_field arr (to_lua i) in
        build (i + 1) (E.of_lua elem :: acc)
      with _ -> List.rev acc
    in
    build 0 []

  let to_lua lst =
    let arr = create_table () in
    List.iteri (fun i elem ->
      set_field arr (to_lua i) (E.to_lua elem)
    ) lst;
    arr
end

module Option (E : S) : S with type t = E.t option = struct
  type t = E.t option

  let of_lua lv =
    if of_lua lv = (Obj.magic 0 : int) then None
    else Some (E.of_lua (get_field lv (to_lua 1)))

  let to_lua = function
    | None -> to_lua 0
    | Some x ->
        let block = create_table () in
        set_field block (to_lua "tag") (to_lua 0);
        set_field block (to_lua 1) (E.to_lua x);
        block
end
```

---

## Standard Library Implementation

### String/Bytes Operations (`runtime/lua/mlBytes.lua`)

**Reference**: JavaScript implementation in `runtime/js/mlBytes.js`

```lua
-- runtime/lua/mlBytes.lua
local core = require("runtime.lua.core")
local M = {}

-- String metatable for immutable strings
local string_mt = {
  __index = function(t, k)
    if type(k) == "number" then
      return string.byte(t._str, k + 1) or 0
    end
    return rawget(t, k)
  end,
  __len = function(t) return #t._str end,
  __tostring = function(t) return t._str end
}

-- Bytes metatable for mutable bytes
local bytes_mt = {
  __index = function(t, k)
    if type(k) == "number" then
      return rawget(t, k) or 0
    end
    return rawget(t, k)
  end,
  __len = function(t) return t._length end,
  __tostring = function(t)
    local chars = {}
    for i = 0, t._length - 1 do
      chars[i + 1] = string.char(t[i] or 0)
    end
    return table.concat(chars)
  end
}

function M.caml_create_bytes(len)
  local bytes = {_length = len}
  setmetatable(bytes, bytes_mt)
  return bytes
end

function M.caml_bytes_get(s, i)
  if type(s) == "string" then
    return string.byte(s, i + 1) or 0
  elseif type(s) == "table" and s._str then
    return string.byte(s._str, i + 1) or 0
  else
    return s[i] or 0
  end
end

function M.caml_bytes_set(s, i, c)
  if type(s) == "table" and s._length then
    s[i] = c % 256
    return core.unit
  else
    error("Cannot modify immutable string")
  end
end

function M.caml_ml_string_length(s)
  if type(s) == "string" then
    return #s
  elseif type(s) == "table" then
    return s._length or #(s._str or "")
  else
    return 0
  end
end

function M.caml_string_get(s, i)
  local len = M.caml_ml_string_length(s)
  if i < 0 or i >= len then
    error("index out of bounds")
  end
  return M.caml_bytes_get(s, i)
end

function M.caml_string_of_bytes(b)
  if type(b) == "string" then
    return b
  end
  return tostring(b)
end

function M.caml_bytes_of_string(s)
  local len = #s
  local bytes = M.caml_create_bytes(len)
  for i = 0, len - 1 do
    bytes[i] = string.byte(s, i + 1)
  end
  return bytes
end

-- Register primitives
core.register("caml_create_bytes", M.caml_create_bytes)
core.register("caml_bytes_get", M.caml_bytes_get)
core.register("caml_bytes_set", M.caml_bytes_set)
core.register("caml_ml_string_length", M.caml_ml_string_length)
core.register("caml_string_get", M.caml_string_get)
core.register("caml_string_of_bytes", M.caml_string_of_bytes)
core.register("caml_bytes_of_string", M.caml_bytes_of_string)

return M
```

### Array Operations (`runtime/lua/array.lua`)

```lua
-- runtime/lua/array.lua
local core = require("runtime.lua.core")
local M = {}

function M.caml_make_vect(len, init)
  local arr = {tag = 0, _length = len}
  for i = 0, len - 1 do
    arr[i] = init
  end
  return arr
end

function M.caml_array_get(arr, idx)
  if idx < 0 or idx >= arr._length then
    error("array index out of bounds")
  end
  return arr[idx]
end

function M.caml_array_set(arr, idx, val)
  if idx < 0 or idx >= arr._length then
    error("array index out of bounds")
  end
  arr[idx] = val
  return core.unit
end

function M.caml_array_length(arr)
  return arr._length or 0
end

function M.caml_array_append(a1, a2)
  local len1 = M.caml_array_length(a1)
  local len2 = M.caml_array_length(a2)
  local result = {tag = 0, _length = len1 + len2}

  for i = 0, len1 - 1 do
    result[i] = a1[i]
  end
  for i = 0, len2 - 1 do
    result[len1 + i] = a2[i]
  end

  return result
end

function M.caml_array_sub(arr, start, len)
  local result = {tag = 0, _length = len}
  for i = 0, len - 1 do
    result[i] = arr[start + i]
  end
  return result
end

core.register("caml_make_vect", M.caml_make_vect)
core.register("caml_array_get", M.caml_array_get)
core.register("caml_array_set", M.caml_array_set)
core.register("caml_array_length", M.caml_array_length)
core.register("caml_array_append", M.caml_array_append)
core.register("caml_array_sub", M.caml_array_sub)

return M
```

---

## Neovim Interop Examples

### Basic Neovim API Binding

**Auto-generated from Neovim API metadata**

```ocaml
(* lib/lua_of_ocaml/neovim.ml - Auto-generated *)

open Lua

module Vim = struct
  let vim = get_global "vim"

  module Api = struct
    let api = get vim "api"

    let nvim_command cmd =
      method1 api "nvim_command" cmd

    let nvim_eval expr =
      method1 api "nvim_eval" expr

    let nvim_call_function name args =
      method2 api "nvim_call_function" name args

    let nvim_get_current_buf () =
      method0 api "nvim_get_current_buf"

    let nvim_get_current_win () =
      method0 api "nvim_get_current_win"

    let nvim_get_current_line () =
      method0 api "nvim_get_current_line"

    let nvim_set_current_line line =
      method1 api "nvim_set_current_line" line

    let nvim_buf_get_lines buf start end_ strict =
      method_call api "nvim_buf_get_lines" [| buf; start; end_; strict |]

    let nvim_buf_set_lines buf start end_ strict lines =
      method_call api "nvim_buf_set_lines" [| buf; start; end_; strict; lines |]

    let nvim_create_buf listed scratch =
      method2 api "nvim_create_buf" listed scratch

    let nvim_open_win buf enter config =
      method_call api "nvim_open_win" [| buf; enter; config |]
  end

  module Fn = struct
    let fn = get vim "fn"

    let expand expr =
      method1 fn "expand" expr

    let input prompt =
      method1 fn "input" prompt

    let getline line =
      method1 fn "getline" line

    let setline line text =
      method2 fn "setline" line text
  end

  module Keymap = struct
    let set mode lhs rhs opts =
      let keymap = get vim "keymap" in
      method_call keymap "set" [| mode; lhs; rhs; opts |]
  end

  module Cmd = struct
    let cmd = get vim "cmd"

    let execute name opts =
      method2 cmd name opts
  end
end

(* Example: Print a message in Neovim *)
let print msg =
  Vim.Api.nvim_command ("echo '" ^ msg ^ "'")

(* Example: Get current buffer content *)
let get_buffer_lines () =
  let buf = Vim.Api.nvim_get_current_buf () in
  Vim.Api.nvim_buf_get_lines buf 0 (-1) false
```

### Example Plugin: Line Counter

```ocaml
(* examples/neovim_plugins/line_counter.ml *)

open Lua
open Neovim

let count_lines () =
  let buf = Vim.Api.nvim_get_current_buf () in
  let lines = Vim.Api.nvim_buf_get_lines buf 0 (-1) false in
  let count = List.length (of_lua lines) in
  print ("Total lines: " ^ string_of_int count)

let count_non_empty_lines () =
  let buf = Vim.Api.nvim_get_current_buf () in
  let lines : string list = of_lua (Vim.Api.nvim_buf_get_lines buf 0 (-1) false) in
  let count = List.fold_left (fun acc line ->
    if String.trim line <> "" then acc + 1 else acc
  ) 0 lines in
  print ("Non-empty lines: " ^ string_of_int count)

(* Register commands *)
let () =
  Vim.Api.nvim_command "command! CountLines lua require('line_counter').count_lines()";
  Vim.Api.nvim_command "command! CountNonEmpty lua require('line_counter').count_non_empty_lines()"
```

### Example Plugin: Fuzzy Finder

```ocaml
(* examples/neovim_plugins/fuzzy_finder.ml *)

open Lua
open Neovim

module Fuzzy = struct
  (* Simple fuzzy matching *)
  let matches pattern text =
    let rec check_pattern p_idx t_idx =
      if p_idx >= String.length pattern then true
      else if t_idx >= String.length text then false
      else if pattern.[p_idx] = text.[t_idx] then
        check_pattern (p_idx + 1) (t_idx + 1)
      else
        check_pattern p_idx (t_idx + 1)
    in
    check_pattern 0 0

  (* Find files matching pattern *)
  let find_files pattern =
    let files_str : string = of_lua (Vim.Fn.expand "**/*") in
    let files = String.split_on_char '\n' files_str in
    List.filter (matches pattern) files

  (* Open fuzzy finder UI *)
  let open_finder () =
    (* Create buffer for results *)
    let buf = Vim.Api.nvim_create_buf false true in

    (* Create floating window *)
    let width = 80 in
    let height = 20 in
    let config = create_table () in
    set config "relative" "editor";
    set config "width" width;
    set config "height" height;
    set config "row" 5;
    set config "col" 10;
    set config "style" "minimal";
    set config "border" "rounded";

    let win = Vim.Api.nvim_open_win buf true config in

    (* Get input from user *)
    let pattern : string = of_lua (Vim.Fn.input "Search: ") in

    (* Find matching files *)
    let matches = find_files pattern in

    (* Display results *)
    let lines = Array.of_list matches in
    Vim.Api.nvim_buf_set_lines buf 0 (-1) false (to_lua lines)
end

let () =
  Vim.Api.nvim_command "command! Fuzzy lua require('fuzzy_finder').open_finder()"
```

### Example Plugin: LSP Helper

```ocaml
(* examples/neovim_plugins/lsp_helper.ml *)

open Lua
open Neovim

module Lsp = struct
  let lsp = get (Vim.vim) "lsp"

  let buf_request_sync buf method params timeout =
    method_call lsp "buf_request_sync" [| buf; method; params; timeout |]

  let get_active_clients () =
    method0 lsp "get_active_clients"

  (* Get document symbols *)
  let get_symbols () =
    let buf = Vim.Api.nvim_get_current_buf () in
    let params = create_table () in
    set params "textDocument" (create_table ());

    let result = buf_request_sync buf "textDocument/documentSymbol" params 1000 in
    of_lua result

  (* Go to definition *)
  let goto_definition () =
    let buf = Vim.Api.nvim_get_current_buf () in
    let row, col = (* get cursor position *) 0, 0 in

    let params = create_table () in
    let text_doc = create_table () in
    let position = create_table () in

    set position "line" row;
    set position "character" col;
    set params "textDocument" text_doc;
    set params "position" position;

    let result = buf_request_sync buf "textDocument/definition" params 1000 in
    match of_lua result with
    | Some locations ->
        (* Jump to first location *)
        print "Jumping to definition..."
    | None ->
        print "No definition found"

  (* Show hover info *)
  let show_hover () =
    let buf = Vim.Api.nvim_get_current_buf () in
    Vim.Api.nvim_command "lua vim.lsp.buf.hover()"
end

let () =
  Vim.Keymap.set "n" "gd" (to_lua Lsp.goto_definition) (create_table ());
  Vim.Keymap.set "n" "K" (to_lua Lsp.show_hover) (create_table ())
```

---

## Auto-Binding Generation

### PPX for Automatic Lua Bindings

**Design**: Generate bindings from type annotations

```ocaml
(* lib/ppx_lua/ppx_lua.ml *)

(** PPX extension for generating Lua bindings *)

(* Usage:
   [%%lua.module "vim.api"] generates bindings for vim.api

   Example:
   module Vim_api = [%%lua.module "vim.api" {
     nvim_command : string -> unit
     nvim_eval : string -> 'a
     nvim_get_current_buf : unit -> buffer
   }]
*)

(* The PPX generates:

   module Vim_api = struct
     let nvim_command =
       let api = Lua.get_global "vim" |> Lua.get "api" in
       fun cmd -> Lua.method1 api "nvim_command" cmd

     let nvim_eval =
       let api = Lua.get_global "vim" |> Lua.get "api" in
       fun expr -> Lua.method1 api "nvim_eval" expr

     let nvim_get_current_buf =
       let api = Lua.get_global "vim" |> Lua.get "api" in
       fun () -> Lua.method0 api "nvim_get_current_buf"
   end
*)
```

**Usage Example**:

```ocaml
(* Auto-generate Neovim API bindings *)
module Nvim = [%%lua.module "vim.api" {
  (* Buffer operations *)
  nvim_get_current_buf : unit -> buffer;
  nvim_buf_get_lines : buffer -> int -> int -> bool -> string list;
  nvim_buf_set_lines : buffer -> int -> int -> bool -> string list -> unit;

  (* Window operations *)
  nvim_get_current_win : unit -> window;
  nvim_open_win : buffer -> bool -> config -> window;

  (* Commands *)
  nvim_command : string -> unit;
  nvim_eval : string -> 'a;
}]

(* Use generated bindings *)
let () =
  let buf = Nvim.nvim_get_current_buf () in
  let lines = Nvim.nvim_buf_get_lines buf 0 (-1) false in
  List.iter print_endline lines
```

### JSON Schema to OCaml Bindings

**Tool**: `nvim-api-gen` - Generate from Neovim API metadata

```bash
# Generate Neovim bindings
$ nvim --api-info | lua_of_ocaml_bindgen > lib/lua_of_ocaml/neovim.ml
```

**Generated Output**:

```ocaml
(* Auto-generated from Neovim API *)
module Nvim : sig
  type buffer = Lua.lua_value
  type window = Lua.lua_value
  type tabpage = Lua.lua_value

  module Buf : sig
    val get_lines : buffer -> int -> int -> bool -> string list
    val set_lines : buffer -> int -> int -> bool -> string list -> unit
    val get_name : buffer -> string
    val set_name : buffer -> string -> unit
    (* ... 100+ more functions *)
  end

  module Win : sig
    val get_buf : window -> buffer
    val set_buf : window -> buffer -> unit
    val get_cursor : window -> int * int
    val set_cursor : window -> int * int -> unit
    (* ... *)
  end
end
```

---

## FFI Strategy

### Low-Overhead FFI

**Goal**: Minimize conversion overhead for common cases

```lua
-- runtime/lua/interop.lua (optimized paths)

-- Fast path for primitives (no conversion needed)
local function is_primitive(val)
  local t = type(val)
  return t == "nil" or t == "boolean" or t == "number" or t == "string"
end

-- Lazy conversion: convert only when accessed
function M.lazy_of_lua(lua_val)
  if is_primitive(lua_val) then
    return lua_val  -- No conversion needed
  end

  -- Return proxy that converts on access
  return setmetatable({}, {
    __index = function(_, key)
      return M.lazy_of_lua(lua_val[key])
    end,
    __call = function(_, ...)
      return M.lazy_of_lua(lua_val(...))
    end,
    _lua_value = lua_val
  })
end
```

### Zero-Copy String Handling

```lua
-- Strings are immutable in both OCaml and Lua - share directly
function M.string_of_lua(lua_str)
  return lua_str  -- No conversion needed!
end

function M.string_to_lua(ocaml_str)
  return ocaml_str  -- No conversion needed!
end
```

### Table Proxies

```ocaml
(* lib/lua_of_ocaml/lua.ml - Advanced API *)

module Table = struct
  type t = lua_value

  (* Direct indexing without conversion *)
  let get_int tbl idx =
    get_field tbl (to_lua idx) |> of_lua

  let get_string tbl key =
    get_field tbl (to_lua key) |> of_lua

  (* Iteration *)
  let iter f tbl =
    let rec loop i =
      match get_int tbl i with
      | exception _ -> ()
      | v -> f v; loop (i + 1)
    in
    loop 0

  (* Lazy iteration with Seq *)
  let to_seq tbl =
    let rec loop i () =
      match get_int tbl i with
      | exception _ -> Seq.Nil
      | v -> Seq.Cons (v, loop (i + 1))
    in
    loop 0
end
```

---

## Best Practices

### 1. Minimize Conversions

```ocaml
(* GOOD: Keep values in Lua domain *)
let process_buffer buf =
  let lines = Nvim.Buf.get_lines buf 0 (-1) false in
  (* Work with Lua values directly *)
  Lua.Table.iter (fun line ->
    (* Process line *)
    ()
  ) lines

(* AVOID: Converting to OCaml and back *)
let process_buffer_slow buf =
  let lines : string list = of_lua (Nvim.Buf.get_lines buf 0 (-1) false) in
  let processed = List.map process_line lines in
  Nvim.Buf.set_lines buf 0 (-1) false (to_lua processed)
```

### 2. Use Type-Safe Wrappers

```ocaml
(* Define typed wrappers for Lua APIs *)
module type LUA_API = sig
  type t
  val method0 : t -> string -> 'a
  val method1 : t -> string -> 'b -> 'a
end

module Make_API (M : sig val name : string end) : LUA_API = struct
  type t = lua_value
  let api = lazy (Lua.get_global M.name)
  let method0 api name = Lua.method0 (Lazy.force api) name
  let method1 api name arg = Lua.method1 (Lazy.force api) name arg
end
```

### 3. Cache Frequent Lookups

```ocaml
(* Cache vim.api reference *)
let vim_api = lazy (
  Lua.get_global "vim" |> Lua.get "api"
)

let nvim_command cmd =
  Lua.method1 (Lazy.force vim_api) "nvim_command" cmd
```

---

## Testing Strategy

### Unit Tests for Interop

```ocaml
(* lib/tests/test_lua_interop.ml *)

let%expect_test "round-trip conversion" =
  let lua_val = Lua.to_lua 42 in
  let ocaml_val : int = Lua.of_lua lua_val in
  print_int ocaml_val;
  [%expect {| 42 |}]

let%expect_test "table operations" =
  let tbl = Lua.create_table () in
  Lua.set tbl "key" "value";
  let result : string = Lua.get tbl "key" in
  print_endline result;
  [%expect {| value |}]

let%expect_test "function call" =
  let lua_fn = Lua.get_global "math" |> Lua.get "abs" in
  let result : int = Lua.call1 lua_fn (-5) in
  print_int result;
  [%expect {| 5 |}]
```

### Integration Tests with Neovim

```ocaml
(* tests/test_neovim.ml *)

let%expect_test "neovim command" =
  Nvim.Api.nvim_command "echo 'test'";
  [%expect {| test |}]

let%expect_test "buffer manipulation" =
  let buf = Nvim.Api.nvim_create_buf false true in
  Nvim.Buf.set_lines buf 0 (-1) false ["line 1"; "line 2"];
  let lines = Nvim.Buf.get_lines buf 0 (-1) false in
  List.iter print_endline (Lua.of_lua lines);
  [%expect {|
    line 1
    line 2
  |}]
```

---

## Summary

This runtime design provides:

1. **Efficient Interop**: Minimal conversion overhead, zero-copy when possible
2. **Type Safety**: OCaml type system ensures correctness
3. **Auto-Binding**: PPX and code generation reduce boilerplate
4. **Neovim Ready**: Complete API coverage for plugin development
5. **Standard Library**: Full OCaml stdlib support in Lua
6. **Best Practices**: Clear patterns for efficient Lua integration

The combination of manual optimized runtime code and auto-generated bindings allows writing Neovim plugins in idiomatic OCaml while maintaining performance.