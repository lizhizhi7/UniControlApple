# Accessibility Permissions Guide for UniControl

## The Problem

UniControl requires Accessibility permissions to control other macOS applications. However, Debug builds with adhoc signing don't appear in System Settings → Privacy & Security → Accessibility.

## Solution 1: Grant Permission to Terminal (⭐ RECOMMENDED)

**Easiest and fastest solution** - Grant Accessibility permission to your terminal app instead of UniControl itself. UniControl inherits the permission from its parent process.

### Steps:

1. **Open System Settings**
   - Click Apple menu → System Settings
   - Navigate to: **Privacy & Security → Accessibility**

2. **Find Your Terminal App**
   Look for one of these in the list:
   - **Terminal** (macOS built-in)
   - **iTerm**
   - **Warp**
   - **Alacritty**
   - **Hyper**
   - Or whichever terminal you're using

3. **Enable Permission**
   - If already in the list: Toggle the switch **ON**
   - If not in the list:
     - Click the **[+]** button at the bottom
     - Navigate to `/Applications`
     - Select your terminal app
     - Click **Open**
     - Toggle the switch **ON**

4. **Restart Terminal**
   - Completely quit your terminal app (Cmd+Q)
   - Reopen it
   - Navigate back to the UniControl directory

5. **Run UniControl**
   ```bash
   ./build/Debug/UniControl examples/test-basic-actions.unictl
   ```

### Verification:
Run the permission check:
```bash
./build/Debug/UniControl
```

If you see accessibility permission prompts or the script runs successfully, you're good to go!

---

## Solution 2: Self-Sign with Your Apple Developer Certificate

If you have an Apple Developer account, you can properly sign the executable.

### Steps:

1. **Find Your Signing Identity**
   ```bash
   security find-identity -v -p codesigning
   ```

2. **Sign the Executable**
   ```bash
   codesign --force --sign "YOUR_IDENTITY_HERE" build/Debug/UniControl
   ```

3. **Run UniControl**
   ```bash
   ./build/Debug/UniControl examples/test-basic-actions.unictl
   ```

   It should now prompt for Accessibility permission and appear in System Settings.

---

## Solution 3: Create a Signed App Bundle

Create a proper macOS application bundle that can be added to Accessibility.

### Steps:

1. **Run the Bundle Creation Script**
   ```bash
   ./scripts/create-app-bundle.sh
   ```

   This creates `UniControl.app` in the project root.

2. **Add to Accessibility**
   - Open System Settings → Privacy & Security → Accessibility
   - Click **[+]**
   - Navigate to your UniControl project directory
   - Select **UniControl.app**
   - Click **Open**
   - Toggle **ON**

3. **Run from App Bundle**
   ```bash
   ./UniControl.app/Contents/MacOS/UniControl examples/test-basic-actions.unictl
   ```

---

## Troubleshooting

### "Operation not permitted" Error
This means Accessibility permission is not granted. Follow Solution 1 above.

### Terminal Not Showing in Accessibility List
1. Try running UniControl once: `./build/Debug/UniControl`
2. macOS should prompt you to add Terminal to Accessibility
3. Click "Open System Settings"
4. Grant permission manually

### Permission Granted But Still Doesn't Work
1. **Restart Terminal completely** (Cmd+Q, then reopen)
2. Check that the correct terminal app is enabled
3. Try running with `sudo` (not recommended for production, but useful for testing):
   ```bash
   sudo ./build/Debug/UniControl examples/test-basic-actions.unictl
   ```

### "Accessibility permission required" Message Persists
The check is done via Swift code. If Terminal has permission, the code should work even if it shows this message initially. Try running a test script:
```bash
./build/Debug/UniControl examples/test-basic-actions.unictl
```

---

## Which Solution Should I Use?

| Solution | Pros | Cons | Best For |
|----------|------|------|----------|
| **1. Terminal Permission** | ✅ Easiest<br>✅ No code changes<br>✅ Works immediately | ⚠️ Grants broad permission to Terminal | Daily development |
| **2. Self-Signing** | ✅ Proper app identity<br>✅ Can be added to Accessibility | ❌ Requires Apple Developer cert<br>❌ Need to re-sign after rebuild | Testing distribution |
| **3. App Bundle** | ✅ Native macOS app<br>✅ Can be distributed | ❌ More complex setup<br>❌ Need to rebuild bundle | Production distribution |

**Recommendation**: Use **Solution 1 (Terminal Permission)** for development and testing.

---

## Testing After Granting Permission

Once permission is granted, test with the basic actions script:

```bash
# Build the project
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build

# Run a test script
./build/Debug/UniControl examples/test-basic-actions.unictl
```

Expected behavior:
- Calculator should launch
- Numbers should be clicked
- Operations should execute
- No "permission required" errors

---

## Security Note

Granting Accessibility permission allows an app to control your computer's UI. Only grant permission to:
- Applications you trust
- Your own development tools (Terminal)
- Official Apple applications

The Terminal permission approach is safe for development because you control what runs in your terminal.
