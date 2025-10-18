# Archived Documentation

This directory contains historical task documentation from lua_of_ocaml development.

## Contents

### SPLAN Tasks (Strategic Plan)
- `TASK_2_*.md` - Phase 2 closure and dispatch fixes
- `TASK_3_*.md` - Phase 3 Printf implementation tasks
- `ASSESSMENT.md` - Initial root cause analysis

### XPLAN Tasks (Printf Fix Plan)
- `XPLAN_PHASE*.md` - Systematic Printf fix phases
- `TASK_5_3K*.md` - Task 5.3k (Set_field bug) investigation and fixes
- `XPLAN_TEST_SUITE.md` - Test suite (kept in root for reference)

### Session Documents
- `SESSION_SUMMARY.md` - Development session summaries
- `NEXT_STEPS_5_3K.md` - Next steps documentation
- `PARTIAL.md` - Partial fix documentation

## Why Archived

These documents were created during active development to track progress and document findings. They contain valuable historical information but are no longer needed for daily reference.

## Master Documentation (Root Directory)

The following documents remain in the root directory as master references:

**Planning & Status**:
- `SPLAN.md` - Strategic plan (COMPLETE)
- `XPLAN.md` - Printf systematic fix plan (COMPLETE)
- `UPLAN.md` - Usage & stabilization plan (Phases 1-2 COMPLETE)
- `APLAN.md` - Application plan for hello_lua
- `LUA.md` - Master roadmap and checklist

**Guides**:
- `USAGE.md` - Comprehensive usage guide
- `CLAUDE.md` - Development guidelines
- `ENV.md` - Environment setup guide
- `README_lua_of_ocaml.md` - Project README

**Results**:
- `OPTIMAL_LINKING.md` - Minimal linking implementation
- `UPLAN_PHASE1_RESULTS.md` - Phase 1 comprehensive test results
- `examples/README_lua_examples.md` - Example documentation

## Accessing Archived Docs

All files are preserved in this directory for historical reference:

```bash
# View archived document
less docs/archive/TASK_5_3K_COMPLETE.md

# Search across archives
grep -r "Set_field" docs/archive/
```

---

**Note**: These archives document the journey to production-ready lua_of_ocaml. They show the debugging process, decision points, and problem-solving approaches used.
