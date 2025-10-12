# Task 2.5.1: JS Dispatch Model Analysis

## Date: 2025-10-12

## Executive Summary

Analyzed js_of_ocaml's Printf closure generation to understand data-driven dispatch model. JS uses **nested labeled blocks + for-loop + switch** pattern, fundamentally different from Lua's current address-based block dispatch.

## Key Findings

### 1. JS Dispatch Structure

**Pattern**: Nested labeled blocks with data-driven switch inside loop

```javascript
function make_printf$0(counter, k$2, acc$4, fmt$2){
  a:      // Label for case 0
  {
    b:    // Label for case 1
    {
      // ... more nested labels (c, d, e, f, g, h, i, j, k)
      {
        var k = k$2, acc = acc$4, fmt = fmt$2;  // ← CRITICAL: Variables initialized BEFORE loop
        l:    // Label for case 23
        for(;;){  // ← Infinite loop
          if(typeof fmt === "number") return caml_call1(k, acc);
          switch(fmt[0]){  // ← Data-driven: dispatch on fmt's tag
            case 0: break a;
            case 1: break b;
            case 2: break c;
            case 3: return make_padding(...);
            case 4: return make_int_padding_precision(...);
            // ... more cases ...
            case 10:
              acc = [7, acc];  // ← Modify dispatch variables
              fmt = fmt[1];
              break;  // ← Continue loop with new values
            case 18:
              // Nested if for sub-cases
              if(0 === a[0]){
                // Modify ALL dispatch variables
                k = function(kacc){...};
                acc = 0;
                fmt = fmt$0;
              }
              else{...}
              break;
            case 23: break l;
            default: return make_custom$0(...);
          }
        }
        // Code after loop: handles cases that broke to outer labels
        var rest = fmt[2], ign = fmt[1];
        if(typeof ign === "number"){...}
        // ... more post-loop logic
      }
    }
  }
}
```

### 2. Key Characteristics

**Data-Driven Dispatch**:
- Dispatch variable: `fmt` (tagged variant)
- Switch on `fmt[0]` (the tag/discriminant)
- Control flow determined by **data**, not block addresses

**Variable Management**:
- Dispatch variables (`k`, `acc`, `fmt`) initialized from parameters **before** entering loop
- Cases can modify dispatch variables and continue loop
- Modified variables drive next iteration

**Control Flow**:
- **Simple cases**: Return directly
- **Loop cases**: Modify vars, break, continue loop
- **Complex cases**: Break to outer labeled blocks
- **Post-loop**: Handle remaining cases outside loop

**Trampoline Pattern**:
- Check `counter >= 50` for tail call optimization
- Return trampoline object instead of direct call
- Prevents stack overflow in deeply nested calls

### 3. Switch Case Mapping

| Case | Action | Purpose |
|------|--------|---------|
| 0 | break a | String with no padding |
| 1 | break b | String with some padding type |
| 2 | break c | String with different padding |
| 3 | return | String padding (direct call) |
| 4 | return | Int with padding/precision |
| 5 | return | Int32 with padding/precision |
| 6 | return | Nativeint with padding/precision |
| 7 | return | Int64 with padding/precision |
| 8 | break d | Another padding type |
| 9 | return | Bool conversion |
| 10 | modify + break | Flush |
| 11 | modify + break | String literal |
| 12 | modify + break | Char literal |
| 13 | break e | Format padding type |
| 14 | break f | Another format type |
| 15 | break g | Another format type |
| 16 | break h | Another format type |
| 17 | modify + break | Formatting literal |
| 18 | modify + break | Meta-format (most complex) |
| 19 | throw | Assert failure |
| 20 | break i | Format type |
| 21 | break j | Format type |
| 22 | break k | Format type |
| 23 | break l | Exit loop |
| default | return | Custom formatting |

**After loop** (when breaking from labels a-k):
- Extract `fmt[2]` (rest) and `fmt[1]` (ign)
- Check `typeof ign` to determine sub-case
- Call appropriate helper (make_invalid_arg, make_from_fmtty, etc.)
- All cases use trampoline pattern

### 4. Labeled Block Purposes

Each labeled block (a-k) corresponds to a different format specifier type. When a case breaks to a label, execution jumps to the code **after** that labeled block.

Example flow:
```javascript
case 0: break a;  // Jump to code after block 'a'
```

The code after block 'a' handles the specific format type for case 0.

### 5. Why This Works

**Variable Initialization**: All dispatch variables are initialized from parameters before the loop starts. This ensures:
- Entry point has all required variables set
- No "nil variable" bugs like Lua's current approach
- Variables available throughout execution

**Data-Driven**: Control flow follows the data (fmt structure), not hardcoded block addresses:
- `fmt` is a recursive variant representing the format string
- Each iteration peels off one layer: `fmt = fmt[1]` or `fmt = rest`
- When `fmt` is a number (empty), we're done

**Label Jumps**: Breaking to outer labels is JS's way of implementing "computed goto":
- Each format case has a distinct handler
- Labels group related functionality
- Breaking jumps to the appropriate handler

### 6. Comparison: JS vs Lua Current

| Aspect | JS (js_of_ocaml) | Lua (lua_of_ocaml current) |
|--------|------------------|---------------------------|
| Dispatch | Data-driven (switch on fmt[0]) | Address-driven (_next_block number) |
| Variables | Initialized before loop | Not always initialized at entry |
| Control flow | Labels + switch in loop | Block numbers + explicit jumps |
| Entry point | Always enters loop with vars set | Jumps to entry block address |
| Loop structure | for(;;) { switch(...) } | while true do if _next_block == X |
| Bug risk | Low (vars always set) | High (entry path may skip init) |

## Root Cause of Printf Bug (Confirmed)

The Lua implementation's **address-driven dispatch** causes the Printf bug:

**Entry Block Problem**:
- Lua entry block: Block 484
- Block 484 uses variable `v270`
- Block 484 reachable by TWO paths:
  1. **Entry path**: v343 set from params, v270 NIL ❌
  2. **Block 482 path**: v343 AND v270 both set ✅

**JS Doesn't Have This**:
- JS initializes `fmt`, `k`, `acc` from parameters BEFORE loop
- JS entry is always the loop start, not a specific case
- All variables are set before any case code runs

## Implications for Lua Refactor

### Option A: Mimic JS Structure Exactly ✅ RECOMMENDED

Restructure Lua code generation to match JS:

```lua
function closure(v343, v344, v345)
  local k = v344
  local acc = v345
  local fmt = v343

  while true do
    if type(fmt) == "number" then
      return caml_call1(k, acc)
    end

    local tag = fmt[1]  -- fmt[0] in JS, but Lua uses 1-indexing

    if tag == 0 then
      -- Handle case 0 (was block a)
      local rest = fmt[3]
      local ign = fmt[2]
      if type(ign) == "number" then...
    elseif tag == 1 then
      -- Handle case 1 (was block b)
      ...
    elseif tag == 10 then
      -- Modify and continue
      acc = {7, acc}
      fmt = fmt[2]
      -- Loop continues
    elseif tag == 18 then
      -- Complex nested case
      local a = fmt[2]
      if a[1] == 0 then
        local rest = fmt[3]
        local fmt_inner = a[2][2]
        k = function(kacc)
          return make_printf(k, {1, acc, {0, kacc}}, rest)
        end
        acc = 0
        fmt = fmt_inner
        -- Loop continues with new values
      else
        ...
      end
    ...
    end
  end
end
```

**Advantages**:
- Matches proven working JS structure
- No "entry block" concept - always start at loop
- Variables initialized before loop
- Data-driven dispatch (tag-based)
- No uninitialized variable bugs

### Option B: Fix Current Approach (Band-Aid) ⚠️ NOT RECOMMENDED

Keep address-driven dispatch but add entry block dependency initialization:
- Analyze entry block for uninitialized variables
- Trace back to find their sources
- Initialize before dispatch loop

**Problems**:
- Complex dependency analysis required
- Fragile (breaks if IR structure changes)
- Still uses address-driven model (conceptual mismatch)
- Doesn't fix root architectural issue

## Next Steps (Task 2.5.2+)

1. **Task 2.5.2**: Analyze IR structure
   - How does OCaml IR represent Printf?
   - What are the "blocks" in the IR?
   - How does js_of_ocaml translate IR to switch cases?

2. **Task 2.5.3**: Design Lua data-driven dispatch
   - Design tag-based dispatch for Lua
   - Handle 1-indexed arrays (tag at [1], not [0])
   - Handle label breaks (convert to if-chain)

3. **Task 2.5.4**: Prototype simple case
   - Implement for simple closure (not Printf yet)
   - Verify variables initialized before loop
   - Test with existing test suite

4. **Task 2.5.5**: Refactor compile_blocks_with_labels
   - Change from address-driven to data-driven
   - Generate switch-style if-elseif chain
   - Handle loop-continue cases vs return cases

5. **Task 2.5.6**: Test Printf
   - Verify "Hello %d\n" works
   - Test all format specifiers
   - Run full Printf test suite

6. **Task 2.5.7**: Optimize and document
   - Performance tuning
   - Code cleanup
   - Documentation

## Files Analyzed

- `/tmp/simple_printf.ml.pretty.js` (345KB)
  - Function: `make_printf$0` (lines 7458-7750)
  - 24 switch cases + default
  - 12 nested labeled blocks
  - Source locations from camlinternalFormat.ml

- `/tmp/simple_printf.ml.bc.debug.lua` (1.1MB)
  - Current Lua output (buggy)
  - Address-driven dispatch
  - Entry block 484 bug confirmed

## References

- `js_of_ocaml/compiler/lib/generate.ml`: JS code generation
- `js_of_ocaml/compiler/lib/structure.ml`: Control flow analysis
- `ocaml/stdlib/camlinternalFormat.ml`: Printf implementation (lines 1518-1626)
- Task 2.6 analysis: `/home/snowbear/projects/js_of_ocaml/TASK_2_6_ANALYSIS.md`

## Conclusion

The JS dispatch model is **data-driven with variables initialized before the dispatch loop**. This is the correct approach and must be replicated in Lua. The current Lua approach (address-driven with hardcoded entry blocks) is architecturally flawed and causes the Printf bug.

**Recommendation**: Proceed with Task 2.5.2 to analyze IR structure, then implement Option A (mimic JS structure exactly) in Tasks 2.5.3-2.5.5.
