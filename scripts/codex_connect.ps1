param(
  [Parameter(Mandatory=$true, Position=0)]
  [string]$Prompt,
  [string]$CodexExecPath = "codex"
)

# Wrapper for non-interactive Codex CLI usage.
# Streams progress to stderr and outputs final response to stdout.
& $CodexExecPath exec $Prompt
