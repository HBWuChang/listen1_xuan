export type ServiceAccount = { project_id: string; client_email: string; private_key: string };
export type Delivery = { token: string; project_id: string; user_id: string; issue_id: string; message_id: number | string; title: string };
export type Fetcher = typeof fetch;

export function parseServiceAccount(raw: string): ServiceAccount {
  const account = JSON.parse(raw);
  if (!/^[a-z0-9][a-z0-9-]{3,62}$/.test(account.project_id ?? '') ||
      typeof account.client_email !== 'string' || !account.client_email.includes('@') ||
      typeof account.private_key !== 'string' || !account.private_key.includes('BEGIN PRIVATE KEY')) {
    throw new Error('FCM_CONFIG_INVALID');
  }
  return account;
}

function base64url(value: Uint8Array): string {
  return btoa(String.fromCharCode(...value)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

export async function accessToken(account: ServiceAccount, fetcher: Fetcher): Promise<{ token: string; expires: number }> {
  const now = Math.floor(Date.now() / 1000);
  const encoder = new TextEncoder();
  const header = base64url(encoder.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = base64url(encoder.encode(JSON.stringify({
    iss: account.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  })));
  const pem = account.private_key.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), c => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const input = `${header}.${claims}`;
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(input));
  const response = await fetcher('https://oauth2.googleapis.com/token', {
    method: 'POST', signal: AbortSignal.timeout(10000),
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${input}.${base64url(new Uint8Array(signature))}` }),
  });
  if (!response.ok) throw new Error('FCM_OAUTH_FAILED');
  const data = await response.json();
  if (typeof data.access_token !== 'string') throw new Error('FCM_OAUTH_FAILED');
  return { token: data.access_token, expires: Date.now() + Math.min(Number(data.expires_in) || 3600, 3600) * 1000 - 60000 };
}

export function buildMessage(delivery: Delivery) {
  return { message: {
    token: delivery.token,
    notification: { title: delivery.title, body: '你关注的问题有新消息，点击查看' },
    data: { kind: 'feedback_message', issue_id: delivery.issue_id, user_id: delivery.user_id, message_id: String(delivery.message_id) },
    android: { priority: 'high', ttl: '3600s', notification: {
      channel_id: 'feedback_messages', tag: `feedback:${delivery.issue_id}`,
      icon: 'ic_feedback_notification', default_sound: true,
    } },
  } };
}

export function failure(responseStatus: number, body: unknown) {
  const data = body as { error?: { details?: Array<{ errorCode?: string }> } };
  const code = data?.error?.details?.map(d => d.errorCode).find(c => c && /^[A-Z_]+$/.test(c)) ?? `FCM_HTTP_${responseStatus}`;
  return { code, invalidToken: code === 'UNREGISTERED', retry: responseStatus === 429 || responseStatus >= 500 || responseStatus === 401 || responseStatus === 403 };
}
