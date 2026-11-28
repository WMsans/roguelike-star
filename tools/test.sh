#!/bin/sh
# The test runner with the error gate the plan's Global Constraints promise: a GDScript runtime
# error aborts only the erroring function, so run_tests.gd can still print "N passed, 0 failed"
# when a part's fire()/continuous_tick()/process() died. Any SCRIPT ERROR in the run fails here.
# Usage: tools/test.sh [file-name-filter]
cd "$(dirname "$0")/.." || exit 1
out=$(godot --headless --path . -s res://tests/run_tests.gd -- "$@" 2>&1)
code=$?
printf '%s\n' "$out"
if printf '%s\n' "$out" | grep -q 'SCRIPT ERROR'; then
	echo "FAIL: SCRIPT ERROR in the run"
	exit 1
fi
exit "$code"
