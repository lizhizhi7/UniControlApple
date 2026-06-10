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

## Deferred (revisit when the need is demonstrated)

| Feature | What it is | Why deferred |
|---------|-----------|--------------|
| **JSON CLI output** (`--json`) | Structured per-command JSON on stdout | Serves agents that shell out to the CLI (e.g. Claude Code); the chosen mode is MCP, which already returns structured data |
| **DSL variables** (`set x = ...`, interpolation) | Carry values between commands inside one script | An MCP model carries values between tool calls itself; only helps batch `execute_script` round-trip economy |
| **Conditionals / loops** | `if exists ... / repeat N` | Same — the model is the control flow. Mainly valuable for *unattended* saved scripts; high parser complexity |
| **Post-action state diff** | Auto-report what changed in the UI tree after each action | High value but costly to do well; cheap 80% alternative: return the element's post-action state in action responses |
| **Multi-window named contexts** | `usewindow A as src` / target by name | Cross-app flows work today by re-attaching; add when chatty re-attachment proves painful |
| **Operation recording** | Record human interactions → script | Human-workflow feature; indirect AI value only (few-shot examples) |

## Permissions required at runtime

- **Accessibility** — all element finding/interaction. Grant once to the MCP host (Claude Desktop) or terminal; see [ACCESSIBILITY_PERMISSIONS.md](ACCESSIBILITY_PERMISSIONS.md).
- **Screen Recording** — `screenshot` only. Granted the same way (to the responsible host process).

Unit tests (`swift test`) require neither.
