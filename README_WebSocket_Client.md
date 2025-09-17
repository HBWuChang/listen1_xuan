# WebSocket测试客户端使用说明

这里提供了几个Python WebSocket测试客户端，用于测试Flutter WebSocket服务器的功能。

## 文件说明

### 1. `test_websocket_client.py` - 交互式客户端
功能最完整的WebSocket测试客户端，支持：
- 交互式命令行界面
- 实时消息收发
- JSON和文本消息支持
- 连接状态监控
- 心跳处理

### 2. `simple_ws_client.py` - 简单客户端
用于快速测试单条消息的简化客户端，支持：
- 一次性发送消息
- 等待服务器响应
- 自动断开连接
- JSON和文本消息支持

### 3. `test_ws.bat` - Windows批处理脚本
Windows用户的便捷启动脚本，支持：
- 自动检查Python环境
- 自动安装依赖包
- 快捷命令行调用

## 安装依赖

```bash
# 安装websocket-client包
pip install websocket-client
```

## 使用方法

### 交互式模式
```bash
# 启动交互式客户端
python test_websocket_client.py

# 指定服务器地址
python test_websocket_client.py ws://192.168.1.100:8080
```

### 快速测试模式
```bash
# 发送简单消息
python simple_ws_client.py "Hello WebSocket!"

# 指定服务器地址
python simple_ws_client.py "Test message" ws://192.168.1.100:8080

# 发送JSON消息
python simple_ws_client.py '{"type":"ping","content":"test"}'
```

### Windows批处理
```cmd
REM 发送消息
test_ws.bat "Hello WebSocket!"

REM 指定服务器
test_ws.bat "Test message" ws://192.168.1.100:8080

REM 交互模式（不带参数运行）
test_ws.bat
```

## 消息格式

### 标准JSON消息格式
```json
{
    "type": "message",
    "content": "消息内容",
    "timestamp": "2024-01-01T12:00:00",
    "sender": "客户端标识"
}
```

### 支持的消息类型
- `message` - 普通消息
- `ping` - 心跳测试
- `connect` - 连接通知
- `test` - 测试消息

## 测试场景示例

### 1. 基本连接测试
```bash
python simple_ws_client.py "连接测试"
```

### 2. 消息广播测试
1. 启动多个客户端：
```bash
python test_websocket_client.py
```
2. 在Flutter应用中广播消息
3. 观察所有客户端是否收到消息

### 3. JSON消息测试
```bash
python simple_ws_client.py '{"type":"custom","data":{"id":123,"name":"测试"}}'
```

### 4. 长时间连接测试
```bash
python test_websocket_client.py
# 保持连接，测试心跳和稳定性
```

## 故障排除

### 连接失败
1. 检查WebSocket服务器是否启动
2. 检查IP地址和端口是否正确
3. 检查防火墙设置

### 依赖安装失败
```bash
# 更新pip
python -m pip install --upgrade pip

# 手动安装
pip install websocket-client --user
```

### 编码问题
如果遇到中文显示问题，确保终端支持UTF-8编码：
```bash
# Windows CMD
chcp 65001

# 或使用PowerShell
$OutputEncoding = [System.Text.Encoding]::UTF8
```

## 开发和调试

### 启用WebSocket调试日志
在Python客户端中修改：
```python
websocket.enableTrace(True)  # 启用详细日志
```

### 自定义消息处理
可以修改 `on_message` 方法来自定义消息处理逻辑：
```python
def on_message(self, ws, message):
    # 自定义处理逻辑
    print(f"收到: {message}")
```

## 性能测试

### 批量消息测试
可以修改客户端代码进行压力测试：
```python
# 发送多条消息
for i in range(100):
    client.send_message(f"消息 {i}")
    time.sleep(0.1)  # 间隔100ms
```

### 并发连接测试
启动多个客户端实例测试服务器的并发处理能力。

---

## 注意事项

1. **服务器地址**: 默认连接到 `ws://localhost:8080`
2. **消息编码**: 支持UTF-8编码的中文消息
3. **连接超时**: 默认连接超时为10秒
4. **响应等待**: 简单客户端默认等待2秒服务器响应
5. **异常处理**: 客户端具备基本的错误处理和恢复能力