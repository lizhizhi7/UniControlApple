#!/bin/bash
# UniControl Test Runner
# Quick script to build and run tests

set -e

echo "======================================"
echo "UniControl Test Runner"
echo "======================================"
echo ""

# Build UniControl
echo "📦 Building UniControl..."
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)" | tail -5
echo ""

# Find executable
EXECUTABLE=$(find ~/Library/Developer/Xcode/DerivedData/UniControl-*/Build/Products/Debug/UniControl -type f 2>/dev/null | head -1)

if [ -z "$EXECUTABLE" ]; then
    echo "❌ Error: Could not find UniControl executable"
    echo "   Try building manually with:"
    echo "   xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build"
    exit 1
fi

echo "✅ Build successful!"
echo "📍 Executable: $EXECUTABLE"
echo ""

# Check for test argument
if [ $# -eq 0 ]; then
    echo "Available test scripts:"
    echo "  1. test-calculator.unictl  - Test with Calculator app (simple)"
    echo "  2. test-textedit.unictl    - Test with TextEdit app (simple)"
    echo "  3. example.unictl          - Test with Excel (complex)"
    echo ""
    echo "Usage: $0 [test-file.unictl]"
    echo "   or: $0 calculator  (shortcut for test-calculator.unictl)"
    echo "   or: $0 textedit    (shortcut for test-textedit.unictl)"
    echo ""
    echo "Running built-in example (exampleDSLComplex)..."
    echo ""
    "$EXECUTABLE"
else
    TEST_FILE="$1"

    # Handle shortcuts
    case "$TEST_FILE" in
        calculator)
            TEST_FILE="test-calculator.unictl"
            ;;
        textedit)
            TEST_FILE="test-textedit.unictl"
            ;;
        excel)
            TEST_FILE="example.unictl"
            ;;
    esac

    if [ ! -f "$TEST_FILE" ]; then
        echo "❌ Error: Test file not found: $TEST_FILE"
        exit 1
    fi

    echo "🚀 Running test: $TEST_FILE"
    echo "======================================"
    echo ""

    # Note: This requires main.swift to use exampleDSLFromFile()
    echo "⚠️  Make sure main.swift is set to run exampleDSLFromFile()"
    echo "   Then rebuild with: xcodebuild -project UniControl.xcodeproj -scheme UniControl build"
    echo ""
    "$EXECUTABLE" "$TEST_FILE"
fi
