# supabase-proxy

Cloudflare Worker：为 Supabase 项目 `jtvxrwybwvgpqobyhaoy` 做**透明反向代理**，
用于在受限网络环境下让 listen1_xuan 客户端仍能连上 Supabase。

## 为什么不是 siteproxy

siteproxy 是 **HTML 重写型网页代理**，靠改写响应里的链接工作，URL 形如
`https://proxy/{token}/https/target/path`。

Supabase 是**纯 API 客户端**，路上跑的是 JSON / SSE / WebSocket，没有 HTML 可重写；
而 `supabase_flutter` 把端点路径写死在
`supabase-2.16.1/lib/src/supabase_client.dart:136-142`：

```dart
_restUrl      = '$supabaseUrl/rest/v1';
_realtimeUrl  = '$supabaseUrl/realtime/v1'.replaceAll('http', 'ws');
_authUrl      = '$supabaseUrl/auth/v1';
_storageUrl   = '$supabaseUrl/storage/v1';
_functionsUrl = '$supabaseUrl/functions/v1';
```

客户端无法注入路径前缀。所以这里走「**换域名、保路径**」的透明反代，
只需把 `supabaseUrl` 换成 Worker 域名即可，代码逻辑一行不用改。

## 覆盖范围

| 路径 | 说明 |
|---|---|
| `/rest/v1/*` | PostgREST（歌单 / users / tokens / continue_play） |
| `/auth/v1/*` | GoTrue（注册、密码登录、OTP） |
| `/storage/v1/*` | Storage |
| `/functions/v1/*` | Edge Functions |
| `/realtime/v1/*` | Realtime，**含 WebSocket Upgrade 透传** |

## 部署

```bash
cd workers/supabase-proxy
npm install
npx wrangler login          # 浏览器 OAuth，需你本人操作
npm run deploy
```

部署后 Cloudflare 会给出 `supabase-proxy.<你的子域>.workers.dev`。
国内网络下 `*.workers.dev` 基本不可达，**务必绑自定义域**：

在 `wrangler.jsonc` 里取消注释并改成你的域名：

```jsonc
"routes": [
  { "pattern": "sb.example.com", "custom_domain": true }
]
```

前提：该域名已托管在同一个 Cloudflare 账号下。`custom_domain: true` 会
自动创建 DNS 记录并签发证书，不需要手工配 CNAME。

⚠️ 必须是**一级**子域（`sb.example.com`），不能是 `sb.a.example.com`。
见下方「踩过的坑」第 1 条。

重新 `npm run deploy` 后验证：

```bash
curl https://sb.example.com/__spx/health
# {"ok":true,"upstream":"https://jtvxrwybwvgpqobyhaoy.supabase.co",...}
```

## 客户端改法

`lib/main.dart:71`：

```dart
// 支持编译期覆盖，便于按渠道/机型切换
const String _supabaseUrlOverride =
    String.fromEnvironment('SUPABASE_URL_OVERRIDE');

String supabaseUrl = _supabaseUrlOverride.isNotEmpty
    ? _supabaseUrlOverride
    : 'https://jtvxrwybwvgpqobyhaoy.supabase.co';
```

构建时：

```bash
flutter build apk --dart-define=SUPABASE_URL_OVERRIDE=https://sb.example.com
```

### 会话存储键会变

`supabase_flutter-2.17.2/lib/src/supabase.dart:135` 用
`"sb-${Uri.parse(url).host.split(".").first}-auth-token"` 作 SharedPreferences 键。
换域名后键从 `sb-jtvxrwybwvgpqobyhaoy-auth-token` 变成 `sb-sb-auth-token`，
**老用户本地 session 失效**。影响可控 —— `SupabaseAuthController` 会在
`INITIAL_SESSION` 事件里用本地保存的账密自动重登。

要完全无感，就在初始化时显式固定键名：

```dart
await Supabase.initialize(
  url: supabaseUrl,
  anonKey: supabaseKey,
  authOptions: FlutterAuthClientOptions(
    localStorage: SharedPreferencesLocalStorage(
      persistSessionKey: 'sb-jtvxrwybwvgpqobyhaoy-auth-token',
    ),
  ),
);
```

## 可选配置

见 `wrangler.jsonc` 的 `vars`：

| 变量 | 默认 | 说明 |
|---|---|---|
| `UPSTREAM` | Supabase 地址 | 上游，只做 origin 级替换 |
| `AUTH_TOKEN` | 空 | 非空则要求 `x-proxy-token` 头，否则 401。客户端用 `Supabase.initialize(headers: {'x-proxy-token': '...'})` 携带。**注意这是客户端持有的值，只能挡扫描，不算真密钥** |
| `FORCE_ORIGIN` | 空 | 强制改写发出的 `Origin`。Flutter 桌面/移动端不发 Origin，一般不用管；若 Supabase 控制台给 Realtime 配了 Origin 白名单，填上游 origin |
| `REWRITE_REDIRECT` | `true` | 把上游 `Location`、`Set-Cookie` 的 `Domain` 改写成本代理域名 |
| `HEALTH_PATH` | `/__spx/health` | 设为空串关闭 |

## 已验证

在 `wrangler dev`（本地 workerd + 真实上游）下实测：

- `GET /auth/v1/health` → 401 且响应体与直连一致
- `GET /rest/v1/users?select=user_id&limit=2` → `200 []`
- `GET /rest/v1/nope_table` → 404，响应体 SHA1 与直连同值（逐字节一致，含 gzip 透传）
- `POST /auth/v1/token?grant_type=password` → 400 `invalid_credentials`（body 转发正常）
- `GET /realtime/v1/websocket` 裸握手 → `HTTP/1.1 101 Switching Protocols`
- WebSocket `phx_join`（带 `postgres_changes` + `filter`，即客户端真实用法）
  → `phx_reply status ok`

## 踩过的坑

### 1. 自定义域只能是**一级**子域

```
curl: (35) LibreSSL/3.3.6: error:1404B410:SSL routines:ST_CONNECT:sslv3 alert handshake failure
```

不是 Worker 的问题，是边缘根本没证书。实测该 zone 的证书 SAN：

```
subject=CN=040905.xyz
X509v3 Subject Alternative Name:
    DNS:040905.xyz, DNS:*.040905.xyz
```

`h3.040905.xyz` 匹配 `*.040905.xyz` ✅
`sb.jtvxrwybwvgpqobyhaoy.040905.xyz` 是 apex 下**两层**，不匹配 ❌

Cloudflare 免费版 Universal SSL **只覆盖 apex 和一级子域**。
多层子域 DNS 能解析（`custom_domain: true` 会自动建记录）、Worker 也能部署，
但 TLS 握手直接被服务端拒绝（`SSL alert number 40`）。

所以 `routes.pattern` 要写成 `sb.example.com` 这种一级形式。
非要用多层子域就得买 Total TLS / Advanced Certificate Manager。

排查手法：

```bash
# 证书是否覆盖该主机名
echo | openssl s_client -connect sb.example.com:443 -servername sb.example.com 2>/dev/null \
  | openssl x509 -noout -subject -ext subjectAltName
```

### 2. 不要写 `url.host = upstream.host`

workerd 的 URL 实现里 host setter **不会清掉已有端口**，
`https://127.0.0.1:8787/auth/v1/health` 会变成
`https://jtvxrwybwvgpqobyhaoy.supabase.co:8787/auth/v1/health`，
打到被 Cloudflare 黑洞的非标准端口，表现为 `fetch` 挂死 150 秒后超时，
客户端只看到连接超时（curl `000`）。

必须分别设置：

```js
target.protocol = upstream.protocol;
target.hostname = upstream.hostname;
target.port     = upstream.port;
```

生产环境入站请求无显式端口，这个 bug 不会触发，但 `wrangler dev`
和任何跑在非标准端口上的场景都会中招。
