-- Lua_of_ocaml runtime support
-- Garbage Collection integration
--
-- Provides GC control and finalizers using Lua's __gc metamethod

--
-- GC Control Functions
--

-- Trigger a minor GC collection (generational GC)
function caml_gc_minor(_unit)
  -- Lua 5.4+ has generational mode, but we use incremental by default
  -- Call collectgarbage to run a GC step
  collectgarbage("step", 0)
  return 0
end

-- Trigger a major GC collection
function caml_gc_major(_unit)
  collectgarbage("collect")
  return 0
end

-- Trigger a full major GC collection
function caml_gc_full_major(_unit)
  collectgarbage("collect")
  return 0
end

-- Trigger GC compaction (no-op in Lua)
function caml_gc_compaction(_unit)
  return 0
end

-- Get GC counters
function caml_gc_counters(_unit)
  -- Return dummy counters: [tag, minor_words, promoted_words, major_words]
  return {254, 0, 0, 0}
end

-- Get quick GC statistics
function caml_gc_quick_stat(_unit)
  local mem = collectgarbage("count")
  -- Return array of 18 values matching OCaml's Gc.stat type
  return {0, mem, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

-- Get GC statistics (same as quick_stat)
function caml_gc_stat(unit)
  return caml_gc_quick_stat(unit)
end

-- Set GC control parameters (no-op, Lua manages GC automatically)
function caml_gc_set(_control)
  return 0
end

-- Get GC control parameters
function caml_gc_get(_unit)
  -- Return dummy control parameters
  return {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

-- Perform a major GC slice
function caml_gc_major_slice(_work)
  collectgarbage("step", math.max(_work, 100))
  return 0
end

-- Get count of minor words allocated
function caml_gc_minor_words(_unit)
  return 0
end

-- Get amount of free space in minor heap
function caml_get_minor_free(_unit)
  return 0
end

--
-- Finalizer Support
--

-- Global registry for finalizers
local all_finalizers = {}

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

-- Release all pending finalizers
function caml_final_release(_unit)
  -- Force GC to run finalizers
  collectgarbage("collect")
  return 0
end

--
-- Memory Profiling (no-op implementations)
--

function caml_memprof_start(_rate, _stack_size, _tracker)
  return 0
end

function caml_memprof_stop(_unit)
  return 0
end

function caml_memprof_discard(_t)
  return 0
end

--
-- Event Logging (no-op implementations)
--

function caml_eventlog_resume(_unit)
  return 0
end

function caml_eventlog_pause(_unit)
  return 0
end

function caml_gc_huge_fallback_count(_unit)
  return 0
end

-- Export all functions as a module
return {
  caml_gc_minor = caml_gc_minor,
  caml_gc_major = caml_gc_major,
  caml_gc_full_major = caml_gc_full_major,
  caml_gc_compaction = caml_gc_compaction,
  caml_gc_counters = caml_gc_counters,
  caml_gc_quick_stat = caml_gc_quick_stat,
  caml_gc_stat = caml_gc_stat,
  caml_gc_set = caml_gc_set,
  caml_gc_get = caml_gc_get,
  caml_gc_major_slice = caml_gc_major_slice,
  caml_gc_minor_words = caml_gc_minor_words,
  caml_get_minor_free = caml_get_minor_free,
  caml_final_register = caml_final_register,
  caml_final_register_called_without_value = caml_final_register_called_without_value,
  caml_final_release = caml_final_release,
  caml_memprof_start = caml_memprof_start,
  caml_memprof_stop = caml_memprof_stop,
  caml_memprof_discard = caml_memprof_discard,
  caml_eventlog_resume = caml_eventlog_resume,
  caml_eventlog_pause = caml_eventlog_pause,
  caml_gc_huge_fallback_count = caml_gc_huge_fallback_count,
}
