@echo off
setlocal
set "PROJECT_ROOT=%~dp0"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "RUNTIME_DRIVE=Z:"
subst %RUNTIME_DRIVE% "%PROJECT_ROOT%" >nul 2>&1
if errorlevel 1 (
  set "RUNTIME_DRIVE=Y:"
  subst %RUNTIME_DRIVE% "%PROJECT_ROOT%" >nul 2>&1
)
if errorlevel 1 (
  echo Unable to create a temporary drive alias for the Student View folder.
  exit /b 1
)
set "RUNTIME_ROOT=%RUNTIME_DRIVE%\"
for %%I in ("%PROJECT_ROOT%\..") do set "WORKSPACE_ROOT=%%~fI"
set "GRADLE_USER_HOME=%RUNTIME_ROOT%.tools\gradle"
set "PUB_CACHE=%PROJECT_ROOT%.tools\pub-cache"
if exist "%WORKSPACE_ROOT%\.tools\pub-cache\hosted" set "PUB_CACHE=%WORKSPACE_ROOT%\.tools\pub-cache"
set "TEMP=%RUNTIME_ROOT%.tools\temp"
set "TMP=%TEMP%"
set "GIT_CONFIG_COUNT=1"
set "GIT_CONFIG_KEY_0=safe.directory"
set "GIT_CONFIG_VALUE_0=%RUNTIME_ROOT%.tools\flutter"
set "FLUTTER_EXECUTABLE=%RUNTIME_ROOT%.tools\flutter\bin\flutter.bat"

if not exist "%FLUTTER_EXECUTABLE%" (
  echo Flutter SDK is missing from %RUNTIME_ROOT%.tools\flutter.
  subst %RUNTIME_DRIVE% /d >nul 2>&1
  exit /b 1
)
if not exist "%RUNTIME_ROOT%.tools\flutter\packages\flutter_tools" (
  echo Flutter SDK is incomplete: packages\flutter_tools is missing.
  subst %RUNTIME_DRIVE% /d >nul 2>&1
  exit /b 1
)

pushd "%RUNTIME_ROOT%"
call "%FLUTTER_EXECUTABLE%" %*
set "FLUTTER_EXIT_CODE=%ERRORLEVEL%"
popd
subst %RUNTIME_DRIVE% /d >nul 2>&1
exit /b %FLUTTER_EXIT_CODE%
