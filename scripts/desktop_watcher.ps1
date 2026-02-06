# Desktop Watcher (5-minute poll)
# Runs on desktop to pull commands, execute, and push acks.

param(
  [string]$RepoPath = "C:\Users\codym\agentic-control-plane",
  [int]$PollSeconds = 300
)

$queueDir = Join-Path $RepoPath "queue"
$cmdFile = Join-Path $queueDir "commands.jsonl"
$ackFile = Join-Path $queueDir "acks.jsonl"
$stateFile = Join-Path $queueDir "state.json"

if (!(Test-Path $queueDir)) { New-Item -ItemType Directory -Path $queueDir | Out-Null }
if (!(Test-Path $cmdFile)) { New-Item -ItemType File -Path $cmdFile | Out-Null }
if (!(Test-Path $ackFile)) { New-Item -ItemType File -Path $ackFile | Out-Null }
if (!(Test-Path $stateFile)) { '{"lastId":""}' | Set-Content $stateFile -NoNewline }

function Get-LastId {
  try { (Get-Content $stateFile -Raw | ConvertFrom-Json).lastId } catch { "" }
}

function Set-LastId([string]$id) {
  @{ lastId = $id } | ConvertTo-Json -Compress | Set-Content $stateFile -NoNewline
}

function Add-Ack($id, $status, $summary, $details) {
  $ack = [ordered]@{ id=$id; target='desktop'; created=(Get-Date).ToString('o'); status=$status; summary=$summary; details=$details }
  ($ack | ConvertTo-Json -Compress) | Add-Content $ackFile
}

function Pull-Repo {
  git -C $RepoPath pull | Out-Null
}

function Push-Repo {
  git -C $RepoPath add queue | Out-Null
  git -C $RepoPath commit -m "watcher: ack" | Out-Null
  git -C $RepoPath push | Out-Null
}

Write-Host "Desktop watcher started. Polling every $PollSeconds seconds." 

while ($true) {
  try {
    Pull-Repo
    $lastId = Get-LastId
    $lines = Get-Content $cmdFile | Where-Object { $_ -and $_.Trim().Length -gt 2 }
    foreach ($line in $lines) {
      $cmd = $null
      try { $cmd = $line | ConvertFrom-Json } catch { continue }
      if ($cmd.id -eq $lastId) { continue }
      if ($cmd.target -ne 'desktop') { continue }

      # Manual approval gate (before planning)
      Write-Host "\nNew command: $($cmd.text)"
      $approve = Read-Host "Approve planning? (yes/no)"
      if ($approve -ne 'yes') {
        Add-Ack $cmd.id 'error' 'Planning not approved' 'User denied planning.'
        Set-LastId $cmd.id
        Push-Repo
        continue
      }

      # Placeholder for Codex CLI execution
      # TODO: replace with actual Codex CLI invocation once command is confirmed
      # Example: codex chat --prompt $cmd.text
      Add-Ack $cmd.id 'ok' 'Command received' 'Execution not wired: Codex CLI command not configured.'
      Set-LastId $cmd.id
      Push-Repo
    }
  } catch {
    Write-Host "Watcher error: $($_.Exception.Message)"
  }
  Start-Sleep -Seconds $PollSeconds
}