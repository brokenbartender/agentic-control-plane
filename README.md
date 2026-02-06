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

## Safety & Control
- Manual approval required before planning and before any destructive action.
- All actions logged in acks.
- No self-modification unless explicitly instructed.