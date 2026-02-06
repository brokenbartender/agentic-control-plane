# Command Protocol

All commands and acks are JSONL. The desktop watcher must process in order and update state.

## Command
```
{"id":"<uuid>","target":"desktop","created":"<iso8601>","type":"instruction","text":"<plain English instruction>","cwd":"<optional>","timeoutSec":0,"requiresApproval":true}
```

## Ack
```
{"id":"<uuid>","target":"desktop","created":"<iso8601>","status":"ok|error","summary":"<short summary>","details":"<longer details>","exitCode":0}
```

## Locking
Desktop should create `queue/lock.json` while running a command.