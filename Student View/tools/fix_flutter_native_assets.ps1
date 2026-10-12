param(
    [Parameter(Mandatory = $true)]
    [string]$PubCache
)

# Flutter's bundled hooks_runner 1.5.x routes native asset commands through
# cmd.exe on Windows when a working directory is supplied. cmd.exe splits
# paths such as `Student View`, so invoke the executable directly instead.
$ErrorActionPreference = 'Stop'
$hostedRoot = Join-Path $PubCache 'hosted/pub.dev'
$runnerFiles = Get-ChildItem -LiteralPath $hostedRoot -Directory -Filter 'hooks_runner-*' -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'lib/src/utils/run_process.dart' } |
    Where-Object { Test-Path -LiteralPath $_ }

$old = @'
      runInShell:
          Platform.isWindows &&
          (!includeParentEnvironment || workingDirectory != null),
'@
$new = @'
      // Avoid cmd.exe: it splits Windows paths containing spaces.
      runInShell: false,
'@

$runnerChanged = $false
foreach ($file in $runnerFiles) {
    $content = [System.IO.File]::ReadAllText($file)
    if ($content.Contains($old)) {
        $content = $content.Replace($old, $new)
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
        $runnerChanged = $true
    }
}

# The Flutter command normally executes flutter_tools.snapshot. Rebuild it
# when the runner source was just patched, otherwise the old shell behavior
# would remain embedded in the snapshot.
if ($runnerChanged) {
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $snapshot = Join-Path $projectRoot '.tools/flutter/bin/cache/flutter_tools.snapshot'
    if (Test-Path -LiteralPath $snapshot) {
        Remove-Item -LiteralPath $snapshot -Force
    }
}
