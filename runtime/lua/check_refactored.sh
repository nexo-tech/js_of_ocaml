#!/bin/bash
# Task 4 refactored modules
echo "=== Task 4: Data Structure Modules ==="
for f in test_fail.lua test_filename.lua test_stream.lua; do
  if lua "$f" > /dev/null 2>&1; then
    echo "✓ $f"
  else
    echo "✗ $f FAILED"
  fi
done

# Previously completed refactored modules
echo ""
echo "=== Previously Refactored Modules ==="
refactored=(
  test_array.lua test_list.lua test_option.lua test_result.lua
  test_buffer.lua test_mlBytes.lua test_lazy.lua test_queue.lua test_stack.lua
  test_obj.lua test_effect.lua test_lexing.lua
  test_digest.lua test_bigarray.lua
  test_marshal_header.lua test_marshal_io.lua test_marshal_int.lua 
  test_marshal_string.lua test_marshal_double.lua test_marshal_block.lua 
  test_marshal_blocks.lua test_marshal_value.lua test_marshal_public.lua 
  test_marshal_sharing.lua
  test_io_marshal.lua test_io_integration.lua
)

pass=0
fail=0
for f in "${refactored[@]}"; do
  if [ -f "$f" ]; then
    if lua "$f" > /dev/null 2>&1; then
      echo "✓ $f"
      ((pass++))
    else
      echo "✗ $f FAILED"
      ((fail++))
    fi
  fi
done

echo ""
echo "Refactored modules: $pass passed, $fail failed"
