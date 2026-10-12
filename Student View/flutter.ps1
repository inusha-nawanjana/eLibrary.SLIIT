# Run the workspace Flutter SDK with all project caches on this drive.
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$env:GRADLE_USER_HOME = Join-Path $projectRoot '.tools/gradle'
$env:PUB_CACHE = Join-Path $projectRoot '.tools/pub-cache'
$env:TEMP = Join-Path $projectRoot '.tools/temp'
$env:TMP = $env:TEMP
# The bundled Flutter SDK is a separate Git checkout. It may have been
# extracted by another Windows account, so tell Git this exact SDK path is
# trusted before Flutter runs its engine-version checks.
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = (Join-Path $projectRoot '.tools/flutter')
New-Item -ItemType Directory -Path $env:GRADLE_USER_HOME,$env:PUB_CACHE,$env:TEMP -Force | Out-Null
$flutterExecutable = Join-Path $projectRoot '.tools/flutter/bin/flutter.bat'
if (!(Test-Path -LiteralPath $flutterExecutable)) {
    throw 'Flutter SDK is missing. Follow the SDK installation instructions in README.md.'
}
Push-Location $projectRoot
try {
    & $flutterExecutable @args
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $flutterExitCode
