# Lua_of_ocaml Architecture Guide

This document provides detailed architectural guidance for implementing lua_of_ocaml by reusing existing js_of_ocaml infrastructure with minimal refactoring.

## Table of Contents
1. [Core Architecture Overview](#core-architecture-overview)
2. [Reusable Components](#reusable-components)
3. [New Components Required](#new-components-required)
4. [Value Representation Strategy](#value-representation-strategy)
5. [Code Generation Approach](#code-generation-approach)
6. [Runtime System Design](#runtime-system-design)
7. [Integration Points](#integration-points)
8. [Implementation Patterns](#implementation-patterns)

---

## Core Architecture Overview

### Compilation Pipeline (Shared Across All Targets)

```
OCaml Bytecode
      ↓
Parse_bytecode.ml → Code.program (IR)
      ↓
Driver.ml (orchestrates optimization passes)
      ↓
[Shared optimizations: deadcode, inline, specialize, tailcall, effects]
      ↓
      ├─→ JavaScript (Generate.ml → Javascript.ml → Js_output.ml)
      ├─→ WebAssembly (lib-wasm/Generate.ml → Wasm_ast → Wasm_output.ml)
      └─→ Lua (NEW: lib-lua/Lua_generate.ml → Lua_ast → Lua_output.ml)
```

**Key Insight**: The entire frontend (bytecode parsing → IR → optimization) is **100% reusable**. Only the backend (code generation + runtime) needs to be implemented.

### Directory Structure for Lua

Following the established pattern:
```
compiler/
  lib/                    # Shared IR and optimizations (REUSE)
  lib-wasm/              # WebAssembly backend (REFERENCE)
  lib-lua/               # Lua backend (NEW - mirror lib-wasm structure)
    lua_ast.ml           # Lua AST definition
    lua_output.ml        # Lua pretty printer
    lua_generate.ml      # Code generation from IR to Lua AST
    lua_reserved.ml      # Lua keyword handling
    lua_link.ml          # Module linking
  bin-lua_of_ocaml/      # Compiler executable (NEW)
  tests-lua/             # Lua-specific tests (NEW)

runtime/
  js/                    # JavaScript runtime (REFERENCE)
  wasm/                  # WebAssembly runtime (REFERENCE)
  lua/                   # Lua runtime (NEW)
    core.lua
    ints.lua
    mlBytes.lua
    array.lua
    ...
```

---

## Reusable Components

### 1. Complete IR and Optimization Infrastructure

**Location**: `compiler/lib/`

**Fully Reusable Modules**:
- `Code.ml` - Intermediate representation (100% reusable)
- `Parse_bytecode.ml` - OCaml bytecode parser (100% reusable)
- `Driver.ml` - Optimization orchestration (95% reusable)
- `Deadcode.ml` - Dead code elimination (100% reusable)
- `Inline.ml` - Function inlining (100% reusable)
- `Tailcall.ml` - Tail call optimization (100% reusable)
- `Specialize.ml` - Specialization passes (100% reusable)
- `Effects.ml` - Effect handler transformation (95% reusable)
- `Flow.ml` - Data flow analysis (100% reusable)
- `Primitive.ml` - Primitive operation registry (100% reusable)

**How to Use**:
```ocaml
(* In lua_generate.ml *)
open Code  (* Use the shared IR types directly *)

let translate_program (p : Code.program) : Lua_ast.program =
  (* Code.program is the input - same as JS/Wasm backends *)
  ...
```

### 2. Driver Integration Pattern

**Reference**: `compiler/lib/driver.ml:238-253`

The `generate` function is called after optimization. Follow this pattern:

```ocaml
(* Add to driver.ml or create lib-lua/lua_driver.ml *)
let generate_lua
    ~exported_runtime
    { program; variable_uses; trampolined_calls; deadcode_sentinal; in_cps; shapes = _ } =
  Lua_generate.f
    program
    ~exported_runtime
    ~live_vars:variable_uses
    ~trampolined_calls
    ~in_cps
    ~deadcode_sentinal
```

### 3. Primitive Operations System

**Reference**: `compiler/lib/primitive.ml`

The primitive system is target-agnostic. Primitives are registered with:
- Kind: `Pure | Mutable | Mutator`
- Arity: Number of arguments
- Args: Const/Mutable annotation

**Implementation Strategy**:
```ocaml
(* In lua_generate.ml *)
let translate_prim name args =
  match name with
  | "caml_add_int" ->
      (* Map to Lua arithmetic *)
      Lua_ast.BinOp (Add, translate_arg args.(0), translate_arg args.(1))
  | _ when Primitive.exists name ->
      (* Generate runtime call *)
      Lua_ast.Call (Runtime_ref name, List.map translate_arg args)
  | _ -> failwith ("Unknown primitive: " ^ name)
```

---

## New Components Required

### 1. Lua AST Definition (`compiler/lib-lua/lua_ast.ml`)

**Pattern**: Mirror JavaScript AST but simplified for Lua

**Reference**: `compiler/lib/javascript.ml:153-200`

```ocaml
(* Recommended structure based on Lua syntax *)
type ident = string

type expr =
  | Nil
  | Bool of bool
  | Number of string  (* Store as string like Javascript.Num *)
  | String of string
  | Ident of ident
  | Table of (table_field list)
  | Index of expr * expr                    (* t[k] *)
  | Dot of expr * ident                     (* t.field *)
  | Call of expr * expr list
  | Method_call of expr * ident * expr list (* obj:method(...) *)
  | Function of ident list * bool * block   (* params, vararg, body *)
  | BinOp of binop * expr * expr
  | UnOp of unop * expr
  | Vararg

and table_field =
  | Array_field of expr                     (* {expr} *)
  | Rec_field of ident * expr              (* {name = expr} *)
  | General_field of expr * expr           (* {[expr] = expr} *)

and binop =
  | Add | Sub | Mul | Div | IDiv | Mod | Pow
  | Concat
  | Eq | Neq | Lt | Le | Gt | Ge
  | And | Or
  | BAnd | BOr | BXor | Shl | Shr

and unop = Not | Neg | BNot | Len

type stat =
  | Local of ident list * expr list option  (* local x, y = ... *)
  | Assign of expr list * expr list        (* x, y = ... *)
  | Call_stat of expr                      (* function call as statement *)
  | If of expr * block * block option      (* if-then-else *)
  | While of expr * block
  | Repeat of block * expr
  | For_num of ident * expr * expr * expr option * block
  | For_in of ident list * expr list * block
  | Return of expr list
  | Break
  | Goto of ident
  | Label of ident
  | Block of block

and block = stat list

type program = block

(* Helper constructors (like Javascript.ml) *)
let nil = Nil
let bool b = Bool b
let number n = Number n
let string s = String s
let ident i = Ident i
let call f args = Call (f, args)
```

### 2. Lua Output (`compiler/lib-lua/lua_output.ml`)

**Pattern**: Follow `compiler/lib/js_output.ml` structure

**Reference**: `compiler/lib/js_output.ml`

**Key Requirements**:
- Proper indentation (2 spaces, configurable)
- Parenthesization for operator precedence
- Comment preservation
- Source map generation (optional)

```ocaml
type context =
  { mutable indent : int
  ; mutable col : int
  ; mutable line : int
  ; buffer : Buffer.t
  }

let newline ctx =
  Buffer.add_char ctx.buffer '\n';
  ctx.line <- ctx.line + 1;
  ctx.col <- 0

let indent ctx =
  for _ = 1 to ctx.indent * 2 do
    Buffer.add_char ctx.buffer ' ';
    ctx.col <- ctx.col + 1
  done

let rec output_expr ctx prec e =
  match e with
  | Nil -> output_string ctx "nil"
  | Bool true -> output_string ctx "true"
  | Bool false -> output_string ctx "false"
  | Number n -> output_string ctx n
  | BinOp (Add, e1, e2) ->
      maybe_paren ctx prec 6 (fun () ->
        output_expr ctx 6 e1;
        output_string ctx " + ";
        output_expr ctx 6 e2)
  | ...
```

### 3. Code Generation (`compiler/lib-lua/lua_generate.ml`)

**Pattern**: Follow `compiler/lib-wasm/generate.ml` structure (functor-based)

**Reference**: `compiler/lib-wasm/generate.ml:32-44`

```ocaml
(* Core generation context *)
type ctx =
  { live : int array                    (* From deadcode analysis *)
  ; in_cps : Effects.in_cps            (* Effect handler info *)
  ; blocks : Code.block Addr.Map.t     (* IR blocks *)
  ; variable_uses : Deadcode.variable_uses
  ; trampolined_calls : Effects.trampolined_calls
  ; var_map : Lua_ast.ident Code.Var.Map.t  (* IR var → Lua var *)
  }

(* Main entry point *)
let f program ~exported_runtime ~live_vars ~trampolined_calls ~in_cps ~deadcode_sentinal =
  let ctx = make_context program live_vars trampolined_calls in_cps in
  let blocks = translate_blocks ctx program.blocks in
  let runtime = if exported_runtime then emit_runtime_exports () else [] in
  Lua_ast.Block (runtime @ blocks)
```

### 4. Reserved Words (`compiler/lib-lua/lua_reserved.ml`)

**Pattern**: Follow `compiler/lib/reserved.ml`

**Reference**: `compiler/lib/reserved.ml`

```ocaml
let lua_keywords =
  StringSet.of_list
    [ "and"; "break"; "do"; "else"; "elseif"
    ; "end"; "false"; "for"; "function"; "goto"
    ; "if"; "in"; "local"; "nil"; "not"
    ; "or"; "repeat"; "return"; "then"; "true"
    ; "until"; "while"
    ]

let lua_globals =
  StringSet.of_list
    [ "_G"; "_VERSION"; "assert"; "collectgarbage"
    ; "dofile"; "error"; "getmetatable"; "ipairs"
    ; "load"; "loadfile"; "next"; "pairs"
    ; "pcall"; "print"; "rawequal"; "rawget"
    ; "rawlen"; "rawset"; "require"; "select"
    ; "setmetatable"; "tonumber"; "tostring"; "type"
    ; "xpcall"
    ; "coroutine"; "debug"; "io"; "math"
    ; "os"; "package"; "string"; "table"; "utf8"
    ]

let is_reserved s =
  StringSet.mem s lua_keywords || StringSet.mem s lua_globals

(* Mangling strategy *)
let mangle_name name =
  if is_reserved name then "_" ^ name
  else if String.contains name '$' then
    String.map (function '$' -> '_' | c -> c) name
  else name
```

---

## Value Representation Strategy

### OCaml Values in Lua

**Reference**: `runtime/js/mlBytes.js:20-48` for JavaScript encoding

| OCaml Type | Lua Representation | Notes |
|------------|-------------------|-------|
| `int` | Lua number with overflow | Lua 5.3+ has 64-bit ints, need 32-bit mask |
| `float` | Lua number | Direct mapping |
| `string` | Lua string (immutable) | Use metamethods for bytes access |
| `bytes` | Table with metatable | `{[0]=b0, [1]=b1, ...}` 0-indexed |
| `bool` | Lua boolean | Direct mapping |
| `unit` | Lua number `0` | Use constant |
| `None` | Lua number `0` | Use constant |
| `Some x` | Table `{tag=0, x}` | Block with tag |
| `[]` | Lua number `0` | Use constant |
| `x::xs` | Table `{tag=0, x, xs}` | Block with tag 0 |
| `(a, b, c)` | Table `{tag=0, a, b, c}` | Block with tag 0 |
| `{x=1; y=2}` | Table `{tag=0, 1, 2}` | Block with tag 0, positional |
| `C(a, b)` | Table `{tag=N, a, b}` | Block with variant tag |
| Function | Lua function | May need curry wrapper |
| Object | Table with metatable | Methods in metatable |
| Array | Table `{tag=0, [0]=x, [1]=y}` | 0-indexed with tag |

### Block Encoding

**Pattern**: Similar to JavaScript (arrays with tag)

```lua
-- OCaml: type t = A | B of int | C of int * int
-- Lua encoding:

local A = 0  -- Constant (immediate)
local B = function(x) return {tag=0, x} end
local C = function(x, y) return {tag=1, x, y} end

-- Access:
local function match_t(v)
  if type(v) == "number" then
    return "A"
  elseif v.tag == 0 then
    return "B", v[1]
  elseif v.tag == 1 then
    return "C", v[1], v[2]
  end
end
```

### Integer Arithmetic with 32-bit Semantics

**Reference**: `runtime/js/ints.js`

```lua
-- runtime/lua/ints.lua
local function int32(n)
  -- Lua 5.3+: Use bitwise ops
  return n & 0xFFFFFFFF
end

local function add_int(a, b)
  local result = a + b
  -- Normalize to 32-bit signed
  if result > 0x7FFFFFFF then
    return result - 0x100000000
  elseif result < -0x80000000 then
    return result + 0x100000000
  else
    return result
  end
end

-- For Lua 5.1/5.2 (no bitwise ops):
local function int32_compat(n)
  n = n % 4294967296
  if n >= 2147483648 then
    n = n - 4294967296
  end
  return n
end
```

---

## Code Generation Approach

### Expression Translation

**Reference**: `compiler/lib/generate.ml:500-600` (JavaScript)
**Reference**: `compiler/lib-wasm/generate.ml:150-200` (WebAssembly)

**Pattern**: Recursive translation of Code.expr → Lua_ast.expr

```ocaml
(* Map Code IR to Lua AST *)
let rec translate_expr ctx (e : Code.expr) : Lua_ast.expr =
  match e with
  | Constant c -> translate_constant c
  | Apply { f; args; exact } ->
      if exact then
        (* Direct call *)
        Lua_ast.Call (get_var ctx f, List.map (get_var ctx) args)
      else
        (* Partial application - need curry *)
        curry_call (get_var ctx f) (List.map (get_var ctx) args)
  | Block (tag, fields, _, _) ->
      (* OCaml block → Lua table *)
      let fields_expr = Array.to_list (Array.map (get_var ctx) fields) in
      Lua_ast.Table (
        Lua_ast.Rec_field ("tag", Lua_ast.Number (string_of_int tag)) ::
        List.mapi (fun i e -> Lua_ast.General_field (Lua_ast.Number (string_of_int i), e)) fields_expr
      )
  | Field (obj, idx, _) ->
      (* Block field access *)
      Lua_ast.Index (get_var ctx obj, Lua_ast.Number (string_of_int idx))
  | Closure (params, (pc, fv), _) ->
      (* Generate closure *)
      let body = translate_cont ctx pc in
      Lua_ast.Function (
        List.map (var_name ctx) params,
        false,
        body
      )
  | Prim (prim, args) ->
      translate_prim ctx prim args
  | Special (Alias_prim name) ->
      Lua_ast.Ident (runtime_name name)

and translate_prim ctx prim args =
  match prim with
  | Vectlength ->
      let arr = translate_prim_arg ctx (List.hd args) in
      Lua_ast.UnOp (Len, arr)
  | Array_get ->
      (match args with
      | [Pv arr; Pv idx] ->
          Lua_ast.Index (get_var ctx arr, get_var ctx idx)
      | _ -> assert false)
  | Extern name ->
      (* Call runtime primitive *)
      Lua_ast.Call (
        Lua_ast.Ident (runtime_name name),
        List.map (translate_prim_arg ctx) args
      )
  | Not ->
      Lua_ast.UnOp (Not, translate_prim_arg ctx (List.hd args))
  | ...
```

### Statement Translation

**Reference**: `compiler/lib/generate.ml:800-900`

```ocaml
let rec translate_instr ctx (i : Code.instr) : Lua_ast.stat list =
  match i with
  | Let (x, e) ->
      let lua_var = new_var ctx x in
      let lua_expr = translate_expr ctx e in
      [Lua_ast.Local ([lua_var], Some [lua_expr])]

  | Assign (x, y) ->
      [Lua_ast.Assign ([get_var ctx x], [get_var ctx y])]

  | Set_field (obj, idx, val_) ->
      let obj_expr = get_var ctx obj in
      let idx_expr = Lua_ast.Number (string_of_int idx) in
      let val_expr = get_var ctx val_ in
      [Lua_ast.Assign ([Lua_ast.Index (obj_expr, idx_expr)], [val_expr])]

  | Array_set (arr, idx, val_) ->
      [Lua_ast.Assign (
        [Lua_ast.Index (get_var ctx arr, get_var ctx idx)],
        [get_var ctx val_]
      )]
```

### Control Flow Translation

**Reference**: `compiler/lib/generate.ml:1000-1100`

```ocaml
let translate_block ctx (block : Code.block) : Lua_ast.block =
  let instrs = List.concat_map (translate_instr ctx) block.body in
  let branch = translate_branch ctx block.branch in
  instrs @ branch

and translate_branch ctx (br : Code.cont) : Lua_ast.stat list =
  match br with
  | Return x ->
      [Lua_ast.Return [get_var ctx x]]

  | Branch (pc, args) ->
      (* Tail call optimization: use goto *)
      let label = label_name pc in
      let assigns = List.map2
        (fun param arg -> Lua_ast.Assign ([Lua_ast.Ident param], [get_var ctx arg]))
        (get_block_params ctx pc)
        args
      in
      assigns @ [Lua_ast.Goto label]

  | Cond (x, (pc_true, args_true), (pc_false, args_false)) ->
      [Lua_ast.If (
        get_var ctx x,
        translate_branch ctx (Branch (pc_true, args_true)),
        Some (translate_branch ctx (Branch (pc_false, args_false)))
      )]

  | Switch (x, cases, default) ->
      (* Generate cascading if-then-elseif *)
      translate_switch ctx x cases default
```

### Tail Call Optimization

Lua 5.1+ supports proper tail calls, but we need explicit handling:

```ocaml
(* Use goto for local tail calls *)
let rec is_tail_recursive pc blocks =
  (* Check if pc refers to current function entry *)
  ...

let translate_tail_call ctx pc args =
  if is_tail_recursive pc ctx.blocks then
    (* Use goto for TCO *)
    [Lua_ast.Goto (label_name pc)]
  else
    (* Regular call *)
    [Lua_ast.Return [Lua_ast.Call (Lua_ast.Ident (func_name pc), args)]]
```

---

## Runtime System Design

### Runtime File Organization

**Pattern**: Mirror JavaScript runtime structure

**Reference**: `runtime/js/` directory structure

```
runtime/lua/
  core.lua              -- Module system, basic infrastructure
  ints.lua              -- Integer operations (32-bit semantics)
  mlBytes.lua           -- String/Bytes implementation
  array.lua             -- Array operations
  compare.lua           -- Polymorphic comparison
  hash.lua              -- Hashing functions
  io.lua                -- I/O operations
  fail.lua              -- Exception handling
  obj.lua               -- Object operations (Obj module)
  stdlib.lua            -- OCaml stdlib primitives
  int64.lua             -- Int64 support
  format.lua            -- Printf/scanf support
  lexing.lua            -- Lexing support
  parsing.lua           -- Parsing support
  ...
```

### Module System Pattern

```lua
-- runtime/lua/core.lua
local M = {}

-- Global runtime table
_OCAML = _OCAML or {}
_OCAML.primitives = {}

function M.register(name, func)
  _OCAML.primitives[name] = func
end

function M.get_primitive(name)
  return _OCAML.primitives[name] or error("Unknown primitive: " .. name)
end

return M
```

### Primitive Implementation Pattern

**Reference**: `runtime/js/ints.js` for integer operations

```lua
-- runtime/lua/ints.lua
local core = require "runtime.lua.core"

-- Check Lua version for bitwise ops
local has_bitops = _VERSION >= "Lua 5.3"

local function caml_add_int(a, b)
  local result = a + b
  -- Normalize to 32-bit signed integer
  if has_bitops then
    result = result & 0xFFFFFFFF
    if result >= 0x80000000 then
      result = result - 0x100000000
    end
  else
    -- Fallback for Lua 5.1/5.2
    result = result % 4294967296
    if result >= 2147483648 then
      result = result - 4294967296
    end
  end
  return result
end

core.register("caml_add_int", caml_add_int)
core.register("caml_sub_int", caml_sub_int)
-- ...
```

### String/Bytes Implementation

**Reference**: `runtime/js/mlBytes.js:20-150`

```lua
-- runtime/lua/mlBytes.lua
local M = {}

-- Metatable for mutable bytes
local bytes_mt = {
  __index = function(t, k)
    return rawget(t, k) or 0
  end,
  __len = function(t)
    return t._length
  end,
  __tostring = function(t)
    local chars = {}
    for i = 0, t._length - 1 do
      chars[i + 1] = string.char(t[i])
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
    return string.byte(s, i + 1)
  else
    return s[i] or 0
  end
end

function M.caml_bytes_set(s, i, c)
  s[i] = c
  return 0  -- unit
end

return M
```

### Exception Handling

**Reference**: `runtime/js/fail.js`

```lua
-- runtime/lua/fail.lua
local M = {}

-- Exception representation
local function make_exception(tag, arg)
  return {_exception = true, tag = tag, arg = arg}
end

function M.caml_raise(exn)
  error(exn, 0)  -- Level 0 to avoid Lua stack info
end

function M.caml_raise_with_string(tag, msg)
  M.caml_raise(make_exception(tag, msg))
end

-- Try-catch using pcall
function M.caml_try_catch(try_fn, catch_fn)
  local ok, result = pcall(try_fn)
  if ok then
    return result
  else
    if type(result) == "table" and result._exception then
      return catch_fn(result)
    else
      -- Re-raise non-OCaml errors
      error(result, 0)
    end
  end
end

return M
```

---

## Integration Points

### 1. Build System Integration

**Reference**: `compiler/bin-js_of_ocaml/dune`

```sexp
; compiler/bin-lua_of_ocaml/dune
(executable
 (name lua_of_ocaml)
 (public_name lua_of_ocaml)
 (package lua_of_ocaml-compiler)
 (modes byte exe)
 (libraries
  compiler-libs.common
  js_of_ocaml-compiler.lib
  js_of_ocaml-compiler.lib-lua
  cmdliner
  yojson)
 (modules lua_of_ocaml compile cmd_arg))
```

### 2. Driver Entry Point

**Reference**: `compiler/bin-js_of_ocaml/js_of_ocaml.ml`

```ocaml
(* compiler/bin-lua_of_ocaml/lua_of_ocaml.ml *)
let compile_to_lua ~output ~source_map options program =
  let optimized =
    Driver.optimize
      ~profile:options.profile
      ~deadcode_sentinal
      program
  in
  let lua_code =
    Lua_generate.f
      optimized.program
      ~exported_runtime:options.export_runtime
      ~live_vars:optimized.variable_uses
      ~trampolined_calls:optimized.trampolined_calls
      ~in_cps:optimized.in_cps
      ~deadcode_sentinal
  in
  let output_channel = open_out output in
  Lua_output.program output_channel lua_code;
  close_out output_channel
```

### 3. Dune Rules for Compilation

```sexp
; Example project dune file
(rule
 (targets output.lua)
 (deps input.bc)
 (action
  (run lua_of_ocaml
   --output %{targets}
   %{deps})))

(executable
 (name main)
 (modes byte)
 (modules main))

(rule
 (alias runtest)
 (deps main.lua)
 (action
  (run lua %{deps})))
```

---

## Implementation Patterns

### Pattern 1: Reuse Shared IR Processing

**Never** duplicate IR manipulation code. Always use existing modules:

```ocaml
(* GOOD: Reuse existing optimizations *)
let optimized = Driver.optimize ~profile:O2 program in
let lua_ast = Lua_generate.f optimized.program in
...

(* BAD: Don't reimplement optimizations *)
let optimized = my_custom_deadcode program in  (* ❌ *)
...
```

### Pattern 2: Follow Existing Backend Patterns

When implementing new Lua backend components, follow the wasm_of_ocaml pattern:

```ocaml
(* Structure of lib-lua/ mirrors lib-wasm/ *)
(* lib-wasm/generate.ml pattern: *)
module Generate (Target : Target_sig.S) = struct
  let translate_expr ctx expr = ...
  let translate_block ctx block = ...
end

(* lib-lua/lua_generate.ml should follow: *)
module Generate = struct
  type ctx = { ... }
  let translate_expr ctx expr = ...
  let translate_block ctx block = ...
  let f program ~exported_runtime ~live_vars ~trampolined_calls ~in_cps = ...
end
```

### Pattern 3: Runtime Modularity

**Reference**: JavaScript runtime modular structure

```lua
-- Each runtime module is independent
-- runtime/lua/array.lua
local core = require "runtime.lua.core"

local function caml_make_vect(len, init)
  local arr = {tag = 0, _length = len}
  for i = 0, len - 1 do
    arr[i] = init
  end
  return arr
end

-- Register all primitives
core.register("caml_make_vect", caml_make_vect)
-- ...

return {
  caml_make_vect = caml_make_vect,
  -- Export for direct use if needed
}
```

### Pattern 4: Progressive Implementation

Follow phase order from LUA.md:

1. **Phase 1-2**: AST + basic runtime (can generate "hello world")
2. **Phase 3-4**: Value representation + code generation (can compile simple programs)
3. **Phase 5-6**: Primitives + modules (can compile stdlib users)
4. **Phase 7-9**: Advanced features + interop (production ready)

Each phase builds on previous, allowing incremental testing.

### Pattern 5: Testing Strategy

**Reference**: `compiler/tests-jsoo/` and `compiler/tests-wasm_of_ocaml/`

```ocaml
(* compiler/tests-lua/test_arithmetic.ml *)
let%expect_test "simple_add" =
  let code = {|
    let x = 1 + 2 in
    print_int x
  |} in
  let bc = compile_to_bytecode code in
  let lua = Lua_of_ocaml.compile bc in
  let output = run_lua lua in
  print_endline output;
  [%expect {| 3 |}]
```

---

## Key Architectural Decisions

### Decision 1: Reuse Code.program IR

**Rationale**: The IR is target-independent and well-optimized. Don't create a Lua-specific IR.

**Impact**:
- ✅ Zero duplication of optimization passes
- ✅ Automatic benefit from future IR improvements
- ✅ Smaller codebase

### Decision 2: Mirror lib-wasm Structure

**Rationale**: WebAssembly backend is recent, well-structured, and similar in target characteristics (non-JS).

**Impact**:
- ✅ Clear separation of concerns
- ✅ Familiar patterns for contributors
- ✅ Easier maintenance

### Decision 3: Table-Based Value Encoding

**Rationale**: Lua tables are flexible and support metatables for custom behavior.

**Impact**:
- ✅ Natural representation of OCaml blocks
- ✅ Can optimize field access
- ⚠️ Memory overhead (vs pure arrays)
- Solution: Use array part of table for block fields

### Decision 4: Runtime in Pure Lua

**Rationale**: Maximum portability across Lua implementations (5.1, 5.2, 5.3, 5.4, LuaJIT, Luau).

**Impact**:
- ✅ No C dependencies
- ✅ Works in sandboxed environments
- ⚠️ Integer operations need special handling
- Solution: Version detection and polyfills

### Decision 5: Effect Handlers via Coroutines

**Rationale**: Lua coroutines map naturally to OCaml effects.

**Impact**:
- ✅ Efficient implementation
- ✅ Natural control flow
- ⚠️ Requires CPS transformation
- Solution: Reuse existing Effects.ml with Lua backend support

### Decision 6: Single-Threaded Domain Model

**Rationale**: Lua has no native threading (except in specific implementations), similar to JavaScript.

**Impact**:
- ✅ Atomic operations become simple assignments
- ✅ No actual concurrency concerns
- ✅ Domain-local storage maps to global variables
- ⚠️ No parallel speedup available
- Solution: Follow JavaScript's single-domain model

---

## OCaml 5 Concurrency Support

### Effect Handlers

**Reference**: `compiler/lib/effects.ml` and `runtime/js/effect.js`

OCaml 5 introduces algebraic effect handlers for structured concurrency. The js_of_ocaml compiler implements this via CPS transformation.

#### JavaScript Implementation Pattern

**Reference**: `runtime/js/effect.js:1-50`

JavaScript uses a fiber stack approach:
```javascript
var caml_current_stack = {
  k: <low-level continuation>,
  x: <exception handler stack>,
  h: <effect handlers (retc, exnc, effc)>,
  e: <parent fiber>
};
```

#### Lua Implementation Strategy

Lua coroutines provide a natural mapping for effect handlers:

```lua
-- runtime/lua/effect.lua
local M = {}

-- Current execution context (fiber)
local caml_current_stack = {
  k = nil,        -- Low-level continuation (coroutine)
  x = nil,        -- Exception handler stack
  h = nil,        -- Effect handlers {retc, exnc, effc}
  e = nil         -- Parent fiber
}

function M.caml_push_fiber(handlers)
  local new_fiber = {
    k = coroutine.create(function() end),
    x = nil,
    h = handlers,
    e = caml_current_stack
  }
  caml_current_stack = new_fiber
  return new_fiber
end

function M.caml_pop_fiber()
  local parent = caml_current_stack.e
  caml_current_stack.e = nil
  caml_current_stack = parent
  return parent.k
end

function M.caml_perform_effect(eff, continuation)
  if caml_current_stack.e == nil then
    error({_exception = true, tag = "Unhandled", arg = eff})
  end

  -- Get effect handler from current fiber
  local handler = caml_current_stack.h[3]  -- effc field
  local last_fiber = caml_current_stack
  last_fiber.k = continuation

  -- Pop to parent fiber
  local k = M.caml_pop_fiber()

  -- Invoke effect handler
  local handler_fn = handler(eff)
  if handler_fn then
    return handler_fn(last_fiber)
  else
    -- Re-perform in parent fiber
    return M.caml_perform_effect(eff, continuation)
  end
end

-- Resume a continuation (one-shot)
function M.caml_resume(cont, value)
  if cont.k == nil then
    error("Continuation already resumed")
  end

  -- Chain continuation to current stack
  local k = cont.k
  cont.k = nil  -- Mark as used (one-shot)

  -- Push fiber onto stack
  local last = cont
  while last.e ~= nil do
    last = last.e
  end
  last.e = caml_current_stack
  caml_current_stack = cont

  -- Resume execution
  return coroutine.resume(k, value)
end

return M
```

#### CPS Transformation Reuse

**Reference**: `compiler/lib/effects.ml:19-35`

The CPS transformation is **100% reusable** across targets. The `Effects.f` function transforms the IR and marks which functions need CPS treatment:

```ocaml
(* In lua_generate.ml, use the CPS info directly *)
let translate_function ctx f params body =
  let is_cps = Var.Set.mem f ctx.in_cps in
  if is_cps then
    (* Add continuation parameter *)
    let cont_param = fresh_ident "_k" in
    let lua_params = List.map (var_name ctx) params @ [cont_param] in
    let lua_body = translate_block ctx body in
    Lua_ast.Function (lua_params, false, lua_body)
  else
    (* Normal function *)
    let lua_params = List.map (var_name ctx) params in
    let lua_body = translate_block ctx body in
    Lua_ast.Function (lua_params, false, lua_body)
```

#### Effect Primitive Translation

```ocaml
(* In lua_generate.ml *)
let translate_effect_prim ctx name args =
  match name with
  | "%perform" ->
      (* Translate: perform effect *)
      Lua_ast.Call (
        Lua_ast.Dot (runtime_ref "effect", "caml_perform_effect"),
        [translate_arg ctx (List.hd args); get_continuation ctx]
      )

  | "%resume" ->
      (* Translate: resume continuation *)
      (match args with
       | [Pv cont; Pv value] ->
           Lua_ast.Call (
             Lua_ast.Dot (runtime_ref "effect", "caml_resume"),
             [get_var ctx cont; get_var ctx value]
           )
       | _ -> assert false)

  | "%reperform" ->
      (* Re-perform effect in parent handler *)
      Lua_ast.Call (
        Lua_ast.Dot (runtime_ref "effect", "caml_reperform"),
        [translate_arg ctx (List.hd args)]
      )

  | _ -> assert false
```

### Domain-Local Storage

**Reference**: `runtime/js/domain.js`

Since Lua (like JavaScript) has no true parallel domains, domain-local storage is simply global state.

#### JavaScript Pattern

```javascript
var caml_domain_dls = [0];

function caml_domain_dls_get(_unit) {
  return caml_domain_dls;
}

function caml_domain_dls_set(a) {
  caml_domain_dls = a;
}
```

#### Lua Implementation

```lua
-- runtime/lua/domain.lua
local M = {}

-- Global domain-local storage (singleton domain)
local caml_domain_dls = {tag = 0}

function M.caml_domain_dls_get(_unit)
  return caml_domain_dls
end

function M.caml_domain_dls_set(a)
  caml_domain_dls = a
  return 0  -- unit
end

function M.caml_domain_dls_compare_and_set(old, new)
  if caml_domain_dls == old then
    caml_domain_dls = new
    return 1  -- true
  end
  return 0  -- false
end

return M
```

### Atomic Operations

**Reference**: `runtime/js/domain.js:28-90`

In single-threaded environments, atomic operations are just normal operations:

```lua
-- runtime/lua/domain.lua (continued)

function M.caml_atomic_load(ref)
  return ref[1]
end

function M.caml_atomic_cas(ref, old_val, new_val)
  if ref[1] == old_val then
    ref[1] = new_val
    return 1  -- true
  end
  return 0  -- false
end

function M.caml_atomic_exchange(ref, val)
  local old = ref[1]
  ref[1] = val
  return old
end

function M.caml_atomic_fetch_add(ref, n)
  local old = ref[1]
  ref[1] = old + n
  return old
end

-- Field variants (OCaml 5.4+)
function M.caml_atomic_load_field(block, index)
  return block[index + 1]  -- +1 for tag offset
end

function M.caml_atomic_cas_field(block, index, old_val, new_val)
  if block[index + 1] == old_val then
    block[index + 1] = new_val
    return 1
  end
  return 0
end

function M.caml_atomic_exchange_field(block, index, val)
  local old = block[index + 1]
  block[index + 1] = val
  return old
end

function M.caml_atomic_fetch_add_field(block, index, n)
  local old = block[index + 1]
  block[index + 1] = old + n
  return old
end
```

### Continuation Representation

Continuations in Lua are represented as fiber records (tables):

```lua
-- Continuation structure (mirrors JavaScript)
local continuation = {
  k = <coroutine>,           -- Low-level continuation
  x = <exception_handlers>,  -- Exception handler stack
  h = <effect_handlers>,     -- {retc, exnc, effc}
  e = <parent_fiber>        -- Enclosing fiber (or nil)
}
```

### Exception Handling Integration

Effect handlers interact with exception handlers:

```lua
-- runtime/lua/effect.lua (continued)

function M.caml_push_trap(handler)
  caml_current_stack.x = {
    h = handler,
    t = caml_current_stack.x
  }
end

function M.caml_pop_trap()
  if not caml_current_stack.x then
    return function(x) error(x) end
  end
  local handler = caml_current_stack.x.h
  caml_current_stack.x = caml_current_stack.x.t
  return handler
end

-- Exception handler in effect context
function M.caml_raise_in_effect(exn)
  if caml_current_stack.x then
    local handler = M.caml_pop_trap()
    return handler(exn)
  else
    -- Propagate to parent fiber's exception handler
    local parent_handler = caml_current_stack.h[2]  -- exnc
    local k = M.caml_pop_fiber()
    return parent_handler(exn)
  end
end
```

### Trampolined Calls

**Reference**: `compiler/lib/effects.ml` trampolined_calls tracking

Some function calls need trampolining to avoid stack overflow in CPS code:

```lua
-- runtime/lua/effect.lua (continued)

local TRAMPOLINE_CALL = {}
local TRAMPOLINE_RETURN = {}

function M.caml_trampoline(f, args)
  local result = {type = TRAMPOLINE_CALL, f = f, args = args}

  while result.type == TRAMPOLINE_CALL do
    result = result.f(table.unpack(result.args))
  end

  return result.value
end

function M.caml_trampoline_return(v)
  return {type = TRAMPOLINE_RETURN, value = v}
end

-- Use in generated code:
-- Instead of: return f(x, y, k)
-- Generate: return {type=TRAMPOLINE_CALL, f=f, args={x,y,k}}
```

### Testing Effect Handlers

**Test Pattern**:
```ocaml
(* Test effect handler compilation *)
open Effect.Deep

type _ Effect.t += E : int -> int Effect.t

let test () =
  match_with
    (fun () -> perform (E 10) + 5)
    { retc = (fun x -> x)
    ; exnc = raise
    ; effc = fun (type a) (e : a Effect.t) ->
        match e with
        | E n -> Some (fun (k : (a, _) continuation) ->
            continue k (n * 2))
        | _ -> None
    }
```

Expected Lua output structure:
```lua
-- Simplified generated code
local function test()
  local fiber = effect.caml_push_fiber({
    retc = function(x) return x end,
    exnc = function(e) error(e) end,
    effc = function(e)
      if e.tag == "E" then
        return function(k)
          return effect.caml_resume(k, e.arg * 2)
        end
      end
      return nil
    end
  })

  -- Perform effect
  local result = effect.caml_perform_effect(
    {tag = "E", arg = 10},
    function(v) return v + 5 end
  )

  return result
end
```

### Integration Checklist

- [ ] Implement `runtime/lua/effect.lua` following JavaScript structure
- [ ] Implement `runtime/lua/domain.lua` for DLS and atomics
- [ ] Use `ctx.in_cps` flag from Effects.ml to identify CPS functions
- [ ] Use `ctx.trampolined_calls` to identify functions needing trampolines
- [ ] Translate `%perform`, `%resume`, `%reperform` primitives
- [ ] Integrate exception handlers with effect handlers
- [ ] Test with OCaml 5.x code using effects
- [ ] Handle continuation reification and resumption
- [ ] Ensure one-shot continuation semantics

---

## Performance Considerations

### Optimization Opportunities

1. **Table vs Array Parts**:
   - Lua tables have array part (0-indexed) and hash part
   - Keep OCaml blocks in array part for performance
   ```lua
   -- GOOD: Array part
   local block = {tag=0, [0]=x, [1]=y, [2]=z}

   -- AVOID: Hash part
   local block = {tag=0, f0=x, f1=y, f2=z}
   ```

2. **Local Variables**:
   - Lua locals are faster than table access
   - Hoist frequently used runtime functions
   ```lua
   -- GOOD:
   local caml_add = _OCAML.primitives.caml_add_int
   for i = 1, n do
     result = caml_add(result, i)
   end

   -- AVOID:
   for i = 1, n do
     result = _OCAML.primitives.caml_add_int(result, i)
   end
   ```

3. **Memoization**:
   - Cache compiled regexes, format strings, etc.
   - Follow JavaScript runtime pattern

4. **LuaJIT Optimizations**:
   - Use `ffi` library for C interop in LuaJIT mode
   - Trace compiler friendly code patterns

---

## Migration from JavaScript Reference

### Common Patterns to Adapt

| JavaScript | Lua | Notes |
|------------|-----|-------|
| `var x = e` | `local x = e` | Use local by default |
| `arr[i]` | `arr[i]` | Same syntax, but 0-indexed in our encoding |
| `obj.field` | `obj.field` or `obj["field"]` | Same |
| `f.apply(null, args)` | `f(table.unpack(args))` | Lua 5.2+ |
| `typeof x === "number"` | `type(x) == "number"` | Different type names |
| `x === y` | `x == y` | Lua only has `==` |
| `function f() {}` | `local function f() end` | Lua syntax |
| `{tag:0, 0:x, 1:y}` | `{tag=0, [0]=x, [1]=y}` | Lua table syntax |
| `try-catch` | `pcall()` | Different mechanism |
| `prototype` | `metatable` | Lua's inheritance |

---

## Summary Checklist for Implementation

- [ ] Create `compiler/lib-lua/` with AST definition
- [ ] Implement Lua pretty printer following `js_output.ml` patterns
- [ ] Implement code generator following `lib-wasm/generate.ml` structure
- [ ] Reuse all shared IR and optimization modules from `compiler/lib/`
- [ ] Create `runtime/lua/` with modular primitive files
- [ ] Use table-based encoding for OCaml blocks (tag + fields)
- [ ] Implement 32-bit integer semantics with overflow
- [ ] Handle mutable bytes with metatables
- [ ] Use pcall for exception handling
- [ ] Leverage Lua coroutines for effects (via existing Effects.ml CPS)
- [ ] Follow incremental phase plan from LUA.md
- [ ] Test after each task using both Lua 5.4 and LuaJIT

This architecture ensures maximum code reuse, minimal refactoring, and a clean integration of Lua as a third compilation target alongside JavaScript and WebAssembly.