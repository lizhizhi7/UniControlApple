# AI Integration Plan

UniControl's primary use case is **AI-driven control via MCP** (Claude Desktop and other MCP clients). This document records the prioritization rationale, what has been implemented, and what is deliberately deferred.

## Guiding principle

An AI in the loop supplies its own logic — it can branch, retry, and chain steps across tool calls. What it cannot supply is **perception** (what does the screen actually show?) and **trustworthy feedback** (did my action hit the right thing?). So perception and feedback features rank above DSL language features.

## Implemented (June 2026)

| Feature | Why it matters for AI control |
|---------|-------------------------------|
| **Parse diagnostics** — line-numbered errors + "did you mean", scripts rejected before execution | AI-generated scripts with typos used to silently skip steps; now the error round-trips to the model so it can self-correct |
| **`wait_for`** (poll until element appears) | Replaces blind `wait N`; deterministic, faster, and failure carries a clear timeout message |
| **`assert`** (exists/missing/enabled/disabled/value) | Lets the model verify an action worked before building on it |
| **`use_window`** (attach to open window) | The dominant MCP scenario is "control the app I already have open", not "launch fresh" |
| **`dump_tree`** | Proactive element discovery; AX titles often differ from visible labels (Calculator's "+" is titled "Add") |
| **`screenshot`** (returns MCP image content + coordinate mapping) | The universal fallback when the AX tree can't describe the UI (Electron, canvas, custom rendering); the model literally sees the window |
| **`click_at`** (absolute screen coordinates) | Completes the screenshot→look→click loop, same as the model's native computer-use pattern |
| **Find ranking + match transparency** | Exact > prefix > contains, title > description > value; multi-matches are reported with alternatives instead of silently clicking the first hit — the worst failure mode was a *successful* wrong click |
| **Action retries** | 3×150ms retry on transient AX failures; fewer spurious errors for the model to waste turns diagnosing |

## Recommended AI workflow

```
use_window (or launch_app)
dump_tree                      → discover what exists
wait_for + click / set_value   → act deterministically
assert / get_element           → verify each step
screenshot + click_at          → fallback when AX can't see it
```

For multi-step batches, `execute_script` supports variables (`set` / `getvalue` / `$name`), `if/else/end`, `repeat n/end`, and `usewindow ... as alias` + `usewindow @alias` — one tool call can carry a value from one window to another and branch on UI state.

## Second wave (June 2026) — formerly deferred, now implemented

| Feature | What landed |
|---------|-------------|
| **Post-action element state** | Element actions return the element's refreshed `ElementInfo`; MCP responses append it, so the model verifies effects without a follow-up `get_element` |
| **JSON CLI output** | `UniControl --json <script>` emits a machine-readable result document as the last line of stdout — for agents that shell out instead of using MCP |
| **DSL variables** | `set name = value`, `getvalue name` (captures the current element's value), `$name`/`${name}` interpolation in command arguments. MCP: `set_variable` / `get_value` |
| **Named window contexts** | `usewindow <title> as <alias>` saves a window, `usewindow @alias` switches back; MCP `use_window` gains `save_as`. Enables read-here-paste-there flows across windows |
| **Conditionals / loops** | `if <condition> ... [else ...] end` (assert-syntax conditions) and `repeat <n> ... end`, nestable, with balanced-block parse diagnostics. Mainly for unattended `execute_script` batches |
| **Operation recording** | `UniControl --record [path]` captures clicks (hit-tested to AX elements → `find`+`click`) and keystrokes (`type`/`presskey`) into a replayable script — useful as few-shot examples for the model and for humans bootstrapping scripts |

## Still open (future)

| Feature | Notes |
|---------|-------|
| **Full UI state diff** | Auto-diffing the whole tree after each action remains costly; the cheap version (post-action element state, above) covers most verification needs. Revisit if models still issue many `dump_tree` calls just to detect changes |
| **Recording polish** | Drag gestures, scroll capture, coalescing repeated clicks, and smarter selector generation (disambiguating duplicate titles) |

## Permissions required at runtime

- **Accessibility** — all element finding/interaction. Grant once to the MCP host (Claude Desktop) or terminal; see [ACCESSIBILITY_PERMISSIONS.md](ACCESSIBILITY_PERMISSIONS.md).
- **Screen Recording** — `screenshot` only. Granted the same way (to the responsible host process).

Unit tests (`swift test`) require neither.
