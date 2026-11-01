import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { createHandler } from './worker.ts';
import { buildMessage } from './fcm.ts';

const keys = await webcrypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',hash:'SHA-256',modulusLength:2048,publicExponent:new Uint8Array([1,0,1])},true,['sign','verify']);
const pem = Buffer.from(await webcrypto.subtle.exportKey('pkcs8',keys.privateKey)).toString('base64');
const account = JSON.stringify({project_id:'listen1-xuan',client_email:'test@example.invalid',private_key:`-----BEGIN PRIVATE KEY-----\n${pem}\n-----END PRIVATE KEY-----`});
const secret = 'a'.repeat(64);
const delivery = {token:'device-token',project_id:'listen1-xuan',user_id:'recipient',issue_id:'issue',message_id:42,title:'Question'};
const json = (body,status=200) => new Response(JSON.stringify(body),{status});
function harness({authorized=true,configured=true,jobs=[{id:1,lease_token:'lease'}],delivered=delivery,fcmStatus=200,fcmBody={},rpcFailure=false}={}) {
  const calls=[], acknowledgements=[];
  const env={SUPABASE_URL:'https://project.supabase.co',SUPABASE_SERVICE_ROLE_KEY:'server-key',...(configured?{FCM_SERVICE_ACCOUNT_JSON:account}:{})};
  const handler=createHandler({env:n=>env[n],fetch:async (url,init)=>{
    calls.push(String(url));
    const body=init?.body instanceof URLSearchParams?Object.fromEntries(init.body):JSON.parse(init?.body??'{}');
    if(String(url).includes('oauth2.googleapis.com')) {
      const parts=body.assertion.split('.');
      const claims=JSON.parse(Buffer.from(parts[1],'base64url'));
      assert.equal(claims.scope,'https://www.googleapis.com/auth/firebase.messaging');
      assert.equal(claims.aud,'https://oauth2.googleapis.com/token');
      assert.equal(await webcrypto.subtle.verify('RSASSA-PKCS1-v1_5',keys.publicKey,Buffer.from(parts[2],'base64url'),Buffer.from(parts[0]+'.'+parts[1])),true);
      return json({access_token:'oauth-token',expires_in:3600});
    }
    if(String(url).includes('fcm.googleapis.com')) {
      assert.equal(body.message.data.message_id,'42');
      assert.equal(body.message.android.notification.tag,'feedback:issue');
      assert.equal(body.message.data.user_id,'recipient');
      assert.equal(JSON.stringify(body).includes('server-key'),false);
      return json(fcmBody,fcmStatus);
    }
    const name=String(url).split('/').at(-1);
    if(name==='feedback_push_authorized') return json(authorized);
    if(rpcFailure) return json({},503);
    if(name==='feedback_claim_push_jobs') return json(jobs);
    if(name==='feedback_push_delivery') return json(delivered);
    if(name==='feedback_complete_push_job') {acknowledgements.push(body);return json(null);}
    throw Error('unexpected mock endpoint');
  }});
  return {handler,calls,acknowledgements};
}
const request=()=>new Request('https://worker.invalid',{method:'POST',headers:{'x-feedback-push-secret':secret}});

test('unauthenticated requests cannot trigger privileged work',async()=>{
  const h=harness();
  assert.equal((await h.handler(new Request('https://worker.invalid',{method:'POST'}))).status,401);
  assert.equal(h.calls.length,0);
  const denied=harness({authorized:false});
  assert.equal((await denied.handler(request())).status,401);
  assert.equal(denied.calls.length,1);
});
test('missing Firebase configuration never consumes delivery attempts',async()=>{
  const h=harness({configured:false});
  assert.equal((await h.handler(request())).status,503);
  assert.equal(h.calls.some(c=>c.includes('claim')),false);
});
test('OAuth is signed and a successful FCM request is acknowledged',async()=>{
  const h=harness();
  const response=await h.handler(request());
  assert.equal(response.status,200);
  assert.deepEqual(await response.json(),{processed:1,sent:1,cancelled:0,failed:0});
  assert.equal(h.acknowledgements[0].p_status,'sent');
});
test('already read, muted or revoked deliveries never reach FCM',async()=>{
  const h=harness({delivered:null});
  await h.handler(request());
  assert.equal(h.calls.some(c=>c.includes('fcm.googleapis.com')),false);
  assert.equal(h.acknowledgements[0].p_status,'cancelled');
});
test('UNREGISTERED only revokes the specific token that failed',async()=>{
  const h=harness({fcmStatus:404,fcmBody:{error:{details:[{errorCode:'UNREGISTERED'}]}}});
  await h.handler(request());
  assert.equal(h.acknowledgements[0].p_status,'failed');
  assert.equal(h.acknowledgements[0].p_invalid_token,'device-token');
});
test('transient provider errors request a bounded database retry',async()=>{
  const h=harness({fcmStatus:503});
  await h.handler(request());
  assert.equal(h.acknowledgements[0].p_status,'retry');
  assert.equal(h.acknowledgements[0].p_invalid_token,null);
});
test('a token from another Firebase project is not sent',async()=>{
  const h=harness({delivered:{...delivery,project_id:'another-project'}});
  await h.handler(request());
  assert.equal(h.calls.some(c=>c.includes('fcm.googleapis.com')),false);
  assert.equal(h.acknowledgements[0].p_error,'FCM_PROJECT_MISMATCH');
});
test('provider failures never leak secrets in the HTTP response',async()=>{
  const h=harness({rpcFailure:true});
  const response=await h.handler(request());
  assert.equal(response.status,503);
  const body=await response.text();
  assert.equal(body.includes('server-key'),false);
  assert.equal(body.includes('PRIVATE KEY'),false);
});
