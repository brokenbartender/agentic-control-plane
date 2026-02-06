# Local Watcher (work node)
# Polls origin for new acks every 60s.

param(
  [string]$RepoPath = "C:\Users\codym\agentic-control-plane",
  [int]$PollSeconds = 60
)

$ackFile = Join-Path $RepoPath "queue\acks.jsonl"
$stateFile = Join-Path $RepoPath "queue\ack_state.json"
if (!(Test-Path $stateFile)) { '{"lastAckId":""}' | Set-Content $stateFile -NoNewline }

function Get-LastAck { try { (Get-Content $stateFile -Raw | ConvertFrom-Json).lastAckId } catch { "" } }
function Set-LastAck([string]$id) { @{ lastAckId = $id } | ConvertTo-Json -Compress | Set-Content $stateFile -NoNewline }

Write-Host "Ack watcher started. Polling every $PollSeconds seconds."

while ($true) {
  try {
    git -C $RepoPath fetch --all | Out-Null
    git -C $RepoPath reset --hard origin/master | Out-Null
    $last = Get-LastAck
    $lines = Get-Content $ackFile | Where-Object { $_ -and $_.Trim().Length -gt 2 }
    foreach ($line in $lines) {
      $ack = $null
      try { $ack = $line | ConvertFrom-Json } catch { continue }
      if ($ack.id -eq $last) { continue }
      Write-Host "\nACK [$($ack.status)] $($ack.summary)"
      if ($ack.details) { Write-Host $ack.details }
      Set-LastAck $ack.id
    }
  } catch {
    Write-Host "Watcher error: $($_.Exception.Message)"
  }
  Start-Sleep -Seconds $PollSeconds
}