#!/bin/bash
# UniControl Test Runner
#
# Usage:
#   ./run-tests.sh                 # run unit tests (no Accessibility permission needed)
#   ./run-tests.sh <script.unictl> # build CLI and run a .unictl script (needs Accessibility)
#   ./run-tests.sh calculator      # shortcut for examples/test-calculator.unictl
#   ./run-tests.sh textedit        # shortcut for examples/test-textedit.unictl
#   ./run-tests.sh excel           # shortcut for examples/example.unictl

set -e

if [ $# -eq 0 ]; then
    echo "Running unit tests (swift test)..."
    swift test
    exit 0
fi

TEST_FILE="$1"
case "$TEST_FILE" in
    calculator) TEST_FILE="examples/test-calculator.unictl" ;;
    textedit)   TEST_FILE="examples/test-textedit.unictl" ;;
    excel)      TEST_FILE="examples/example.unictl" ;;
esac

if [ ! -f "$TEST_FILE" ]; then
    echo "Error: script not found: $TEST_FILE"
    exit 1
fi

echo "Building UniControl CLI..."
swift build

BIN="$(swift build --show-bin-path)/UniControl"
echo "Running: $TEST_FILE"
echo "(requires Accessibility permission; see docs/ACCESSIBILITY_PERMISSIONS.md)"
"$BIN" "$TEST_FILE"
