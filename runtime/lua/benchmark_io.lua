#!/usr/bin/env lua
-- Performance Benchmarks for I/O Operations
--
-- Measures performance of marshal, channels, buffers, hashtables, and comparison operations

-- Preload our runtime modules (they clash with standard Lua modules)
package.loaded.io = dofile("io.lua")
local io_module = package.loaded.io

local marshal = require("marshal")
local buffer = require("buffer")
local hashtbl = require("hashtbl")
local compare = require("compare")
local hash = require("hash")
local core = require("core")

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
  print(string.format("%-50s %12s ops/sec  %8.1f ns/op",
    result.name,
    format_number(result.ops_per_sec),
    result.ns_per_op))
end

print("====================================================================")
print("I/O Performance Benchmarks")
print("====================================================================")
print("Lua Version: " .. _VERSION)
if jit then
  print("JIT: " .. jit.version .. " (" .. (jit.status() and "enabled" or "disabled") .. ")")
end
print("")

-- Helper: create OCaml list
local function make_list(tbl)
  local list = 0
  for i = #tbl, 1, -1 do
    list = {tag = 0, [1] = tbl[i], [2] = list}
  end
  return list
end

-- Helper: open temp file for writing
local function open_temp_write()
  local filename = "/tmp/bench_" .. os.time() .. "_" .. math.random(10000) .. ".dat"
  local flags = make_list({1, 3, 4, 6})  -- WRONLY, CREAT, TRUNC, BINARY
  local fd = io_module.caml_sys_open(filename, flags, 420)
  local chan = io_module.caml_ml_open_descriptor_out(fd)
  return chan, filename
end

-- Helper: cleanup temp file
local function cleanup_temp(filename)
  os.remove(filename)
end

print("Marshal Serialization")
print("--------------------------------------------------------------------")

local result = benchmark("marshal.to_string(42)", 100000, function()
  local _ = marshal.to_string(42, {tag = 0})
end)
print_result(result)

result = benchmark("marshal.to_string(string 100 chars)", 50000, function()
  local _ = marshal.to_string(string.rep("x", 100), {tag = 0})
end)
print_result(result)

result = benchmark("marshal.to_string(list of 10 ints)", 50000, function()
  local list = make_list({1, 2, 3, 4, 5, 6, 7, 8, 9, 10})
  local _ = marshal.to_string(list, {tag = 0})
end)
print_result(result)

result = benchmark("marshal.to_string(list of 100 ints)", 10000, function()
  local list = make_list({})
  for i = 1, 100 do
    list = {tag = 0, [1] = i, [2] = list}
  end
  local _ = marshal.to_string(list, {tag = 0})
end)
print_result(result)

local marshaled_int = marshal.to_string(42, {tag = 0})
result = benchmark("marshal.from_bytes(int)", 100000, function()
  local _ = marshal.from_bytes(marshaled_int, 0)
end)
print_result(result)

local marshaled_string = marshal.to_string(string.rep("x", 100), {tag = 0})
result = benchmark("marshal.from_bytes(string 100 chars)", 50000, function()
  local _ = marshal.from_bytes(marshaled_string, 0)
end)
print_result(result)

local marshaled_list = marshal.to_string(make_list({1, 2, 3, 4, 5, 6, 7, 8, 9, 10}), {tag = 0})
result = benchmark("marshal.from_bytes(list of 10 ints)", 50000, function()
  local _ = marshal.from_bytes(marshaled_list, 0)
end)
print_result(result)

print("")
print("Channel I/O Operations")
print("--------------------------------------------------------------------")

result = benchmark("channel write int (1000 values)", 100, function()
  local chan, filename = open_temp_write()
  for i = 1, 1000 do
    marshal.to_channel(chan, i, {tag = 0})
  end
  io_module.caml_ml_flush(chan)
  io_module.caml_ml_close_channel(chan)
  cleanup_temp(filename)
end)
print_result(result)

result = benchmark("channel write/read roundtrip (100 ints)", 100, function()
  local chan, filename = open_temp_write()
  for i = 1, 100 do
    marshal.to_channel(chan, i, {tag = 0})
  end
  io_module.caml_ml_flush(chan)
  io_module.caml_ml_close_channel(chan)

  local flags = make_list({0, 6})  -- RDONLY, BINARY
  local fd = io_module.caml_sys_open(filename, flags, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd)
  for i = 1, 100 do
    local _ = marshal.from_channel(chan_in)
  end
  io_module.caml_ml_close_channel(chan_in)
  cleanup_temp(filename)
end)
print_result(result)

result = benchmark("channel output_char (10000 chars)", 100, function()
  local chan, filename = open_temp_write()
  for i = 1, 10000 do
    io_module.caml_ml_output_char(chan, 65)
  end
  io_module.caml_ml_flush(chan)
  io_module.caml_ml_close_channel(chan)
  cleanup_temp(filename)
end)
print_result(result)

result = benchmark("channel output string (1KB)", 1000, function()
  local chan, filename = open_temp_write()
  local str = string.rep("x", 1024)
  io_module.caml_ml_output(chan, str, 0, 1024)
  io_module.caml_ml_flush(chan)
  io_module.caml_ml_close_channel(chan)
  cleanup_temp(filename)
end)
print_result(result)

result = benchmark("channel output string (10KB)", 500, function()
  local chan, filename = open_temp_write()
  local str = string.rep("x", 10240)
  io_module.caml_ml_output(chan, str, 0, 10240)
  io_module.caml_ml_flush(chan)
  io_module.caml_ml_close_channel(chan)
  cleanup_temp(filename)
end)
print_result(result)

result = benchmark("channel flush (empty)", 10000, function()
  local chan, filename = open_temp_write()
  io_module.caml_ml_flush(chan)
  io_module.caml_ml_close_channel(chan)
  cleanup_temp(filename)
end)
print_result(result)

print("")
print("Buffer Operations")
print("--------------------------------------------------------------------")

result = benchmark("buffer.create(256)", 100000, function()
  local _ = buffer.caml_buffer_create(256)
end)
print_result(result)

local buf = buffer.caml_buffer_create(1024)
result = benchmark("buffer.add_char (1000 chars)", 10000, function()
  buffer.caml_buffer_reset(buf)
  for i = 1, 1000 do
    buffer.caml_buffer_add_char(buf, 65)
  end
end)
print_result(result)

buf = buffer.caml_buffer_create(1024)
result = benchmark("buffer.add_string (100 byte string)", 10000, function()
  buffer.caml_buffer_reset(buf)
  local str = string.rep("x", 100)
  buffer.caml_buffer_add_string(buf, str)
end)
print_result(result)

buf = buffer.caml_buffer_create(10240)
result = benchmark("buffer.add_string (1KB string)", 10000, function()
  buffer.caml_buffer_reset(buf)
  local str = string.rep("x", 1024)
  buffer.caml_buffer_add_string(buf, str)
end)
print_result(result)

buf = buffer.caml_buffer_create(1024)
for i = 1, 1000 do
  buffer.caml_buffer_add_char(buf, 65)
end
result = benchmark("buffer.contents (1000 chars)", 100000, function()
  local _ = buffer.caml_buffer_contents(buf)
end)
print_result(result)

buf = buffer.caml_buffer_create(1024)
for i = 1, 1000 do
  buffer.caml_buffer_add_char(buf, 65)
end
result = benchmark("buffer.length (1000 chars)", 1000000, function()
  local _ = buffer.caml_buffer_length(buf)
end)
print_result(result)

print("")
print("Hashtable Operations")
print("--------------------------------------------------------------------")

result = benchmark("hashtbl.create(16)", 100000, function()
  local _ = hashtbl.caml_hash_create(16)
end)
print_result(result)

local tbl = hashtbl.caml_hash_create(256)
result = benchmark("hashtbl.add (100 int keys)", 10000, function()
  hashtbl.caml_hash_clear(tbl)
  for i = 1, 100 do
    hashtbl.caml_hash_add(tbl, i, i * 10)
  end
end)
print_result(result)

tbl = hashtbl.caml_hash_create(256)
for i = 1, 100 do
  hashtbl.caml_hash_add(tbl, i, i * 10)
end
result = benchmark("hashtbl.find (100 lookups, hit)", 10000, function()
  for i = 1, 100 do
    local _ = hashtbl.caml_hash_find(tbl, i)
  end
end)
print_result(result)

tbl = hashtbl.caml_hash_create(256)
for i = 1, 100 do
  hashtbl.caml_hash_add(tbl, i, i * 10)
end
result = benchmark("hashtbl.mem (100 lookups, hit)", 10000, function()
  for i = 1, 100 do
    local _ = hashtbl.caml_hash_mem(tbl, i)
  end
end)
print_result(result)

tbl = hashtbl.caml_hash_create(256)
for i = 1, 100 do
  hashtbl.caml_hash_add(tbl, i, i * 10)
end
result = benchmark("hashtbl.find (100 lookups, miss)", 10000, function()
  for i = 200, 299 do
    local ok, _ = pcall(hashtbl.caml_hash_find, tbl, i)
  end
end)
print_result(result)

result = benchmark("hashtbl.remove (100 keys)", 1000, function()
  local t = hashtbl.caml_hash_create(256)
  for i = 1, 100 do
    hashtbl.caml_hash_add(t, i, i * 10)
  end
  for i = 1, 100 do
    hashtbl.caml_hash_remove(t, i)
  end
end)
print_result(result)

tbl = hashtbl.caml_hash_create(256)
for i = 1, 1000 do
  hashtbl.caml_hash_add(tbl, "key" .. i, i)
end
result = benchmark("hashtbl.length (1000 entries)", 100000, function()
  local _ = hashtbl.caml_hash_length(tbl)
end)
print_result(result)

print("")
print("Comparison Operations")
print("--------------------------------------------------------------------")

result = benchmark("compare.caml_compare(42, 100)", 500000, function()
  local _ = compare.caml_compare(42, 100)
end)
print_result(result)

result = benchmark("compare.caml_compare(strings)", 500000, function()
  local _ = compare.caml_compare("hello", "world")
end)
print_result(result)

local list1 = make_list({1, 2, 3, 4, 5})
local list2 = make_list({1, 2, 3, 4, 6})
result = benchmark("compare.caml_compare(list of 5 ints)", 100000, function()
  local _ = compare.caml_compare(list1, list2)
end)
print_result(result)

result = benchmark("compare.caml_equal(ints, equal)", 500000, function()
  local _ = compare.caml_equal(42, 42)
end)
print_result(result)

result = benchmark("compare.caml_equal(ints, not equal)", 500000, function()
  local _ = compare.caml_equal(42, 100)
end)
print_result(result)

result = benchmark("compare.caml_equal(strings, equal)", 500000, function()
  local _ = compare.caml_equal("hello", "hello")
end)
print_result(result)

result = benchmark("compare.caml_notequal(ints)", 500000, function()
  local _ = compare.caml_notequal(42, 100)
end)
print_result(result)

result = benchmark("compare.caml_lessthan(ints)", 500000, function()
  local _ = compare.caml_lessthan(42, 100)
end)
print_result(result)

result = benchmark("compare.caml_greaterthan(ints)", 500000, function()
  local _ = compare.caml_greaterthan(100, 42)
end)
print_result(result)

print("")
print("Hashing Operations")
print("--------------------------------------------------------------------")

result = benchmark("hash.caml_hash_default(42)", 500000, function()
  local _ = hash.caml_hash_default(42)
end)
print_result(result)

result = benchmark("hash.caml_hash_default(string 10 chars)", 500000, function()
  local _ = hash.caml_hash_default("hellohello")
end)
print_result(result)

result = benchmark("hash.caml_hash_default(string 100 chars)", 200000, function()
  local _ = hash.caml_hash_default(string.rep("x", 100))
end)
print_result(result)

local list = make_list({1, 2, 3, 4, 5})
result = benchmark("hash.caml_hash_default(list of 5 ints)", 200000, function()
  local _ = hash.caml_hash_default(list)
end)
print_result(result)

local list = make_list({1, 2, 3, 4, 5, 6, 7, 8, 9, 10})
result = benchmark("hash.caml_hash_default(list of 10 ints)", 100000, function()
  local _ = hash.caml_hash_default(list)
end)
print_result(result)

result = benchmark("hash.caml_hash_mix_int(1000, 42)", 1000000, function()
  local _ = hash.caml_hash_mix_int(1000, 42)
end)
print_result(result)

print("")
print("====================================================================")
print("Benchmark Complete")
print("====================================================================")
