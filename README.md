# Agentic Control Plane

Purpose: establish a cross-computer control plane that lets you issue tasks via repo commits, and have the desktop (primary coordinator) execute them and report back. This creates a low-touch, always-on, conversational loop.

## Communication Standard
- Commands are appended to `queue/commands.jsonl` as JSON lines.
- Desktop appends results to `queue/acks.jsonl`.
- Desktop pulls every 5 minutes (or sooner if instructed), executes new commands, and pushes acks.

### Command format (JSONL)
```
{"id":"<uuid>","target":"desktop","created":"<iso8601>","type":"instruction","text":"<plain English instruction>"}
```

### Ack format (JSONL)
```
{"id":"<uuid>","target":"desktop","created":"<iso8601>","status":"ok|error","summary":"<short summary>","details":"<optional details>"}
```

## Desktop Watcher
Run `scripts/desktop_watcher.ps1` on the desktop. It will:
- `git pull`
- read new commands
- execute them (manual approval gate before planning)
- write acks
- `git push`

### CLI Notifications (A2A)
If Agentic Console is running with A2A enabled, the watcher can notify the CLI on new commands.
Defaults:
- Host: `127.0.0.1`
- Port: `9451`
- Shared secret: empty string (set this to match your `.env`)

Example (desktop):
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\codym\agentic-control-plane\scripts\desktop_watcher.ps1 -PollSeconds 60 -A2AHost 127.0.0.1 -A2APort 9451 -A2ASharedSecret change_me
```

### Codex Connect (auto-response)
If you want autonomous responses, enable auto-respond and point to the Codex CLI executable.
This uses non-interactive `codex exec` to generate a response and writes it into `queue/acks.jsonl`.

Example (desktop):
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\codym\agentic-control-plane\scripts\desktop_watcher.ps1 -PollSeconds 10 -AutoRespond -SkipApproval -CodexExecPath codex
```

You can also call the wrapper directly:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\codym\agentic-control-plane\scripts\codex_connect.ps1 "hello from control plane"
```

## Laptop Watcher (same setup)
On the laptop, set up the same watcher so it can receive its own commands:
```powershell
git clone https://github.com/brokenbartender/agentic-control-plane.git C:\Users\<you>\agentic-control-plane
```
Find the Codex CLI path:
```powershell
(Get-Command codex).Source
```

Create `scripts\run_watcher.ps1` on the laptop (update the codex path):
```powershell
param(
  [int]$PollSeconds = 10
)

$watcher = "C:\Users\<you>\agentic-control-plane\scripts\desktop_watcher.ps1"
$codex = "C:\Users\<you>\AppData\Roaming\npm\codex.ps1"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $watcher `
  -PollSeconds $PollSeconds `
  -AutoRespond `
  -SkipApproval `
  -CodexExecPath $codex `
  -A2AHost 127.0.0.1 `
  -A2APort 9451 `
  -A2ASharedSecret change_me
```

Then create a scheduled task (poll every 10s):
```powershell
schtasks /Create /TN "AgenticControlPlaneWatcher" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\<you>\agentic-control-plane\scripts\run_watcher.ps1" /SC ONLOGON /RL HIGHEST /F
schtasks /Run /TN "AgenticControlPlaneWatcher"
```
Make sure commands in `queue/commands.jsonl` use `target:"laptop"` for that machine.

## Safety & Control
- Manual approval required before planning and before any destructive action.
- All actions logged in acks.
- No self-modification unless explicitly instructed.
