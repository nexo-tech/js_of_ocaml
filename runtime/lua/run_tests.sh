#!/bin/bash
pass=0
fail=0
for f in test_*.lua; do
  if lua "$f" > /dev/null 2>&1; then
    echo "✓ $f"
    ((pass++))
  else
    echo "✗ $f"
    ((fail++))
  fi
done
echo ""
echo "=== Summary ==="
echo "Passed: $pass"
echo "Failed: $fail"
echo "Total: $((pass + fail))"
