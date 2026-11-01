@echo off
rem Switch FFmpeg only; preserves Firebase mode. Requires Python 3.
python "%~dp0configure_build.py" ffmpeg "%~1"
exit /b %errorlevel%
