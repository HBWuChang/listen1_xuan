@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

rem ============================================================
rem  Switch FFmpeg dependency config in pubspec.yaml and regenerate
rem  lib\services\ffmpeg_config.dart (Windows).
rem  Does NOT run `flutter pub get` and does NOT build anything.
rem
rem  Usage:
rem    scripts\build.bat with      FFmpeg-enabled (remove override, default)
rem    scripts\build.bat without   FFmpeg-free (add stub package override)
rem    scripts\build.bat check     Print current mode
rem ============================================================

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
if errorlevel 1 goto :error

set "MODE=%~1"

if "%MODE%"=="" goto :usage
if /i "%MODE%"=="check" goto :check
if /i "%MODE%"=="with" goto :switch
if /i "%MODE%"=="without" goto :switch
goto :usage

:switch
set "PUBSPEC=pubspec.yaml"
set "FFMPEG_CONFIG=lib\services\ffmpeg_config.dart"
set "BEGIN_MARK=BEGIN: no-ffmpeg override"
set "END_MARK=END: no-ffmpeg override"

call :strip_override
if errorlevel 1 goto :error

if /i "%MODE%"=="without" (
  >>"%PUBSPEC%" echo(
  >>"%PUBSPEC%" echo # %BEGIN_MARK%
  >>"%PUBSPEC%" echo dependency_overrides:
  >>"%PUBSPEC%" echo   ffmpeg_kit_flutter_new_audio:
  >>"%PUBSPEC%" echo     path: packages/ffmpeg_kit_flutter_new_audio
  >>"%PUBSPEC%" echo # %END_MARK%
  call :write_ffmpeg_config false
  echo MODE=without
) else (
  call :write_ffmpeg_config true
  echo MODE=with
)
goto :eof

:check
set "FFMPEG_CONFIG=lib\services\ffmpeg_config.dart"
findstr /c:"isFfmpegEnabled = false" "%FFMPEG_CONFIG%" >nul 2>&1
if errorlevel 1 (
  echo MODE=with
) else (
  echo MODE=without
)
goto :eof

rem Delete and regenerate lib\services\ffmpeg_config.dart with given value.
:write_ffmpeg_config
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p='%FFMPEG_CONFIG%'; $v='%~1'; " ^
  "$content='// GENERATED FILE - DO NOT EDIT MANUALLY.' + [Environment]::NewLine + " ^
  "'// 本文件由 scripts/build.sh / scripts/build.bat 自动生成，' + [Environment]::NewLine + " ^
  "'// 手动修改会在下次切换时被覆盖。' + [Environment]::NewLine + [Environment]::NewLine + " ^
  "'// Whether FFmpeg-dependent features are enabled' + [Environment]::NewLine + " ^
  "'// (bilibili transcode, cache metadata writing).' + [Environment]::NewLine + [Environment]::NewLine + " ^
  "'// Switch with:  scripts/build.sh with|without' + [Environment]::NewLine + " ^
  "'const bool isFfmpegEnabled = ' + $v + ';' + [Environment]::NewLine; " ^
  "[System.IO.File]::WriteAllText($p, $content, (New-Object System.Text.UTF8Encoding $false))"
exit /b %errorlevel%

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

:error
echo ==^> ERROR: failed to run scripts\build.bat. 1>&2
exit /b 1

:usage
echo Usage: scripts\build.bat ^<with^|without^|check^>
echo   with     FFmpeg-enabled ^(pub.dev package, default config^)
echo   without  FFmpeg-free ^(stub package override^)
echo   check    Print current mode
exit /b 1
