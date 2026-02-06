param(
  [int]$PollSeconds = 10
)

$watcher = "C:\Users\codym\agentic-control-plane\scripts\desktop_watcher.ps1"
$codex = "C:\nvm4w\nodejs\codex.ps1"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $watcher `
  -PollSeconds $PollSeconds `
  -AutoRespond `
  -SkipApproval `
  -CodexExecPath $codex `
  -A2AHost 127.0.0.1 `
  -A2APort 9451 `
  -A2ASharedSecret change_me
