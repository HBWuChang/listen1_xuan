#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Apeiria重定向服务器
部署在 listen1-xuan.040905.xyz/Apeiria 上
接收带参数的请求后跳转到 listen1-xuan:// 协议
"""

from flask import Flask, request, redirect, jsonify, render_template_string
import urllib.parse
import logging
from datetime import datetime

app = Flask(__name__)

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# HTML模板，用于显示跳转页面
REDIRECT_TEMPLATE = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>正在跳转到 Listen1 Xuan</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.1);
            padding: 2rem;
            border-radius: 10px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }
        .loading {
            display: inline-block;
            width: 40px;
            height: 40px;
            border: 4px solid rgba(255, 255, 255, 0.3);
            border-top: 4px solid white;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 1rem 0;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .error {
            color: #ff6b6b;
            margin-top: 1rem;
        }
        .manual-link {
            margin-top: 1rem;
            word-break: break-all;
            background: rgba(255, 255, 255, 0.1);
            padding: 1rem;
            border-radius: 5px;
            font-family: monospace;
        }
        .btn {
            display: inline-block;
            padding: 0.5rem 1rem;
            margin: 0.5rem;
            background: rgba(255, 255, 255, 0.2);
            color: white;
            text-decoration: none;
            border-radius: 5px;
            transition: background 0.3s;
        }
        .btn:hover {
            background: rgba(255, 255, 255, 0.3);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>正在跳转到 Listen1 Xuan</h1>
        <div class="loading"></div>
        <p>正在尝试打开应用...</p>
        <div class="manual-link">
            <strong>目标链接:</strong><br>
            <span id="target-url">{{ target_url }}</span>
        </div>
        <p>如果应用未自动打开，请点击下方链接：</p>
        <a href="{{ target_url }}" class="btn">手动打开应用</a>
        <div id="error-message" class="error" style="display: none;">
            <p>自动跳转失败，请确保已安装 Listen1 Xuan 应用</p>
        </div>
    </div>

    <script>
        // 自动跳转逻辑 - 使用JSON编码确保URL正确传递
        const targetUrl = {{ target_url|tojson }};
        
        // 记录跳转尝试
        console.log('尝试跳转到:', targetUrl);
        
        // 立即尝试跳转
        try {
            window.location.href = targetUrl;
        } catch (error) {
            console.error('跳转失败:', error);
            document.getElementById('error-message').style.display = 'block';
        }
        
        // 3秒后显示错误信息
        setTimeout(function() {
            document.getElementById('error-message').style.display = 'block';
        }, 3000);
    </script>
</body>
</html>
'''

@app.route('/Apeiria')
def apeiria_redirect():
    """
    处理 /Apeiria 路径的请求
    接收所有查询参数并转发到 listen1-xuan:// 协议
    """
    try:
        # 获取所有查询参数
        query_params = request.args.to_dict()
        
        # 构建目标URL
        base_url = "listen1-xuan://listen1-xuan.040905.xyz/Apeiria"
        
        # 如果有参数，添加到URL中
        if query_params:
            query_string = urllib.parse.urlencode(query_params)
            target_url = f"{base_url}?{query_string}"
        else:
            target_url = base_url
        
        # 记录请求日志
        logger.info(f"收到请求 - IP: {request.remote_addr}, 参数: {query_params}")
        logger.info(f"目标URL: {target_url}")
        
        # 检查是否是API请求（通过Accept头判断）
        if request.headers.get('Accept', '').startswith('application/json'):
            return jsonify({
                'success': True,
                'target_url': target_url,
                'timestamp': datetime.now().isoformat(),
                'parameters': query_params
            })
        
        # 返回HTML页面进行跳转
        return render_template_string(REDIRECT_TEMPLATE, target_url=target_url)
        
    except Exception as e:
        logger.error(f"处理请求时出错: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500

@app.route('/')
def index():
    """根路径信息页面"""
    return jsonify({
        'service': 'Listen1 Xuan Apeiria 重定向服务',
        'version': '1.0.0',
        'endpoints': {
            '/Apeiria': '重定向到 listen1-xuan://listen1-xuan.040905.xyz/Apeiria',
        },
        'usage': '在URL后添加查询参数，例如: /Apeiria?param1=value1&param2=value2',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    # 开发环境运行
    app.run(debug=False, host='127.0.0.1', port=25922)