# Accessibility Permissions Guide for UniControl

UniControl controls other applications through the macOS Accessibility (AX) APIs, which require the **Accessibility** permission (System Settings → Privacy & Security → Accessibility).

The `screenshot` command additionally requires **Screen Recording** permission (System Settings → Privacy & Security → Screen Recording). It follows the same responsible-process rules described below — grant it once to your terminal or MCP host.

## Why macOS keeps asking (and how to make it stop)

macOS ties an Accessibility grant to the **responsible process** and its **code signing identity**:

- When you run the CLI from a terminal, the *terminal app* is the responsible process. Grant Accessibility to **Terminal/iTerm/etc. once** and every binary you run from it — including freshly rebuilt ones — inherits the permission. **Rebuilds never trigger a new prompt.**
- When an MCP client (Claude Desktop, Claude Code, etc.) spawns `UniControl --mcp`, the *host app* is the responsible process. Grant Accessibility to **that host app once**.
- When you run the **GUI app** from Xcode, debug builds are ad-hoc signed: the signature changes on every build, so macOS sees a "new" app each time and re-asks (or the toggle silently stops working). Signing with a **stable identity** fixes this.

So if you are being prompted repeatedly, you are almost certainly running an ad-hoc-signed app bundle directly. Use one of the solutions below.

## Solution 1: Grant permission to your terminal (recommended for CLI development)

1. Open **System Settings → Privacy & Security → Accessibility**
2. Add your terminal app (Terminal, iTerm, Warp, …) with **[+]** if it isn't listed, and toggle it **ON**
3. Fully restart the terminal (Cmd+Q, reopen)
4. Run the CLI:
   ```bash
   swift build
   .build/debug/UniControl examples/test-calculator.unictl
   ```

This is a one-time grant. Rebuilding with `swift build` does not invalidate it.

> Unit tests (`swift test`) never touch the AX APIs, so they need no permission at all.

## Solution 2: Grant permission to the MCP host (for Claude Desktop / MCP use)

If UniControl runs as an MCP server, grant Accessibility to the application that launches it (e.g. **Claude Desktop**, or the terminal hosting Claude Code). One grant covers every `UniControl --mcp` invocation that host spawns.

## Solution 3: Sign the GUI app with a stable identity (stops Xcode-build re-prompts)

The re-prompt loop with UniControlApp happens because each ad-hoc signed build has a new identity. Either:

- **With an Apple Developer certificate**: in Xcode, set a Development Team for the UniControlApp target (Signing & Capabilities). Builds then share a stable identity and the grant persists across rebuilds.
- **Self-signed certificate** (no Apple account needed):
  1. Keychain Access → Certificate Assistant → Create a Certificate… → name e.g. `UniControl Dev`, type **Code Signing**
  2. Sign after building:
     ```bash
     codesign --force --deep --sign "UniControl Dev" /path/to/UniControlApp.app
     ```
  3. Grant Accessibility once; subsequent builds signed with the same certificate keep the grant.

If old, stale entries accumulate in the Accessibility list, clean them up with:

```bash
sudo tccutil reset Accessibility com.yourteam.UniControlApp   # or omit the bundle id to reset all
```

## Troubleshooting

- **"Operation not permitted" / silent failures** — permission not granted to the responsible process. Re-check which app actually launched UniControl.
- **Granted but still failing** — restart the responsible app completely (TCC checks at process start). For terminals: Cmd+Q, reopen.
- **App listed but toggle has no effect** — the entry is stale (signature changed since the grant). Remove it with **[−]**, run `tccutil reset Accessibility`, and re-grant.

## Security note

Accessibility permission lets a process control your UI. Grant it only to apps you trust. The terminal-grant approach is safe for development because you control what runs in your terminal.
