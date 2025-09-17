#!/usr/bin/env python3
"""
WebSocket测试客户端
用于测试Flutter WebSocket服务器的功能

使用方法:
1. 安装依赖: pip install websocket-client
2. 运行客户端: python test_websocket_client.py
3. 输入消息进行测试，输入 'quit' 退出

功能:
- 连接到WebSocket服务器
- 发送文本消息
- 接收并显示服务器消息
- 处理ping/pong心跳
- 优雅断开连接
"""

import websocket
import json
import threading
import time
import sys
from datetime import datetime

class WebSocketTestClient:
    def __init__(self, url="ws://localhost:8080"):
        self.url = url
        self.ws = None
        self.connected = False
        self.running = False
        
    def on_message(self, ws, message):
        """接收到消息时的回调"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        try:
            # 尝试解析JSON消息
            data = json.loads(message)
            if isinstance(data, dict):
                msg_type = data.get('type', 'unknown')
                content = data.get('content', data)
                print(f"[{timestamp}] 📨 收到 {msg_type} 消息: {content}")
            else:
                print(f"[{timestamp}] 📨 收到JSON: {data}")
        except json.JSONDecodeError:
            # 处理纯文本消息
            print(f"[{timestamp}] 📨 收到消息: {message}")
    
    def on_error(self, ws, error):
        """连接出错时的回调"""
        print(f"❌ WebSocket错误: {error}")
    
    def on_close(self, ws, close_status_code, close_msg):
        """连接关闭时的回调"""
        self.connected = False
        print(f"🔌 连接已关闭 (状态码: {close_status_code})")
        if close_msg:
            print(f"关闭原因: {close_msg}")
    
    def on_open(self, ws):
        """连接建立时的回调"""
        self.connected = True
        print("✅ WebSocket连接已建立!")
        print("💡 提示: 输入消息按Enter发送，输入 'quit' 退出")
        print("-" * 50)
        
        # 发送初始连接消息
        welcome_msg = {
            "type": "connect",
            "content": "Python客户端已连接",
            "timestamp": datetime.now().isoformat()
        }
        self.send_message(welcome_msg)
    
    def send_message(self, message):
        """发送消息到服务器"""
        if not self.connected or not self.ws:
            print("❌ 未连接到服务器")
            return False
            
        try:
            if isinstance(message, dict):
                # 发送JSON消息
                json_msg = json.dumps(message, ensure_ascii=False)
                self.ws.send(json_msg)
                print(f"📤 已发送JSON: {message}")
            else:
                # 发送文本消息
                self.ws.send(str(message))
                print(f"📤 已发送: {message}")
            return True
        except Exception as e:
            print(f"❌ 发送消息失败: {e}")
            return False
    
    def connect(self):
        """连接到WebSocket服务器"""
        try:
            print(f"🔗 正在连接到 {self.url}...")
            
            # 启用WebSocket调试日志
            websocket.enableTrace(False)
            
            # 创建WebSocket连接
            self.ws = websocket.WebSocketApp(
                self.url,
                on_open=self.on_open,
                on_message=self.on_message,
                on_error=self.on_error,
                on_close=self.on_close
            )
            
            # 在单独线程中运行WebSocket
            self.running = True
            ws_thread = threading.Thread(target=self.ws.run_forever, daemon=True)
            ws_thread.start()
            
            # 等待连接建立
            timeout = 10
            for i in range(timeout):
                if self.connected:
                    return True
                time.sleep(1)
            
            print("❌ 连接超时")
            return False
            
        except Exception as e:
            print(f"❌ 连接失败: {e}")
            return False
    
    def disconnect(self):
        """断开WebSocket连接"""
        self.running = False
        if self.ws:
            self.ws.close()
            print("👋 正在断开连接...")
    
    def run_interactive(self):
        """运行交互模式"""
        if not self.connect():
            return
        
        try:
            while self.running and self.connected:
                try:
                    # 获取用户输入
                    user_input = input("💬 输入消息 > ").strip()
                    
                    if user_input.lower() in ['quit', 'exit', 'q']:
                        break
                    
                    if not user_input:
                        continue
                    
                    # 尝试解析为JSON
                    if user_input.startswith('{') and user_input.endswith('}'):
                        try:
                            json_data = json.loads(user_input)
                            self.send_message(json_data)
                        except json.JSONDecodeError:
                            self.send_message(user_input)
                    else:
                        # 构造JSON消息
                        message = {
                            "type": "message",
                            "content": user_input,
                            "timestamp": datetime.now().isoformat(),
                            "sender": "Python客户端"
                        }
                        self.send_message(message)
                        
                except KeyboardInterrupt:
                    break
                except EOFError:
                    break
                    
        finally:
            self.disconnect()

def main():
    """主函数"""
    print("🚀 WebSocket测试客户端启动")
    print("=" * 50)
    
    # 检查命令行参数
    url = "ws://192.168.2.123:8080"
    url = "ws://localhost:8080"
    if len(sys.argv) > 1:
        url = sys.argv[1]
    
    print(f"🎯 目标服务器: {url}")
    
    # 创建并运行客户端
    client = WebSocketTestClient(url)
    
    try:
        client.run_interactive()
    except KeyboardInterrupt:
        print("\n\n⏹️  收到中断信号，正在退出...")
    finally:
        client.disconnect()
        print("👋 客户端已退出")

if __name__ == "__main__":
    main()