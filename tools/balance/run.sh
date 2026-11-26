#!/bin/sh
# The balance runner, always with the flags that make fights reproduce (see README.md).
exec godot --headless --fixed-fps 60 --path "$(dirname "$0")/../.." -s res://tools/balance/run.gd -- "$@"
