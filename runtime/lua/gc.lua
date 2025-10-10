-- Js_of_ocaml runtime support
-- http://www.ocsigen.org/js_of_ocaml/
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, with linking exception;
-- either version 2.1 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

-- Garbage Collection integration
--
-- Provides GC control and finalizers using Lua's __gc metamethod

--
-- GC Control Functions
--

--Provides: caml_gc_minor
-- Trigger a minor GC collection (generational GC)
function caml_gc_minor(_unit)
  -- Lua 5.4+ has generational mode, but we use incremental by default
  -- Call collectgarbage to run a GC step
  collectgarbage("step", 0)
  return 0
end

--Provides: caml_gc_major
-- Trigger a major GC collection
function caml_gc_major(_unit)
  collectgarbage("collect")
  return 0
end

--Provides: caml_gc_full_major
-- Trigger a full major GC collection
function caml_gc_full_major(_unit)
  collectgarbage("collect")
  return 0
end

--Provides: caml_gc_compaction
-- Trigger GC compaction (no-op in Lua)
function caml_gc_compaction(_unit)
  return 0
end

--Provides: caml_gc_counters
-- Get GC counters
function caml_gc_counters(_unit)
  -- Return dummy counters: [tag, minor_words, promoted_words, major_words]
  return {254, 0, 0, 0}
end

--Provides: caml_gc_quick_stat
-- Get quick GC statistics
function caml_gc_quick_stat(_unit)
  local mem = collectgarbage("count")
  -- Return array of 18 values matching OCaml's Gc.stat type
  return {0, mem, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

--Provides: caml_gc_stat
--Requires: caml_gc_quick_stat
-- Get GC statistics (same as quick_stat)
function caml_gc_stat(unit)
  return caml_gc_quick_stat(unit)
end

--Provides: caml_gc_set
-- Set GC control parameters (no-op, Lua manages GC automatically)
function caml_gc_set(_control)
  return 0
end

--Provides: caml_gc_get
-- Get GC control parameters
function caml_gc_get(_unit)
  -- Return dummy control parameters
  return {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

--Provides: caml_gc_major_slice
-- Perform a major GC slice
function caml_gc_major_slice(_work)
  collectgarbage("step", math.max(_work, 100))
  return 0
end

--Provides: caml_gc_minor_words
-- Get count of minor words allocated
function caml_gc_minor_words(_unit)
  return 0
end

--Provides: caml_get_minor_free
-- Get amount of free space in minor heap
function caml_get_minor_free(_unit)
  return 0
end

--
-- Finalizer Support
--

-- Global registry for finalizers
local all_finalizers = {}

--Provides: caml_final_register
-- Register a finalizer that receives the value
function caml_final_register(f, x)
  -- Create a proxy table for the object
  if type(x) == "table" then
    local proxy = newproxy and newproxy(true) or {}
    local mt = getmetatable(proxy) or {}

    -- Set up __gc metamethod
    mt.__gc = function()
      -- Call the OCaml finalizer function with the value
      pcall(f, x)
    end

    setmetatable(proxy, mt)

    -- Keep proxy alive as long as x is alive
    if not all_finalizers[x] then
      all_finalizers[x] = {}
    end
    table.insert(all_finalizers[x], proxy)
  end

  return 0
end

--Provides: caml_final_register_called_without_value
-- Register a finalizer called without the value
function caml_final_register_called_without_value(cb, a)
  -- Create a proxy for finalization
  if type(a) == "table" then
    local proxy = newproxy and newproxy(true) or {}
    local mt = getmetatable(proxy) or {}

    -- Set up __gc metamethod that calls callback without value
    mt.__gc = function()
      -- Call the OCaml callback with unit
      pcall(cb, 0)
    end

    setmetatable(proxy, mt)

    -- Keep proxy alive
    if not all_finalizers[a] then
      all_finalizers[a] = {}
    end
    table.insert(all_finalizers[a], proxy)
  end

  return 0
end

--Provides: caml_final_release
-- Release all pending finalizers
function caml_final_release(_unit)
  -- Force GC to run finalizers
  collectgarbage("collect")
  return 0
end

--
-- Memory Profiling (no-op implementations)
--

--Provides: caml_memprof_start
function caml_memprof_start(_rate, _stack_size, _tracker)
  return 0
end

--Provides: caml_memprof_stop
function caml_memprof_stop(_unit)
  return 0
end

--Provides: caml_memprof_discard
function caml_memprof_discard(_t)
  return 0
end

--
-- Event Logging (no-op implementations)
--

--Provides: caml_eventlog_resume
function caml_eventlog_resume(_unit)
  return 0
end

--Provides: caml_eventlog_pause
function caml_eventlog_pause(_unit)
  return 0
end

--Provides: caml_gc_huge_fallback_count
function caml_gc_huge_fallback_count(_unit)
  return 0
end
