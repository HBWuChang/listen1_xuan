import { accessToken, buildMessage, failure, parseServiceAccount } from './fcm.ts';
import type { Delivery, Fetcher, ServiceAccount } from './fcm.ts';

type Job = { id: number; lease_token: string };
type Dependencies = { env: (key: string) => string | undefined; fetch: Fetcher };
const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

export function createHandler(deps: Dependencies) {
  let cached: { token: string; expires: number; account: string } | undefined;
  async function rpc<T = unknown>(name: string, params: unknown): Promise<T> {
    const url = deps.env('SUPABASE_URL');
    const key = deps.env('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !key) throw new Error('SERVER_CONFIG_MISSING');
    const response = await deps.fetch(`${url}/rest/v1/rpc/${name}`, {
      method: 'POST', signal: AbortSignal.timeout(10000),
      headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(params),
    });
    if (!response.ok) throw new Error('PUSH_RPC_FAILED');
    const body = await response.text();
    return body ? JSON.parse(body) : null;
  }
  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') return reply(405, { error: 'METHOD_NOT_ALLOWED' });
    const secret = request.headers.get('x-feedback-push-secret');
    if (!secret || secret.length !== 64) return reply(401, { error: 'UNAUTHORIZED' });
    try {
      if (await rpc<boolean>('feedback_push_authorized', { p_secret: secret }) !== true) return reply(401, { error: 'UNAUTHORIZED' });
      const raw = deps.env('FCM_SERVICE_ACCOUNT_JSON');
      // Do not claim or consume retries while deployment credentials are missing.
      if (!raw) return reply(503, { error: 'FCM_NOT_CONFIGURED' });
      let account: ServiceAccount;
      try { account = parseServiceAccount(raw); } catch { return reply(503, { error: 'FCM_CONFIG_INVALID' }); }
      if (!cached || cached.expires < Date.now() || cached.account !== account.client_email) {
        cached = { ...await accessToken(account, deps.fetch), account: account.client_email };
      }
      const oauthToken = cached.token;
      const jobs = await rpc<Job[]>('feedback_claim_push_jobs', { p_limit: 20 });
      let sent = 0, cancelled = 0, failed = 0;
      async function complete(job: Job, status: string, error: string | null = null, invalidToken: string | null = null) {
        await rpc('feedback_complete_push_job', { p_job: job.id, p_lease: job.lease_token,
          p_status: status, p_error: error, p_invalid_token: invalidToken });
      }
      async function process(job: Job) {
        try {
          const delivery = await rpc<Delivery | null>('feedback_push_delivery', { p_job: job.id, p_lease: job.lease_token });
          if (!delivery) { await complete(job, 'cancelled'); cancelled++; return; }
          if (delivery.project_id !== account.project_id) { await complete(job, 'failed', 'FCM_PROJECT_MISMATCH'); failed++; return; }
          const response = await deps.fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
            method: 'POST', signal: AbortSignal.timeout(10000),
            headers: { Authorization: `Bearer ${oauthToken}`, 'Content-Type': 'application/json' },
            body: JSON.stringify(buildMessage(delivery)),
          });
          if (response.ok) { await complete(job, 'sent'); sent++; return; }
          let body: unknown = null;
          try { body = await response.json(); } catch { /* Never log provider payloads or device tokens. */ }
          const result = failure(response.status, body);
          if (response.status === 401) cached = undefined;
          await complete(job, result.retry ? 'retry' : 'failed', result.code, result.invalidToken ? delivery.token : null);
          failed++;
        } catch {
          failed++;
          // If acknowledgement also fails, the five-minute lease recovers it.
          try { await complete(job, 'retry', 'DELIVERY_TEMPORARY_FAILURE'); } catch { /* lease recovery */ }
        }
      }
      // Bound concurrent network operations and stay below Edge Function limits.
      for (let offset = 0; offset < jobs.length; offset += 4) await Promise.all(jobs.slice(offset, offset + 4).map(process));
      return reply(200, { processed: jobs.length, sent, cancelled, failed });
    } catch {
      return reply(503, { error: 'PUSH_DISPATCH_TEMPORARY_FAILURE' });
    }
  };
}
