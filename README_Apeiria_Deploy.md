# Apeiria 重定向服务部署指南

## 概述
这是一个Python Flask应用，用于处理web请求并重定向到 `listen1-xuan://` 自定义协议。

## 功能特性
- 接收 `/Apeiria` 路径的GET请求
- 自动将所有查询参数转发到自定义协议URL
- 支持子路径重定向（如 `/Apeiria/playlist`）
- 提供美观的HTML跳转页面
- 支持JSON API响应
- 包含健康检查端点

## 部署方式

### 1. 使用 Nginx + Gunicorn (推荐)

#### 安装依赖
```bash
pip install -r requirements.txt
```

#### 运行服务
```bash
# 生产环境
gunicorn -w 4 -b 0.0.0.0:5000 apeiria_redirect:app

# 或者指定更多参数
gunicorn -w 4 -b 0.0.0.0:5000 --access-logfile - --error-logfile - apeiria_redirect:app
```

#### Nginx配置示例
```nginx
server {
    listen 80;
    server_name listen1-xuan.040905.xyz;

    location /Apeiria {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 可选：健康检查
    location /health {
        proxy_pass http://localhost:5000;
    }
}
```

### 2. 使用 Docker

#### Dockerfile
```dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY apeiria_redirect.py .

EXPOSE 5000

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "apeiria_redirect:app"]
```

#### 构建和运行
```bash
docker build -t apeiria-redirect .
docker run -p 5000:5000 apeiria-redirect
```

### 3. 直接使用 Flask 开发服务器（仅用于测试）
```bash
python apeiria_redirect.py
```

## 使用示例

### 1. 基本重定向
访问：`https://listen1-xuan.040905.xyz/Apeiria`
重定向到：`listen1-xuan://listen1-xuan.040905.xyz/Apeiria`

### 2. 带参数重定向
访问：`https://listen1-xuan.040905.xyz/Apeiria?song=123&playlist=abc`
重定向到：`listen1-xuan://listen1-xuan.040905.xyz/Apeiria?song=123&playlist=abc`

### 3. 带子路径重定向
访问：`https://listen1-xuan.040905.xyz/Apeiria/playlist?id=456`
重定向到：`listen1-xuan://listen1-xuan.040905.xyz/Apeiria/playlist?id=456`

### 4. API访问
```bash
curl -H "Accept: application/json" "https://listen1-xuan.040905.xyz/Apeiria?test=1"
```
返回JSON响应：
```json
{
    "success": true,
    "target_url": "listen1-xuan://listen1-xuan.040905.xyz/Apeiria?test=1",
    "timestamp": "2024-01-01T12:00:00",
    "parameters": {"test": "1"}
}
```

## 监控和日志
- 访问 `/health` 进行健康检查
- 应用会自动记录所有请求日志
- 可以通过日志监控服务使用情况

## 安全考虑
- 应用不执行任何危险操作，只进行URL重定向
- 所有参数都经过URL编码处理
- 支持HTTPS（需要在反向代理层配置）

## 故障排除
1. 确保Listen1 Xuan应用已安装并注册了自定义协议
2. 检查防火墙设置，确保端口开放
3. 查看应用日志排查问题
4. 使用 `/health` 端点检查服务状态