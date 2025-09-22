# Caddy配置更新说明

由于Python程序现在使用端口25922，请更新你的Caddyfile中的端口配置：

将：
```caddy
reverse_proxy 127.0.0.1:5000 {
```

改为：
```caddy
reverse_proxy 127.0.0.1:25922 {
```

完整的listen1-xuan.040905.xyz配置应该是：

```caddy
listen1-xuan.040905.xyz {
	tls {
		dns cloudflare iumv38r7SFliLeOtcML2Vqa0bK2X4KlCSD2hYbg6
	}

	encode gzip

	# 处理 /Apeiria 路径的请求，转发到 Python 重定向服务
	handle /Apeiria* {
		reverse_proxy 127.0.0.1:25922 {
			header_up Host {host}
			header_up X-Real-IP {remote}
			header_up X-Forwarded-For {remote}
			header_up X-Forwarded-Proto {scheme}
			header_up User-Agent {header.User-Agent}
			header_up Accept {header.Accept}
			header_up Accept-Language {header.Accept-Language}
		}
	}

	# 健康检查端点
	handle /health {
		reverse_proxy 127.0.0.1:25922 {
			header_up Host {host}
			header_up X-Real-IP {remote}
			header_up X-Forwarded-For {remote}
			header_up X-Forwarded-Proto {scheme}
		}
	}

	root * /home/xiebian/listen1_xuan
	file_server {
		index index.html index.htm
	}
}
```