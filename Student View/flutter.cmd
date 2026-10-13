@echo off
setlocal
set "PROJECT_ROOT=%~dp0"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
for %%I in ("%PROJECT_ROOT%\..") do set "WORKSPACE_ROOT=%%~fI"
set "GRADLE_USER_HOME=%PROJECT_ROOT%\.tools\gradle"
set "PUB_CACHE=%PROJECT_ROOT%\.tools\pub-cache"
if exist "%WORKSPACE_ROOT%\.tools\pub-cache\hosted" set "PUB_CACHE=%WORKSPACE_ROOT%\.tools\pub-cache"
set "TEMP=%PROJECT_ROOT%\.tools\temp"
set "TMP=%TEMP%"
set "GIT_CONFIG_COUNT=1"
set "GIT_CONFIG_KEY_0=safe.directory"
set "GIT_CONFIG_VALUE_0=%PROJECT_ROOT%\.tools\flutter"
set "FLUTTER_EXECUTABLE=%PROJECT_ROOT%\.tools\flutter\bin\flutter.bat"
set "FLUTTER_NATIVE_ASSETS=true"
set "FLUTTER_DART_DATA_ASSETS=true"

if not exist "%FLUTTER_EXECUTABLE%" (
  echo Flutter SDK is missing from %PROJECT_ROOT%\.tools\flutter.
  exit /b 1
)
if not exist "%PROJECT_ROOT%\.tools\flutter\packages\flutter_tools" (
  echo Flutter SDK is incomplete: packages\flutter_tools is missing.
  exit /b 1
)

set "FIX_NATIVE_ASSETS=%PROJECT_ROOT%\tools\fix_flutter_native_assets.ps1"
if exist "%FIX_NATIVE_ASSETS%" (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%FIX_NATIVE_ASSETS%" -PubCache "%PUB_CACHE%"
  if errorlevel 1 exit /b 1
)

pushd "%PROJECT_ROOT%"
call "%FLUTTER_EXECUTABLE%" %*
set "FLUTTER_EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %FLUTTER_EXIT_CODE%
