#!/usr/bin/env lua
-- Test complex block marshalling

local marshal = require("marshal")

-- Test 1: Simple array-style table
print("Test 1: Simple array")
local t1 = {42, "hello", 3.14}
local m1 = marshal.to_string(t1)
local r1 = marshal.from_bytes(m1, 0)
print("  Input:", t1[1], t1[2], t1[3])
print("  Output:", r1[1], r1[2], r1[3])
print("  " .. (r1[1] == 42 and r1[2] == "hello" and math.abs(r1[3] - 3.14) < 0.01 and "✓ PASS" or "✗ FAIL"))

-- Test 2: Nested tables
print("\nTest 2: Nested tables")
local t2 = {{1, 2}, {3, 4}}
local m2 = marshal.to_string(t2)
local r2 = marshal.from_bytes(m2, 0)
print("  Input:", t2[1][1], t2[1][2], t2[2][1], t2[2][2])
print("  Output:", r2[1] and r2[1][1], r2[1] and r2[1][2], r2[2] and r2[2][1], r2[2] and r2[2][2])
print("  " .. (r2[1] and r2[1][1] == 1 and r2[1][2] == 2 and r2[2][1] == 3 and r2[2][2] == 4 and "✓ PASS" or "✗ FAIL"))

-- Test 3: Mixed types
print("\nTest 3: Mixed types")
local t3 = {100, "test", {5, 6}}
local m3 = marshal.to_string(t3)
local r3 = marshal.from_bytes(m3, 0)
print("  Input:", t3[1], t3[2], t3[3] and t3[3][1], t3[3] and t3[3][2])
print("  Output:", r3[1], r3[2], r3[3] and r3[3][1], r3[3] and r3[3][2])
print("  " .. (r3[1] == 100 and r3[2] == "test" and r3[3] and r3[3][1] == 5 and r3[3][2] == 6 and "✓ PASS" or "✗ FAIL"))

print("\nAll tests completed!")
