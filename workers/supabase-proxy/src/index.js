/**
 * Supabase 透明反向代理（Cloudflare Worker）
 *
 * 为什么不做成 siteproxy 那种 «路径前缀» 代理：
 * siteproxy 是 HTML 重写型网页代理，靠改写响应里的链接工作。
 * Supabase 是纯 API 客户端（JSON / SSE / WebSocket），没有 HTML 可重写，
 * 且 supabase_flutter 把端点路径写死为 `$supabaseUrl/rest/v1` 等，
 * 无法注入路径前缀。所以这里走 «换域名、保路径» 的透明反代。
 *
 * 覆盖的端点（由 supabase_client.dart:136-142 决定）：
 *   /rest/v1/*        PostgREST
 *   /auth/v1/*        GoTrue
 *   /storage/v1/*     Storage
 *   /functions/v1/*   Edge Functions
 *   /realtime/v1/*    Realtime（WebSocket，需 Upgrade 透传）
 */

const DEFAULT_UPSTREAM = 'https://jtvxrwybwvgpqobyhaoy.supabase.co';

/**
 * 逐跳（hop-by-hop）与边缘注入头，不能原样转发给上游。
 * 注意：`host` 不在此列 —— 它属于 forbidden header，
 * 删不掉也不影响，Worker 出网时会按目标 URL 自动重算。
 */
const STRIP_REQUEST_HEADERS = [
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade-insecure-requests',
  // CF 边缘注入
  'cf-connecting-ip',
  'cf-connecting-ipv6',
  'cf-ipcountry',
  'cf-ray',
  'cf-visitor',
  'cf-worker',
  'cf-ew-via',
  'cdn-loop',
  // 上游可能据此判断真实来源，去掉更干净
  'x-forwarded-host',
  'x-forwarded-port',
  'x-forwarded-proto',
  'x-real-ip',
  'x-forwarded-for',
  'forwarded',
];

export default {
  /**
   * @param {Request} request
   * @param {Record<string, string>} env
   */
  async fetch(request, env) {
    const upstream = parseUpstream(env.UPSTREAM);
    const incomingUrl = new URL(request.url);

    // ---------- 健康检查 ----------
    const healthPath = env.HEALTH_PATH ?? '/__spx/health';
    if (healthPath && incomingUrl.pathname === healthPath) {
      return Response.json({
        ok: true,
        upstream: upstream.origin,
        realtime: `${upstream.origin}/realtime/v1`,
        auth: `${upstream.origin}/auth/v1`,
      });
    }

    // ---------- 可选口令 ----------
    const token = (env.AUTH_TOKEN ?? '').trim();
    if (token && request.headers.get('x-proxy-token') !== token) {
      return new Response('unauthorized', {
        status: 401,
        headers: { 'content-type': 'text/plain; charset=utf-8' },
      });
    }

    // ---------- 构造上游 URL：只换 origin，路径与 query 原样保留 ----------
    const targetUrl = buildTargetUrl(request.url, upstream);

    const isWebSocket =
      (request.headers.get('upgrade') ?? '').toLowerCase() === 'websocket';

    const outbound = buildForwardRequest(request, targetUrl, isWebSocket, env);

    let response;
    try {
      response = await fetch(outbound);
    } catch (error) {
      // 上游不可达 / TLS 失败等，给客户端一个可辨识的响应而不是 500 空体
      return new Response(
        `proxy error: ${error && error.message ? error.message : String(error)}`,
        {
          status: 502,
          headers: { 'content-type': 'text/plain; charset=utf-8' },
        },
      );
    }

    // ---------- WebSocket 握手：必须原样返回，重建 Response 会断掉套接字 ----------
    if (response.status === 101 || response.webSocket) {
      return response;
    }

    // ---------- 普通响应：按需改写 Location / Set-Cookie ----------
    if ((env.REWRITE_REDIRECT ?? 'true') !== 'false') {
      const headers = new Headers(response.headers);

      const location = headers.get('location');
      if (location && location.startsWith(upstream.origin)) {
        headers.set(
          'location',
          incomingUrl.origin + location.slice(upstream.origin.length),
        );
      }

      // 注意：这里无需处理 `content-length`。Worker 直接透传 response.body
      // 流，运行时按 chunked 输出，长度不一致不会出错。

      // 把 Set-Cookie 的 Domain 属性去掉，否则浏览器会因域名不匹配丢弃。
      // Flutter 客户端不走 cookie，这里只是让 Web 端也能用。
      const cookies = getSetCookies(response.headers);
      if (cookies.length > 0) {
        headers.delete('set-cookie');
        for (const cookie of cookies) {
          headers.append('set-cookie', cookie.replace(/;\s*domain=[^;]*/gi, ''));
        }
      }

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers,
      });
    }

    return response;
  },
};

/**
 * 构造转发请求。
 *
 * 两条分支是刻意的：
 *  - WebSocket 与带 body 的请求走 `new Request(url, request)` 纯克隆。
 *    这样 Upgrade / Connection 头以及 ReadableStream body 由运行时原样搬运，
 *    不会因为手工重建 Headers 而丢掉（Upgrade 属于 forbidden header，手工 set 会被忽略）。
 *  - GET / HEAD 没有 body 也没有 upgrade，重建 Headers 来清洗边缘注入头最干净。
 *
 * @param {Request} request
 * @param {URL} targetUrl
 * @param {boolean} isWebSocket
 * @param {Record<string, string>} env
 */
function buildForwardRequest(request, targetUrl, isWebSocket, env) {
  const hasBody = !['GET', 'HEAD'].includes(request.method);
  const forceOrigin = (env.FORCE_ORIGIN ?? '').trim();

  if (isWebSocket || hasBody) {
    const cloned = new Request(targetUrl.toString(), request);
    applyForcedOrigin(cloned.headers, forceOrigin);
    return cloned;
  }

  const headers = new Headers(request.headers);
  for (const name of STRIP_REQUEST_HEADERS) {
    headers.delete(name);
  }
  applyForcedOrigin(headers, forceOrigin);

  return new Request(targetUrl.toString(), {
    method: request.method,
    headers,
    redirect: 'manual',
  });
}

/**
 * 改写 Origin 头。
 * `Origin` 在 fetch 规范里是 forbidden header，某些运行时下 set 会抛
 * TypeError，所以这里吞掉异常 —— 失败也不影响主流程。
 *
 * @param {Headers} headers
 * @param {string} origin
 */
function applyForcedOrigin(headers, origin) {
  if (!origin) return;
  try {
    headers.set('origin', origin);
  } catch {
    // 运行时不允许改写，忽略
  }
}

/**
 * 由入站 URL 派生上游 URL：保留 path / query，仅替换 origin。
 *
 * 坑点：**不要用 `url.host = upstream.host`**。
 * workerd 的 URL 实现里 host setter 不会清掉已有端口，
 * 于是 `https://127.0.0.1:8787/auth/v1/health` 会变成
 * `https://jtvxrwybwvgpqobyhaoy.supabase.co:8787/auth/v1/health`，
 * 打到被 Cloudflare 黑洞的非标准端口上，表现为 fetch 挂死 150s 后超时。
 * 必须分别设置 hostname 与 port。
 *
 * @param {string} requestUrl
 * @param {URL} upstream
 * @returns {URL}
 */
function buildTargetUrl(requestUrl, upstream) {
  const target = new URL(requestUrl);
  target.protocol = upstream.protocol;
  target.hostname = upstream.hostname;
  target.port = upstream.port;
  return target;
}

/**
 * 归一化上游地址，容忍 env 里多写的斜杠与路径。
 *
 * @param {string | undefined} value
 * @returns {URL}
 */
function parseUpstream(value) {
  const raw = (value ?? '').trim() || DEFAULT_UPSTREAM;
  const url = new URL(raw);
  // 上游必须是 https，否则 Worker 出网会被拒
  if (url.protocol !== 'https:') {
    url.protocol = 'https:';
  }
  // 清掉可能误填的路径，代理只做 origin 级替换
  url.pathname = '';
  url.search = '';
  url.hash = '';
  return url;
}

/**
 * 兼容读取 Set-Cookie。Workers 支持 getSetCookie()，
 * 老运行时退化到 get()。
 *
 * @param {Headers} headers
 * @returns {string[]}
 */
function getSetCookies(headers) {
  if (typeof headers.getSetCookie === 'function') {
    return headers.getSetCookie();
  }
  const single = headers.get('set-cookie');
  return single ? [single] : [];
}
