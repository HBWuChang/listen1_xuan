@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

rem ============================================================
rem  Dual-build config switch script (with/without FFmpeg) - Windows
rem
rem  Usage:
rem    scripts\build.bat with                   FFmpeg-enabled (default)
rem    scripts\build.bat without                FFmpeg-free (stub override)
rem    scripts\build.bat check                  Print current mode
rem    scripts\build.bat <mode> --no-pub-get    Skip flutter pub get
rem
rem  Only switches the pubspec dependency config; it does NOT build.
rem  Windows equivalent of scripts/build.sh
rem ============================================================

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
if errorlevel 1 goto :error

set "MODE=%~1"
set "SKIP_PUB_GET=0"
if /i "%~2"=="--no-pub-get" set "SKIP_PUB_GET=1"

if "%MODE%"=="" goto :usage
if /i "%MODE%"=="check" goto :check
if /i "%MODE%"=="with" goto :switch
if /i "%MODE%"=="without" goto :switch
goto :usage

:switch
set "PUBSPEC=pubspec.yaml"
set "BACKUP=%TEMP%\pubspec.build.bak"
set "BEGIN_MARK=BEGIN: no-ffmpeg override"
set "END_MARK=END: no-ffmpeg override"

copy /y "%PUBSPEC%" "%BACKUP%" >nul
if errorlevel 1 goto :error

call :strip_override
if errorlevel 1 goto :rollback

if /i "%MODE%"=="without" (
  >>"%PUBSPEC%" echo(
  >>"%PUBSPEC%" echo # %BEGIN_MARK%
  >>"%PUBSPEC%" echo dependency_overrides:
  >>"%PUBSPEC%" echo   ffmpeg_kit_flutter_new_audio:
  >>"%PUBSPEC%" echo     path: packages/ffmpeg_kit_flutter_new_audio
  >>"%PUBSPEC%" echo # %END_MARK%
  echo ==^> Config: FFmpeg-free ^(stub package packages\ffmpeg_kit_flutter_new_audio^)
) else (
  echo ==^> Config: FFmpeg-enabled ^(pub.dev ffmpeg_kit_flutter_new_audio ^^2.5.2^)
)

if "%SKIP_PUB_GET%"=="1" (
  echo ==^> Skipping flutter pub get ^(--no-pub-get^)
) else (
  echo ==^> flutter pub get
  call flutter pub get
  if errorlevel 1 goto :rollback
)

del "%BACKUP%" >nul 2>&1

echo.
echo Config switch done. Run your platform build now ^(do NOT run flutter pub get again^),
if /i "%MODE%"=="without" (
  echo and pass: flutter build ... --dart-define=ENABLE_FFMPEG=false
) else (
  echo and pass: flutter build ... --dart-define=ENABLE_FFMPEG=true
)
goto :eof

:check
set "PUBSPEC=pubspec.yaml"
findstr /c:"BEGIN: no-ffmpeg override" "%PUBSPEC%" >nul 2>&1
if errorlevel 1 (
  echo MODE=with
  echo ENABLE_FFMPEG=true
) else (
  echo MODE=without
  echo ENABLE_FFMPEG=false
)
goto :eof

rem Remove the injected override block (idempotent), then trim any trailing
rem blank lines so the pubspec is restored byte-identical.
:strip_override
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p='%PUBSPEC%'; $b='BEGIN: no-ffmpeg override'; $e='END: no-ffmpeg override'; " ^
  "$lines=[System.IO.File]::ReadAllLines($p); $out=New-Object System.Collections.Generic.List[string]; " ^
  "$in=$false; foreach($l in $lines){ if($l -like \"*$b*\"){$in=$true; continue}; if($l -like \"*$e*\"){$in=$false; continue}; if(-not $in){[void]$out.Add($l)} }; " ^
  "while($out.Count -gt 0 -and $out[$out.Count-1] -eq ''){[void]$out.RemoveAt($out.Count-1)}; " ^
  "[System.IO.File]::WriteAllLines($p, $out, (New-Object System.Text.UTF8Encoding $false))"
exit /b %errorlevel%

:rollback
copy /y "%BACKUP%" "%PUBSPEC%" >nul 2>&1
del "%BACKUP%" >nul 2>&1
echo ==^> FAILED: reverted pubspec.yaml to previous state. 1>&2
exit /b 1

:error
echo ==^> ERROR: failed to run scripts\build.bat. 1>&2
exit /b 1

:usage
echo Usage: scripts\build.bat ^<with^|without^|check^> [--no-pub-get]
echo   with     FFmpeg-enabled ^(pub.dev package, default config^)
echo   without  FFmpeg-free ^(stub package override^)
echo   check    Print current mode and ENABLE_FFMPEG value
exit /b 1
