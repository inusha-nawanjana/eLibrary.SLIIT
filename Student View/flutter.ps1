# Run the workspace Flutter SDK with all project caches on this drive.
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$workspaceRoot = Split-Path $projectRoot -Parent
$env:GRADLE_USER_HOME = Join-Path $projectRoot '.tools/gradle'
$localPubCache = Join-Path $projectRoot '.tools/pub-cache'
$sharedPubCache = Join-Path $workspaceRoot '.tools/pub-cache'
$env:PUB_CACHE = if (Test-Path -LiteralPath (Join-Path $sharedPubCache 'hosted')) {
    $sharedPubCache
} else {
    $localPubCache
}
$env:TEMP = Join-Path $projectRoot '.tools/temp'
$env:TMP = $env:TEMP
# The bundled Flutter SDK is a separate Git checkout. It may have been
# extracted by another Windows account, so tell Git this exact SDK path is
# trusted before Flutter runs its engine-version checks.
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = (Join-Path $projectRoot '.tools/flutter')
$env:FLUTTER_NATIVE_ASSETS = 'true'
$env:FLUTTER_DART_DATA_ASSETS = 'true'
New-Item -ItemType Directory -Path $env:GRADLE_USER_HOME,$env:PUB_CACHE,$env:TEMP -Force | Out-Null
$fixNativeAssets = Join-Path $projectRoot 'tools/fix_flutter_native_assets.ps1'
if (Test-Path -LiteralPath $fixNativeAssets) {
    & $fixNativeAssets -PubCache $env:PUB_CACHE
}
$flutterExecutable = Join-Path $projectRoot '.tools/flutter/bin/flutter.bat'
if (!(Test-Path -LiteralPath $flutterExecutable)) {
    throw 'Flutter SDK is missing. Follow the SDK installation instructions in README.md.'
}
if (!(Test-Path -LiteralPath (Join-Path $projectRoot '.tools/flutter/packages/flutter_tools'))) {
    throw 'Flutter SDK is incomplete: .tools/flutter/packages/flutter_tools is missing.'
}
Push-Location $projectRoot
try {
    & $flutterExecutable @args
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $flutterExitCode
