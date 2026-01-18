# UniControl - Quick Start Guide

Get up and running with UniControl in 5 minutes!

## Step 1: Build the Project

```bash
cd /Users/oliverli/.claude-worktrees/UniControl/wonderful-lalande
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build
```

✅ You should see `** BUILD SUCCEEDED **`

## Step 2: Grant Accessibility Permissions

UniControl needs permission to control other apps.

**Option A: Let UniControl prompt you**
- Just run it (Step 3), and it will ask for permissions
- Click "Open System Settings" and enable it

**Option B: Grant manually**
1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the **+** button
3. Add Terminal (or the UniControl executable)
4. Enable the checkbox

## Step 3: Run Your First Test

### Test with Calculator (Recommended First Test)

The project is currently set to run a complex example. Let's test with something simpler first:

**Option 1: Use the built-in Calculator test**

1. The executable is already built. Find it and run:
```bash
# Find the executable
UNICONTROL=$(find ~/Library/Developer/Xcode/DerivedData/UniControl-*/Build/Products/Debug/UniControl -type f | head -1)

# Run the built-in example (currently exampleDSLComplex)
"$UNICONTROL"
```

This will try to automate Excel. If you don't have Excel, continue to Option 2.

**Option 2: Test with Calculator (simpler)**

1. Edit `UniControl/main.swift` and change the active example:
```swift
// Change this line:
exampleDSLComplex()

// To this:
exampleDSLFromFile()
```

2. Rebuild:
```bash
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build
```

3. Run with Calculator test script:
```bash
UNICONTROL=$(find ~/Library/Developer/Xcode/DerivedData/UniControl-*/Build/Products/Debug/UniControl -type f | head -1)
"$UNICONTROL" test-calculator.unictl
```

**Expected Result**:
- Calculator launches
- Numbers 5, +, 3, = are clicked automatically
- Result shows 8
- Console shows "Test complete!"

## Step 4: Try TextEdit Test

```bash
UNICONTROL=$(find ~/Library/Developer/Xcode/DerivedData/UniControl-*/Build/Products/Debug/UniControl -type f | head -1)
"$UNICONTROL" test-textedit.unictl
```

**Expected Result**:
- TextEdit launches
- A new blank document is created
- Console shows "Test complete!"

## Step 5: Create Your Own Script

Create `my-test.unictl`:
```bash
cat > my-test.unictl << 'EOF'
# My first automation script
log Hello from UniControl!
launch Calculator
wait 2

log Clicking 9
find 9 role: AXButton
click

log Done!
EOF
```

Run it:
```bash
UNICONTROL=$(find ~/Library/Developer/Xcode/DerivedData/UniControl-*/Build/Products/Debug/UniControl -type f | head -1)
"$UNICONTROL" my-test.unictl
```

## Alternative: Use the Test Runner Script

We've included a helper script to make testing easier:

```bash
# See available options
./run-tests.sh

# Run Calculator test
./run-tests.sh calculator

# Run TextEdit test
./run-tests.sh textedit

# Run custom script
./run-tests.sh my-test.unictl
```

## Available Examples

You can switch between different examples by editing `UniControl/main.swift`:

```swift
// Choose one:
exampleOld()              // Legacy example - finds buttons
exampleControlFlow()      // Excel automation step-by-step
exampleDSLSimple()        // Simple DSL script (inline)
exampleDSLComplex()       // Complex DSL script (programmatic)
exampleDSLFromFile()      // Load script from .unictl file
```

After changing, rebuild:
```bash
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build
```

## Troubleshooting

### "App did not launch"
- Make sure the app name is correct (e.g., "Calculator" not "calculator")
- Try `ls /Applications/*.app` to see available apps

### "Could not find element"
- Increase the wait time: `wait 3` instead of `wait 2`
- The app UI might be different than expected

### "No accessibility permission"
- Go to System Settings → Privacy & Security → Accessibility
- Add Terminal or the UniControl executable
- Enable the checkbox

### Build fails
```bash
# Clean and rebuild
rm -rf ~/Library/Developer/Xcode/DerivedData/UniControl-*
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build
```

## What's Next?

✅ **Built and ran your first test** - Great!
✅ **Automated Calculator** - Nice!
✅ **Created a custom script** - Awesome!

**Now try:**
1. Explore more apps (Safari, Notes, Finder)
2. Chain multiple commands together
3. Create complex workflows
4. Read the [TESTING_GUIDE.md](TESTING_GUIDE.md) for advanced techniques
5. Check out [README.md](README.md) for DSL syntax reference

## Quick Reference

### Common Commands
```bash
launch <app-name>              # Launch an application
wait <seconds>                 # Wait/delay
find <title> role: <role>      # Find UI element
click                          # Click current element
log <message>                  # Print message
```

### Common Roles
- `AXButton` - Buttons
- `AXTextField` - Text input fields
- `AXStaticText` - Text labels
- `AXCheckBox` - Checkboxes

### Example Script Structure
```
# Comments start with #
log Starting my script
launch AppName
wait 2
find ButtonName role: AXButton
click
log Done!
```

## Need Help?

- 📖 Full documentation: [CLAUDE.md](CLAUDE.md)
- 🧪 Testing guide: [TESTING_GUIDE.md](TESTING_GUIDE.md)
- 📘 DSL reference: [README.md](README.md)
- 🔧 Architecture: [REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)

Happy automating! 🚀
