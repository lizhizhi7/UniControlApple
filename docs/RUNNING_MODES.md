# UniControl Running Modes

UniControl supports three running modes for different use cases: direct script execution, interactive REPL, and HTTP/WebSocket server mode.

## Command Line Options

```bash
UniControl [options] <script-file>
UniControl --interactive, -i
UniControl --serve [port]

Options:
  --debug, -d       Enable debug/verbose output
  --quiet, -q       Disable verbose output (default)
  --interactive, -i Start interactive REPL mode
  --serve [port]    Start HTTP/WebSocket server (default port: 8080)
  --help, -h        Show help message
  --version, -v     Show version information
```

## Mode 1: Direct Script Execution

Run a `.unictl` script file directly from the command line.

### Usage

```bash
# Run a script with default quiet output
./UniControl path/to/script.unictl

# Run with debug mode (verbose output)
./UniControl --debug script.unictl

# Run quietly (explicit, same as default)
./UniControl --quiet script.unictl
```

### Output

With quiet mode (default), you'll only see:
- Explicit `log` commands from your script
- Critical errors
- Final success/failure status

With debug mode enabled, you'll see:
- Command execution progress: `[1/10]`, `[2/10]`, etc.
- Success/failure indicators
- Vision fallback activation messages
- Element suggestions when searches fail
- Error summaries at the end

### Exit Behavior

The process exits after script completion:
- Exit code `0`: All commands succeeded
- Exit code `1`: One or more commands failed

## Mode 2: Interactive REPL

Start an interactive Read-Eval-Print Loop for entering commands one at a time.

### Usage

```bash
# Start interactive mode
./UniControl --interactive

# Or shorthand
./UniControl -i
```

### Features

- **Persistent Context**: Window and element selections persist across commands
- **Prompt Indicators**: Shows current window and element state
- **Built-in Commands**: Special REPL commands for status and control

### REPL Commands

| Command | Description |
|---------|-------------|
| `help` | Show available commands |
| `status` | Show current context (window, element) |
| `clear` | Reset context (clear window/element selection) |
| `exit`, `quit` | Exit interactive mode |

### Prompt Format

The prompt shows current state:
```
unictl>                    # No window selected
unictl [Calculator]>       # Window "Calculator" selected
unictl [Calculator] *>     # Window selected + element selected
```

### Example Session

```
$ ./UniControl -i
UniControl Interactive Mode
Type 'help' for commands, 'exit' to quit.

unictl> launch Calculator
[1/1] Executing: launch(appName: "Calculator")
✓ Success

unictl [Calculator]> find 7
[1/1] Executing: find(selector: byTitle("7"))
✓ Success

unictl [Calculator] *> click
[1/1] Executing: perform(action: click)
✓ Success

unictl [Calculator]> status

Current Context:
  Window: "Calculator"
  Element: AXButton "7"

unictl [Calculator]> exit
Goodbye!
```

## Mode 3: HTTP/WebSocket Server

Start a server that accepts commands via HTTP requests or WebSocket connections.

### Usage

```bash
# Start server on default port (8080)
./UniControl --serve

# Start server on custom port
./UniControl --serve 3000
```

### Server Output

```
UniControl server starting on http://127.0.0.1:8080
Endpoints:
  GET  /health  - Health check
  POST /execute - Execute DSL script
  WS   /ws      - WebSocket for streaming

Press Ctrl+C to stop the server
```

### HTTP Endpoints

#### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "version": "1.0.0"
}
```

#### POST /execute

Execute a DSL script. Each request creates a new execution context (stateless).

**Request:**
```json
{
  "script": "launch Calculator\nwait 1\nfind 7\nclick",
  "mode": "continue"
}
```

**Parameters:**
- `script` (required): DSL script content (commands separated by newlines)
- `mode` (optional): Execution mode - `"strict"`, `"continue"` (default), or `"interactive"`

**Response:**
```json
{
  "success": true,
  "commandsExecuted": 4,
  "commandsFailed": 0,
  "results": [
    {"index": 0, "command": "launch(appName: \"Calculator\")", "status": "success"},
    {"index": 1, "command": "perform(action: wait(1.0))", "status": "success"},
    {"index": 2, "command": "find(selector: byTitle(\"7\"))", "status": "success"},
    {"index": 3, "command": "perform(action: click)", "status": "success"}
  ],
  "executionTime": 2.45
}
```

**Example with curl:**
```bash
curl -X POST http://localhost:8080/execute \
  -H "Content-Type: application/json" \
  -d '{"script": "launch Calculator\nwait 1\nfind 7\nclick"}'
```

### WebSocket Endpoint

#### WS /ws

WebSocket connection for real-time streaming and persistent sessions.

**Key Features:**
- **Persistent Context**: Execution context is maintained across commands within the same connection
- **Real-time Logs**: Log messages are streamed as they occur
- **Command Results**: Individual command results are streamed immediately

**Client → Server Messages:**

Execute command:
```json
{
  "type": "execute",
  "script": "launch Calculator",
  "mode": "continue"
}
```

Reset session context:
```json
{
  "type": "reset"
}
```

**Server → Client Messages:**

Log message:
```json
{
  "type": "log",
  "level": "info",
  "message": "[1/1] Executing: launch(appName: \"Calculator\")",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

Command result:
```json
{
  "type": "result",
  "index": 0,
  "command": "launch(appName: \"Calculator\")",
  "status": "success"
}
```

Execution complete:
```json
{
  "type": "complete",
  "success": true,
  "commandsExecuted": 1,
  "commandsFailed": 0,
  "executionTime": 2.1
}
```

**Example WebSocket Client (JavaScript):**
```javascript
const ws = new WebSocket('ws://localhost:8080/ws');

ws.onopen = () => {
  // Commands share context within this connection
  ws.send(JSON.stringify({type: "execute", script: "launch Calculator"}));
};

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);

  if (msg.type === "log") {
    console.log(`[${msg.level}] ${msg.message}`);
  } else if (msg.type === "complete") {
    // First command done, send next (context preserved)
    ws.send(JSON.stringify({type: "execute", script: "find 7\nclick"}));
  }
};
```

## Comparison of Modes

| Feature | Script | Interactive | Server HTTP | Server WebSocket |
|---------|--------|-------------|-------------|------------------|
| Context persistence | Single run | Across commands | Per request | Per connection |
| Real-time output | Yes | Yes | Response only | Streaming |
| User input | No | Yes | No | Via messages |
| Use case | Automation | Debugging | API integration | Real-time control |
| Exit behavior | After script | On quit | Runs until stopped | Connection-based |

## Accessibility Permissions

All modes require macOS Accessibility permissions to control applications.

**To grant permissions:**
1. Go to **System Settings** → **Privacy & Security** → **Accessibility**
2. Add and enable the terminal app running UniControl

**Server Mode Note:** The server will start even without permissions (for health checks), but script execution will fail until permissions are granted.

## See Also

- [DSL Reference](DSL_REFERENCE.md) - Complete command reference
- [Extension System](EXTENSION_SYSTEM.md) - Creating custom extensions
