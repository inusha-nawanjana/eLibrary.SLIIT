@echo off
setlocal
set "PROJECT_ROOT=%~dp0"
set "GRADLE_USER_HOME=%PROJECT_ROOT%.tools\gradle"
set "PUB_CACHE=%PROJECT_ROOT%.tools\pub-cache"
set "TEMP=%PROJECT_ROOT%.tools\temp"
set "TMP=%TEMP%"
set "GIT_CONFIG_COUNT=1"
set "GIT_CONFIG_KEY_0=safe.directory"
set "GIT_CONFIG_VALUE_0=%PROJECT_ROOT%.tools\flutter"
set "FLUTTER_EXECUTABLE=%PROJECT_ROOT%.tools\flutter\bin\flutter.bat"

if not exist "%FLUTTER_EXECUTABLE%" (
  echo Flutter SDK is missing from %PROJECT_ROOT%.tools\flutter.
  exit /b 1
)

pushd "%PROJECT_ROOT%"
call "%FLUTTER_EXECUTABLE%" %*
set "FLUTTER_EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %FLUTTER_EXIT_CODE%
