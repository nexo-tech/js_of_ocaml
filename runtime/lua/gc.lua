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

_OCAML_gc = _OCAML_gc or {finalizers = {}}

--Provides: caml_gc_minor
function caml_gc_minor(_unit)
  collectgarbage("step", 0)
  return 0
end

--Provides: caml_gc_major
function caml_gc_major(_unit)
  collectgarbage("collect")
  return 0
end

--Provides: caml_gc_full_major
function caml_gc_full_major(_unit)
  collectgarbage("collect")
  return 0
end

--Provides: caml_gc_compaction
function caml_gc_compaction(_unit)
  return 0
end

--Provides: caml_gc_counters
function caml_gc_counters(_unit)
  return {254, 0, 0, 0}
end

--Provides: caml_gc_quick_stat
function caml_gc_quick_stat(_unit)
  local mem = collectgarbage("count")
  return {0, mem, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

--Provides: caml_gc_stat
--Requires: caml_gc_quick_stat
function caml_gc_stat(unit)
  return caml_gc_quick_stat(unit)
end

--Provides: caml_gc_set
function caml_gc_set(_control)
  return 0
end

--Provides: caml_gc_get
function caml_gc_get(_unit)
  return {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

--Provides: caml_gc_major_slice
function caml_gc_major_slice(_work)
  collectgarbage("step", math.max(_work, 100))
  return 0
end

--Provides: caml_gc_minor_words
function caml_gc_minor_words(_unit)
  return 0
end

--Provides: caml_get_minor_free
function caml_get_minor_free(_unit)
  return 0
end

--Provides: caml_final_register
function caml_final_register(f, x)
  if type(x) == "table" then
    local proxy
    if newproxy then
      proxy = newproxy(true)
      local mt = getmetatable(proxy)
      mt.__gc = function()
        pcall(f, x)
      end
    else
      proxy = {}
      setmetatable(proxy, {__gc = function()
        pcall(f, x)
      end})
    end
    if not _OCAML_gc.finalizers[x] then
      _OCAML_gc.finalizers[x] = {}
    end
    table.insert(_OCAML_gc.finalizers[x], proxy)
  end
  return 0
end

--Provides: caml_final_register_called_without_value
function caml_final_register_called_without_value(cb, a)
  if type(a) == "table" then
    local proxy
    if newproxy then
      proxy = newproxy(true)
      local mt = getmetatable(proxy)
      mt.__gc = function()
        pcall(cb, 0)
      end
    else
      proxy = {}
      setmetatable(proxy, {__gc = function()
        pcall(cb, 0)
      end})
    end
    if not _OCAML_gc.finalizers[a] then
      _OCAML_gc.finalizers[a] = {}
    end
    table.insert(_OCAML_gc.finalizers[a], proxy)
  end
  return 0
end

--Provides: caml_final_release
function caml_final_release(_unit)
  collectgarbage("collect")
  return 0
end

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
