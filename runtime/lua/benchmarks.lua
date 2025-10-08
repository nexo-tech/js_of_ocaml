#!/usr/bin/env lua
-- Performance Benchmarks for lua_of_ocaml Runtime
--
-- Measures performance of key runtime operations across different Lua versions

local function benchmark(name, iterations, fn)
  -- Warmup
  for i = 1, math.min(100, math.floor(iterations / 10)) do
    fn()
  end

  -- Collect garbage before benchmark
  collectgarbage("collect")

  -- Actual benchmark
  local start = os.clock()
  for i = 1, iterations do
    fn()
  end
  local elapsed = os.clock() - start

  local ops_per_sec = iterations / elapsed
  local ns_per_op = (elapsed * 1000000000) / iterations

  return {
    name = name,
    iterations = iterations,
    elapsed = elapsed,
    ops_per_sec = ops_per_sec,
    ns_per_op = ns_per_op
  }
end

local function format_number(n)
  if n >= 1000000000 then
    return string.format("%.2fB", n / 1000000000)
  elseif n >= 1000000 then
    return string.format("%.2fM", n / 1000000)
  elseif n >= 1000 then
    return string.format("%.2fK", n / 1000)
  else
    return string.format("%.2f", n)
  end
end

local function print_result(result)
  print(string.format("%-40s %12s ops/sec  %8.1f ns/op  (%d iterations)",
    result.name,
    format_number(result.ops_per_sec),
    result.ns_per_op,
    result.iterations))
end

print("====================================================================")
print("lua_of_ocaml Runtime Benchmarks")
print("====================================================================")
print("Lua Version: " .. _VERSION)
if jit then
  print("JIT: " .. jit.version .. " (" .. (jit.status() and "enabled" or "disabled") .. ")")
end
print("")

-- Load modules
local core = require("core")
local ints = require("ints")
local float = require("float")
local mlBytes = require("mlBytes")
local array = require("array")
local obj = require("obj")
local list = require("list")

print("Integer Operations (ints.lua)")
print("--------------------------------------------------------------------")

local result = benchmark("ints.add(1000, 2000)", 1000000, function()
  local _ = ints.add(1000, 2000)
end)
print_result(result)

result = benchmark("ints.mul(123, 456)", 1000000, function()
  local _ = ints.mul(123, 456)
end)
print_result(result)

result = benchmark("ints.div(1000000, 7)", 1000000, function()
  local _ = ints.div(1000000, 7)
end)
print_result(result)

result = benchmark("ints.band(0xFF00, 0x00FF)", 1000000, function()
  local _ = ints.band(0xFF00, 0x00FF)
end)
print_result(result)

result = benchmark("ints.lsl(1, 16)", 1000000, function()
  local _ = ints.lsl(1, 16)
end)
print_result(result)

result = benchmark("ints.compare(42, 100)", 1000000, function()
  local _ = ints.compare(42, 100)
end)
print_result(result)

print("")
print("Float Operations (float.lua)")
print("--------------------------------------------------------------------")

result = benchmark("float.caml_modf_float(3.14159)", 500000, function()
  local _ = float.caml_modf_float(3.14159)
end)
print_result(result)

result = benchmark("float.caml_ldexp_float(1.5, 10)", 500000, function()
  local _ = float.caml_ldexp_float(1.5, 10)
end)
print_result(result)

result = benchmark("float.caml_frexp_float(1024.0)", 500000, function()
  local _ = float.caml_frexp_float(1024.0)
end)
print_result(result)

result = benchmark("float.caml_is_finite(42.0)", 1000000, function()
  local _ = float.caml_is_finite(42.0)
end)
print_result(result)

result = benchmark("float.caml_classify_float(3.14)", 500000, function()
  local _ = float.caml_classify_float(3.14)
end)
print_result(result)

print("")
print("Bytes Operations (mlBytes.lua)")
print("--------------------------------------------------------------------")

result = benchmark("mlBytes.create(100)", 100000, function()
  local _ = mlBytes.create(100)
end)
print_result(result)

local bytes = mlBytes.create(1000)
result = benchmark("mlBytes.get(bytes, 500)", 1000000, function()
  local _ = mlBytes.get(bytes, 500)
end)
print_result(result)

result = benchmark("mlBytes.set(bytes, 500, 65)", 1000000, function()
  mlBytes.set(bytes, 500, 65)
end)
print_result(result)

result = benchmark("mlBytes.get16(bytes, 0)", 1000000, function()
  local _ = mlBytes.get16(bytes, 0)
end)
print_result(result)

result = benchmark("mlBytes.set32(bytes, 0, 0x12345678)", 500000, function()
  mlBytes.set32(bytes, 0, 0x12345678)
end)
print_result(result)

local str = "Hello, World!"
result = benchmark("mlBytes.bytes_of_string(str)", 100000, function()
  local _ = mlBytes.bytes_of_string(str)
end)
print_result(result)

print("")
print("Array Operations (array.lua)")
print("--------------------------------------------------------------------")

result = benchmark("array.make(100, 42)", 100000, function()
  local _ = array.make(100, 42)
end)
print_result(result)

local arr = array.make(1000, 0)
result = benchmark("array.get(arr, 500)", 1000000, function()
  local _ = array.get(arr, 500)
end)
print_result(result)

result = benchmark("array.set(arr, 500, 123)", 1000000, function()
  array.set(arr, 500, 123)
end)
print_result(result)

result = benchmark("array.length(arr)", 1000000, function()
  local _ = array.length(arr)
end)
print_result(result)

print("")
print("Object Operations (obj.lua)")
print("--------------------------------------------------------------------")

result = benchmark("obj.fresh_oo_id()", 1000000, function()
  local _ = obj.fresh_oo_id()
end)
print_result(result)

local methods = {{42, function(self) return 123 end}}
local method_table = obj.create_method_table(methods)
result = benchmark("obj.create_method_table({...})", 100000, function()
  local _ = obj.create_method_table(methods)
end)
print_result(result)

local test_obj = obj.create_object(method_table, {})
result = benchmark("obj.get_public_method(obj, 42)", 500000, function()
  local _ = obj.get_public_method(test_obj, 42)
end)
print_result(result)

result = benchmark("obj.call_method(obj, 42, {})", 100000, function()
  local _ = obj.call_method(test_obj, 42, {})
end)
print_result(result)

print("")
print("List Operations (list.lua)")
print("--------------------------------------------------------------------")

result = benchmark("list.caml_list_cons(42, 0)", 500000, function()
  local _ = list.caml_list_cons(42, 0)
end)
print_result(result)

-- Build a 10-element list: [1;2;3;4;5;6;7;8;9;10]
local lst = 0
for i = 10, 1, -1 do
  lst = list.caml_list_cons(i, lst)
end

result = benchmark("list.caml_list_length(10-elem)", 500000, function()
  local _ = list.caml_list_length(lst)
end)
print_result(result)

result = benchmark("list.caml_list_rev(10-elem)", 100000, function()
  local _ = list.caml_list_rev(lst)
end)
print_result(result)

result = benchmark("list.caml_list_map(f, 10-elem)", 100000, function()
  local _ = list.caml_list_map(function(x) return x * 2 end, lst)
end)
print_result(result)

result = benchmark("list.caml_list_fold_left(f,0,10)", 100000, function()
  local _ = list.caml_list_fold_left(function(acc, x) return acc + x end, 0, lst)
end)
print_result(result)

print("")
print("Core Operations (core.lua)")
print("--------------------------------------------------------------------")

result = benchmark("core.get_primitive('caml_int32_add')", 500000, function()
  local _ = core.get_primitive("caml_int32_add")
end)
print_result(result)

-- Test primitive registration overhead
local dummy_count = 0
local function dummy_prim()
  dummy_count = dummy_count + 1
end

result = benchmark("Primitive call overhead", 1000000, function()
  dummy_prim()
end)
print_result(result)

print("")
print("====================================================================")
print("Benchmark Complete")
print("====================================================================")

-- Print summary statistics
if jit and jit.status() then
  print("")
  print("Note: JIT compilation may take a few iterations to optimize hot code.")
  print("Actual performance may be higher than shown for frequently called code.")
end
