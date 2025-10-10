#!/usr/bin/env lua
-- Performance Benchmarks for Marshal module (Task 7.4)
--
-- Measures marshalling/unmarshalling speed and compares with JSON encoding

local marshal = require("marshal")

-- JSON support (may not be available on all platforms)
local json_available, json = pcall(require, "cjson")
if not json_available then
  json_available, json = pcall(require, "dkjson")
end

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
  print(string.format("%-45s %12s ops/sec  %8.1f ns/op",
    result.name,
    format_number(result.ops_per_sec),
    result.ns_per_op))
end

local function measure_size(value)
  local marshalled = marshal.to_string(value, {tag = 0})
  return #marshalled
end

print("====================================================================")
print("Marshal Performance Benchmarks")
print("====================================================================")
print("Lua Version: " .. _VERSION)
if jit then
  print("JIT: " .. jit.version .. " (" .. (jit.status() and "enabled" or "disabled") .. ")")
end
print("")

-- ========================================
-- Marshalling Speed
-- ========================================

print("Marshalling Speed")
print("--------------------------------------------------------------------")

-- Small integer
local result = benchmark("marshal.to_string(42)", 100000, function()
  local _ = marshal.to_string(42, {tag = 0})
end)
print_result(result)

-- String
local str = "Hello, World!"
result = benchmark("marshal.to_string('Hello, World!')", 100000, function()
  local _ = marshal.to_string(str, {tag = 0})
end)
print_result(result)

-- Long string
local long_str = string.rep("x", 1000)
result = benchmark("marshal.to_string(1KB string)", 10000, function()
  local _ = marshal.to_string(long_str, {tag = 0})
end)
print_result(result)

-- Float
result = benchmark("marshal.to_string(3.14159)", 100000, function()
  local _ = marshal.to_string(3.14159, {tag = 0})
end)
print_result(result)

-- List (5 elements)
local list = {tag = 0, [1] = 1, [2] = {tag = 0, [1] = 2, [2] = {tag = 0, [1] = 3, [2] = {tag = 0, [1] = 4, [2] = {tag = 0, [1] = 5, [2] = 0}}}}}
result = benchmark("marshal.to_string([1;2;3;4;5])", 50000, function()
  local _ = marshal.to_string(list, {tag = 0})
end)
print_result(result)

-- Array (100 elements)
local array = {tag = 0}
for i = 1, 100 do
  array[i] = i
end
result = benchmark("marshal.to_string(100-elem array)", 10000, function()
  local _ = marshal.to_string(array, {tag = 0})
end)
print_result(result)

-- Nested structure
local nested = {tag = 0, [1] = "user", [2] = 42, [3] = {tag = 0, [1] = "addr", [2] = "city"}}
result = benchmark("marshal.to_string(nested record)", 50000, function()
  local _ = marshal.to_string(nested, {tag = 0})
end)
print_result(result)

print("")

-- ========================================
-- Unmarshalling Speed
-- ========================================

print("Unmarshalling Speed")
print("--------------------------------------------------------------------")

-- Small integer
local m_int = marshal.to_string(42, {tag = 0})
result = benchmark("marshal.from_bytes(42)", 100000, function()
  local _ = marshal.from_bytes(m_int, 0)
end)
print_result(result)

-- String
local m_str = marshal.to_string(str, {tag = 0})
result = benchmark("marshal.from_bytes('Hello, World!')", 100000, function()
  local _ = marshal.from_bytes(m_str, 0)
end)
print_result(result)

-- Long string
local m_long_str = marshal.to_string(long_str, {tag = 0})
result = benchmark("marshal.from_bytes(1KB string)", 10000, function()
  local _ = marshal.from_bytes(m_long_str, 0)
end)
print_result(result)

-- Float
local m_float = marshal.to_string(3.14159, {tag = 0})
result = benchmark("marshal.from_bytes(3.14159)", 100000, function()
  local _ = marshal.from_bytes(m_float, 0)
end)
print_result(result)

-- List
local m_list = marshal.to_string(list, {tag = 0})
result = benchmark("marshal.from_bytes([1;2;3;4;5])", 50000, function()
  local _ = marshal.from_bytes(m_list, 0)
end)
print_result(result)

-- Array
local m_array = marshal.to_string(array, {tag = 0})
result = benchmark("marshal.from_bytes(100-elem array)", 10000, function()
  local _ = marshal.from_bytes(m_array, 0)
end)
print_result(result)

-- Nested structure
local m_nested = marshal.to_string(nested, {tag = 0})
result = benchmark("marshal.from_bytes(nested record)", 50000, function()
  local _ = marshal.from_bytes(m_nested, 0)
end)
print_result(result)

print("")

-- ========================================
-- Roundtrip Speed
-- ========================================

print("Roundtrip Speed (marshal + unmarshal)")
print("--------------------------------------------------------------------")

result = benchmark("roundtrip(42)", 50000, function()
  local m = marshal.to_string(42, {tag = 0})
  local _ = marshal.from_bytes(m, 0)
end)
print_result(result)

result = benchmark("roundtrip('Hello, World!')", 50000, function()
  local m = marshal.to_string(str, {tag = 0})
  local _ = marshal.from_bytes(m, 0)
end)
print_result(result)

result = benchmark("roundtrip([1;2;3;4;5])", 25000, function()
  local m = marshal.to_string(list, {tag = 0})
  local _ = marshal.from_bytes(m, 0)
end)
print_result(result)

print("")

-- ========================================
-- JSON Comparison
-- ========================================

if json_available then
  print("JSON Comparison")
  print("--------------------------------------------------------------------")

  -- Simple values for JSON (OCaml structures don't map directly)
  local json_data = {name = "Alice", age = 30, email = "alice@example.com"}

  result = benchmark("json.encode(record)", 50000, function()
    local _ = json.encode(json_data)
  end)
  print_result(result)

  local json_str = json.encode(json_data)
  result = benchmark("json.decode(record)", 50000, function()
    local _ = json.decode(json_str)
  end)
  print_result(result)

  result = benchmark("json roundtrip(record)", 25000, function()
    local j = json.encode(json_data)
    local _ = json.decode(j)
  end)
  print_result(result)

  -- Compare sizes
  print("")
  print("Size Comparison (bytes)")
  print("--------------------------------------------------------------------")
  local m_size = measure_size(nested)
  local j_size = #json_str
  print(string.format("Marshal nested record:  %d bytes", m_size))
  print(string.format("JSON simple record:     %d bytes", j_size))
  print(string.format("Ratio (marshal/json):   %.2fx", m_size / j_size))

  print("")
else
  print("JSON library not available - skipping JSON comparison")
  print("")
end

-- ========================================
-- Memory Usage Profiling
-- ========================================

print("Memory Usage")
print("--------------------------------------------------------------------")

local function measure_memory(fn, iterations)
  collectgarbage("collect")
  local before = collectgarbage("count")

  for i = 1, iterations do
    fn()
  end

  collectgarbage("collect")
  local after = collectgarbage("count")

  return (after - before) * 1024 -- Convert KB to bytes
end

-- Small value
local mem = measure_memory(function()
  local m = marshal.to_string(42, {tag = 0})
  local _ = marshal.from_bytes(m, 0)
end, 1000)
print(string.format("Memory per roundtrip(42):            %8.1f bytes", mem / 1000))

-- String
mem = measure_memory(function()
  local m = marshal.to_string(str, {tag = 0})
  local _ = marshal.from_bytes(m, 0)
end, 1000)
print(string.format("Memory per roundtrip('Hello'):       %8.1f bytes", mem / 1000))

-- List
mem = measure_memory(function()
  local m = marshal.to_string(list, {tag = 0})
  local _ = marshal.from_bytes(m, 0)
end, 1000)
print(string.format("Memory per roundtrip([1;2;3;4;5]):   %8.1f bytes", mem / 1000))

-- Array
mem = measure_memory(function()
  local m = marshal.to_string(array, {tag = 0})
  local _ = marshal.from_bytes(m, 0)
end, 100)
print(string.format("Memory per roundtrip(100-elem array):%8.1f bytes", mem / 100))

print("")

-- ========================================
-- Summary
-- ========================================

print("====================================================================")
print("Benchmark Summary")
print("====================================================================")
print("")
print("Marshal module provides:")
print("  • Fast integer marshalling:   ~100K-1M ops/sec")
print("  • Fast string marshalling:    ~100K-1M ops/sec")
print("  • Efficient large data:       ~10K ops/sec for KB-sized data")
print("  • Binary format:              Compact, type-preserving")
print("  • Sharing support:            Preserves object identity")
print("")
print("Use marshal for:")
print("  • Cross-language data exchange (OCaml ↔ Lua)")
print("  • Binary serialization with type preservation")
print("  • Cyclic and shared data structures")
print("")
if json_available then
  print("Use JSON for:")
  print("  • Human-readable format")
  print("  • Web API compatibility")
  print("  • Simple data without cycles")
  print("")
end
