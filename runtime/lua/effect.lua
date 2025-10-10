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

-- Effect handlers (OCaml 5.x) using Lua coroutines
--
-- Maps OCaml effect handlers to Lua coroutines with fiber stacks.
-- This provides delimited continuations and algebraic effects.
--
-- Design:
-- - Fibers are represented as Lua coroutines
-- - Fiber stack tracks parent-child relationships
-- - Continuations are reified as fiber references
-- - Effect handlers are triples: {retc, exnc, effc}
--
-- Execution model:
-- - Current fiber executes with a low-level continuation
-- - When effect is performed, fiber yields to parent with effect value
-- - Parent's effect handler processes the effect
-- - Continuation can be resumed to return to child fiber

--
-- Fiber Stack Structure
--
-- Each fiber has:
-- - k: low-level continuation (Lua function)
-- - x: exception handler stack
-- - h: handler triple {retc, exnc, effc}
-- - e: parent fiber (enclosing stack)
-- - co: Lua coroutine (optional, for fiber)
--

-- Current execution stack
local current_stack = {
  k = 0,      -- low-level continuation
  x = 0,      -- exception stack
  h = 0,      -- handlers {retc, exnc, effc}
  e = 0       -- enclosing (parent) fiber
}

--
-- Stack Management
--

-- Save current stack for later restoration
-- Helper function for testing
function save_stack()
  return {
    k = current_stack.k,
    x = current_stack.x,
    h = current_stack.h,
    e = current_stack.e
  }
end

-- Restore saved stack
-- Helper function for testing
function restore_stack(stack)
  current_stack.k = stack.k
  current_stack.x = stack.x
  current_stack.h = stack.h
  current_stack.e = stack.e
end

-- Get current stack (for debugging)
-- Helper function for testing
function get_current_stack()
  return current_stack
end

--
-- Exception Handlers
--

--Provides: caml_push_trap
-- Push exception handler onto stack
function caml_push_trap(handler)
  current_stack.x = {h = handler, t = current_stack.x}
end

--Provides: caml_pop_trap
-- Pop exception handler from stack
function caml_pop_trap()
  if not current_stack.x or current_stack.x == 0 then
    return function(x)
      error(x)
    end
  end
  local h = current_stack.x.h
  current_stack.x = current_stack.x.t
  return h
end

--
-- Fiber Management
--

--Provides: caml_pop_fiber
-- Pop fiber: move to parent fiber
function caml_pop_fiber()
  local parent = current_stack.e
  current_stack.e = 0
  current_stack = parent
  return parent.k
end

--Provides: caml_alloc_stack
--Requires: caml_alloc_stack_call
-- Allocate new fiber with handlers
-- hv: value handler (continuation for normal return)
-- hx: exception handler
-- hf: effect handler
function caml_alloc_stack(hv, hx, hf)
  local handlers = {hv, hx, hf}

  -- Handler wrappers that call handlers in parent fiber
  local function hval_wrapper(x)
    -- Call hv in parent fiber
    local f = current_stack.h[1]
    return caml_alloc_stack_call(f, x)
  end

  local function hexn_wrapper(e)
    -- Call hx in parent fiber
    local f = current_stack.h[2]
    return caml_alloc_stack_call(f, e)
  end

  return {
    k = hval_wrapper,
    x = {h = hexn_wrapper, t = 0},
    h = handlers,
    e = 0
  }
end

--Provides: caml_alloc_stack_call
--Requires: caml_pop_fiber
-- Call function in parent fiber context
function caml_alloc_stack_call(f, x)
  local args = {x, caml_pop_fiber()}
  return f(table.unpack(args))
end

--Provides: caml_alloc_stack_disabled
-- Stub for when effects are disabled
function caml_alloc_stack_disabled()
  return 0
end

--
-- Continuation Management
--

-- Continuation representation: {tag=245, stack_ref, last_fiber}
local CONTINUATION_TAG = 245

-- Create continuation from current fiber
-- Helper function for testing
function make_continuation(stack, last)
  return {tag = CONTINUATION_TAG, stack, last}
end

--Provides: caml_continuation_use_noexc
-- Use continuation (one-shot: clears the continuation)
function caml_continuation_use_noexc(cont)
  local stack = cont[1]
  cont[1] = 0  -- Mark as used
  return stack
end

--Provides: caml_continuation_use_and_update_handler_noexc
--Requires: caml_continuation_use_noexc
-- Use continuation and update its handlers
function caml_continuation_use_and_update_handler_noexc(cont, hval, hexn, heff)
  local stack = caml_continuation_use_noexc(cont)
  if stack == 0 then
    return stack
  end
  local last = cont[2]
  last.h[1] = hval
  last.h[2] = hexn
  last.h[3] = heff
  return stack
end

--
-- Effect Operations
--

-- Exception for unhandled effects
local function make_unhandled_effect_exn(eff)
  -- Try to find registered Unhandled exception
  -- Fallback to generic exception
  return {
    tag = 248,
    "Effect.Unhandled",
    eff
  }
end

--Provides: caml_raise_unhandled
-- Raise unhandled effect exception
function caml_raise_unhandled(eff)
  error(make_unhandled_effect_exn(eff))
end

--Provides: caml_perform_effect
--Requires: make_continuation, caml_pop_fiber
-- Perform an effect
-- eff: the effect value
-- k0: current continuation
function caml_perform_effect(eff, k0)
  if current_stack.e == 0 then
    -- No effect handler installed
    error(make_unhandled_effect_exn(eff))
  end

  -- Get current effect handler
  local handler = current_stack.h[3]
  local last_fiber = current_stack
  last_fiber.k = k0

  -- Create continuation
  local cont = make_continuation(last_fiber, last_fiber)

  -- Move to parent fiber and execute effect handler
  local k1 = caml_pop_fiber()

  -- Call effect handler with effect, continuation, and parent continuation
  return handler(eff, cont, last_fiber, k1)
end

--Provides: caml_reperform_effect
--Requires: caml_pop_fiber, caml_continuation_use_noexc, caml_resume_stack
-- Re-perform an effect (for effect forwarding)
function caml_reperform_effect(eff, cont, last, k0)
  if current_stack.e == 0 then
    -- No effect handler installed
    local stack = caml_continuation_use_noexc(cont)
    caml_resume_stack(stack, last, k0)
    error(make_unhandled_effect_exn(eff))
  end

  -- Get current effect handler
  local handler = current_stack.h[3]
  local last_fiber = current_stack
  last_fiber.k = k0
  last.e = last_fiber
  cont[2] = last_fiber

  -- Move to parent fiber and execute effect handler
  local k1 = caml_pop_fiber()

  return handler(eff, cont, last_fiber, k1)
end

--
-- Continuation Resume
--

--Provides: caml_resume_stack
-- Resume a continuation with a value
function caml_resume_stack(stack, last, k)
  if not stack or stack == 0 then
    error("Effect.Continuation_already_resumed")
  end

  if last == 0 then
    last = stack
    -- Find deepest fiber
    while last.e ~= 0 do
      last = last.e
    end
  end

  current_stack.k = k
  last.e = current_stack
  current_stack = stack
  return stack.k
end

--Provides: caml_resume
--Requires: save_stack, restore_stack, caml_resume_stack
-- High-level resume function
function caml_resume(f, arg, stack, last)
  local saved_current_stack = save_stack()

  local success, result = pcall(function()
    current_stack = {k = 0, x = 0, h = 0, e = 0}

    local k = caml_resume_stack(stack, last, function(x)
      return x
    end)

    -- Call function with argument and continuation
    return f(arg, k)
  end)

  restore_stack(saved_current_stack)

  if not success then
    error(result)
  end

  return result
end

--
-- Coroutine Integration
--

-- Wrap function in coroutine for effect handling
-- Helper function for testing
function with_coroutine(f)
  return coroutine.create(function(...)
    return f(...)
  end)
end

-- Yield current fiber (for cooperative multitasking)
-- Helper function for testing
function fiber_yield(value)
  if current_stack.e == 0 then
    -- No parent fiber, can't yield
    return value
  end

  -- Save state and yield to parent
  return coroutine.yield(value)
end

-- Resume a fiber coroutine
-- Helper function for testing
function fiber_resume(co, value)
  if coroutine.status(co) == "dead" then
    error("Cannot resume dead fiber")
  end

  local success, result = coroutine.resume(co, value)
  if not success then
    error(result)
  end

  return result
end

--
-- Effect Handler Utilities
--

-- Check if effects are supported
-- Helper function for testing
function effects_supported()
  return true  -- Lua coroutines provide necessary support
end

--Provides: caml_get_continuation_callstack
-- Get continuation callstack (for debugging)
function caml_get_continuation_callstack()
  -- Lua doesn't provide detailed callstack for continuations
  -- Return empty list
  return {tag = 0}  -- Empty OCaml list
end

--
-- Condition Variables (for Stdlib.Condition)
--

--Provides: caml_ml_condition_new
function caml_ml_condition_new()
  return {condition = 1}
end

--Provides: caml_ml_condition_wait
function caml_ml_condition_wait()
  return 0
end

--Provides: caml_ml_condition_broadcast
function caml_ml_condition_broadcast()
  return 0
end

--Provides: caml_ml_condition_signal
function caml_ml_condition_signal()
  return 0
end

--
-- Error Handling
--

--Provides: jsoo_effect_not_supported
-- Raise "not supported" error
function jsoo_effect_not_supported()
  error("Effect handlers are not supported")
end
