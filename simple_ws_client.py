#!/usr/bin/env python3
"""
WebSocket简单测试客户端
用于快速测试单条消息发送

使用方法:
1. 安装依赖: pip install websocket-client
2. 发送消息: python simple_ws_client.py "Hello WebSocket!"
3. 指定服务器: python simple_ws_client.py "Hello!" ws://localhost:8080

功能:
- 连接WebSocket服务器
- 发送一条消息
- 显示服务器响应
- 自动断开连接
"""

import websocket
import json
import sys
import time
import threading
from datetime import datetime

class SimpleWebSocketClient:
    def __init__(self, url="ws://localhost:8080"):
        self.url = url
        self.connected = False
        self.received_messages = []
        self.ws = None
        
    def on_message(self, ws, message):
        """接收消息"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        try:
            data = json.loads(message)
            self.received_messages.append(f"[{timestamp}] JSON: {data}")
        except json.JSONDecodeError:
            self.received_messages.append(f"[{timestamp}] TEXT: {message}")
    
    def on_error(self, ws, error):
        """处理错误"""
        print(f"❌ 错误: {error}")
    
    def on_close(self, ws, close_status_code, close_msg):
        """连接关闭"""
        self.connected = False
    
    def on_open(self, ws):
        """连接建立"""
        self.connected = True
    
    def send_single_message(self, message, wait_time=2):
        """发送单条消息并等待响应"""
        try:
            print(f"🔗 连接到 {self.url}")
            
            # 创建WebSocket连接
            self.ws = websocket.WebSocketApp(
                self.url,
                on_open=self.on_open,
                on_message=self.on_message,
                on_error=self.on_error,
                on_close=self.on_close
            )
            
            # 在后台线程运行WebSocket
            def run_websocket():
                self.ws.run_forever()
            
            ws_thread = threading.Thread(target=run_websocket, daemon=True)
            ws_thread.start()
            
            # 等待连接
            for i in range(50):  # 5秒超时
                if self.connected:
                    break
                time.sleep(0.1)
            
            if not self.connected:
                print("❌ 连接超时")
                return False
            
            print("✅ 连接成功")
            
            # 构造消息
            if message.startswith('{') and message.endswith('}'):
                try:
                    # 尝试解析为JSON
                    json_msg = json.loads(message)
                    send_data = json.dumps(json_msg, ensure_ascii=False)
                except json.JSONDecodeError:
                    # 如果不是有效JSON，作为文本发送
                    send_data = message
            else:
                # 构造标准JSON消息
                json_msg = {
                    "type": "test",
                    "content": message,
                    "timestamp": datetime.now().isoformat(),
                    "sender": "SimpleClient"
                }
                send_data = json.dumps(json_msg, ensure_ascii=False)
            
            # 发送消息
            print(f"📤 发送消息: {message}")
            self.ws.send(send_data)
            
            # 等待响应
            print(f"⏳ 等待响应 ({wait_time}秒)...")
            time.sleep(wait_time)
            
            # 显示接收到的消息
            if self.received_messages:
                print(f"📨 接收到 {len(self.received_messages)} 条消息:")
                for msg in self.received_messages:
                    print(f"   {msg}")
            else:
                print("📭 未收到响应消息")
            
            # 关闭连接
            self.ws.close()
            print("🔌 连接已关闭")
            return True
            
        except Exception as e:
            print(f"❌ 发送失败: {e}")
            return False

def show_usage():
    """显示使用说明"""
    print("WebSocket简单测试客户端")
    print("=" * 40)
    print("使用方法:")
    print("  python simple_ws_client.py <消息> [WebSocket地址]")
    print()
    print("示例:")
    print("  python simple_ws_client.py \"Hello WebSocket!\"")
    print("  python simple_ws_client.py \"Test message\" ws://192.168.1.100:8080")
    print("  python simple_ws_client.py '{\"type\":\"ping\",\"content\":\"test\"}'")
    print()
    print("参数:")
    print("  消息        - 要发送的消息内容")
    print("  WebSocket地址 - 服务器地址 (默认: ws://localhost:8080)")

def main():
    """主函数"""
    if len(sys.argv) < 2:
        show_usage()
        return
    
    message = sys.argv[1]
    url = sys.argv[2] if len(sys.argv) > 2 else "ws://localhost:8080"
    
    print(f"🚀 WebSocket简单测试客户端")
    print(f"🎯 服务器: {url}")
    print("-" * 40)
    
    client = SimpleWebSocketClient(url)
    client.send_single_message(message)

if __name__ == "__main__":
    main()