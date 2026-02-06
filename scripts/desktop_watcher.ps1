# Desktop Watcher (5-minute poll)
# Runs on desktop to pull commands, execute, and push acks.

param(
  [string]$RepoPath = "C:\Users\codym\agentic-control-plane",
  [int]$PollSeconds = 300,
  [string]$A2AHost = "127.0.0.1",
  [int]$A2APort = 9451,
  [string]$A2ASharedSecret = "",
  [string]$A2ASender = "control-plane",
  [string]$A2AReceiver = "local",
  [switch]$AutoRespond = $false,
  [string]$CodexExecPath = "codex",
  [switch]$SkipApproval = $false
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

function Send-A2ANotification([string]$message) {
  try {
    $payload = @{
      sender = $A2ASender
      receiver = $A2AReceiver
      message = $message
      shared_secret = $A2ASharedSecret
    } | ConvertTo-Json -Compress
    $uri = "http://$A2AHost`:$A2APort/a2a"
    Invoke-RestMethod -Method Post -Uri $uri -Body $payload -ContentType "application/json" | Out-Null
  } catch {
    Write-Host "A2A notify failed: $($_.Exception.Message)"
  }
}

function Invoke-CodexExec([string]$prompt) {
  $output = ""
  try {
    $output = & $CodexExecPath exec $prompt 2>&1 | Out-String
    $exit = $LASTEXITCODE
    return @{
      ok = ($exit -eq 0)
      output = $output.Trim()
      exit = $exit
    }
  } catch {
    return @{
      ok = $false
      output = $_.Exception.Message
      exit = 1
    }
  }
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
      Send-A2ANotification("New control-plane command: $($cmd.text)")
      if (-not $SkipApproval -and -not $AutoRespond) {
        $approve = Read-Host "Approve planning? (yes/no)"
        if ($approve -ne 'yes') {
          Add-Ack $cmd.id 'error' 'Planning not approved' 'User denied planning.'
          Set-LastId $cmd.id
          Push-Repo
          continue
        }
      }

      if ($AutoRespond) {
        $result = Invoke-CodexExec $cmd.text
        if ($result.ok) {
          Add-Ack $cmd.id 'ok' 'Codex response generated' $result.output
        } else {
          Add-Ack $cmd.id 'error' 'Codex exec failed' ("exit=" + $result.exit + "`n" + $result.output)
        }
      } else {
        Add-Ack $cmd.id 'ok' 'Command received' 'Execution not wired: Codex exec not enabled.'
      }
      Set-LastId $cmd.id
      Push-Repo
    }
  } catch {
    Write-Host "Watcher error: $($_.Exception.Message)"
  }
  Start-Sleep -Seconds $PollSeconds
}
