@echo off
REM WebSocket客户端测试脚本
REM 使用方法: test_ws.bat "消息内容" [服务器地址]

setlocal enabledelayedexpansion

echo ========================================
echo WebSocket测试客户端
echo ========================================

REM 检查Python是否安装
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ 错误: 未找到Python环境
    echo 请先安装Python 3.x
    pause
    exit /b 1
)

REM 检查websocket-client是否安装
python -c "import websocket" >nul 2>&1
if errorlevel 1 (
    echo ⚠️  警告: 未安装websocket-client包
    echo 正在自动安装...
    pip install websocket-client
    if errorlevel 1 (
        echo ❌ 安装失败，请手动运行: pip install websocket-client
        pause
        exit /b 1
    )
    echo ✅ websocket-client安装成功
    echo.
)

REM 检查参数
if "%~1"=="" (
    echo 使用方法: %~n0 "消息内容" [服务器地址]
    echo.
    echo 示例:
    echo   %~n0 "Hello WebSocket!"
    echo   %~n0 "Test message" ws://192.168.1.100:8080
    echo.
    echo 启动交互模式? (y/N)
    set /p choice=
    if /i "!choice!"=="y" (
        python test_websocket_client.py
    )
    pause
    exit /b 0
)

REM 执行测试
if "%~2"=="" (
    python simple_ws_client.py "%~1"
) else (
    python simple_ws_client.py "%~1" "%~2"
)

pause