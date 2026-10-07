import assert from 'node:assert/strict';
import { test } from 'node:test';

// Real handler, with network and Deno replaced by deterministic test doubles.
// No production token, secret or Supabase user is used.
const env = new Map([
  ['SUPABASE_URL', 'https://project.test'], ['SUPABASE_ANON_KEY', 'test-anon'],
  ['QF_PRODUCTION_CLIENT_ID', 'test-client'], ['QF_PRODUCTION_CLIENT_SECRET', 'test-secret'],
]);
let handler;
let oauthCalls = 0;
let upstreamCalls = 0;
let upstreamStatus = 200;
let lastURL;
globalThis.Deno = { env: { get: name => env.get(name) }, serve: value => { handler = value; } };
globalThis.fetch = async (input, options) => {
  const url = String(input);
  if (url.endsWith('/auth/v1/user')) {
    return Response.json(options.headers.Authorization === 'Bearer valid-user' ? { id: 'user' } : { error: 'invalid' }, { status: options.headers.Authorization === 'Bearer valid-user' ? 200 : 401 });
  }
  if (url.includes('/oauth2/token')) {
    oauthCalls++;
    assert.equal(options.body, 'grant_type=client_credentials&scope=content');
    return Response.json({ access_token: 'private-test-token', expires_in: 3600 });
  }
  assert.ok(url.startsWith('https://apis.quran.foundation/content/api/v4/'));
  assert.equal(options.headers['x-auth-token'], 'private-test-token');
  upstreamCalls++; lastURL = new URL(url);
  return Response.json(upstreamStatus === 200 ? { verses: [], pagination: { next_page: null } } : { privateDetail: 'must-not-leak' }, { status: upstreamStatus });
};
await import('./index.ts');
const invoke = (body, authorization = 'Bearer valid-user') => handler(new Request('https://project.test/functions/v1/quran-foundation', {
  method: 'POST', headers: authorization ? { Authorization: authorization } : {}, body: JSON.stringify(body),
}));

test('missing and invalid sessions never call Foundation', async () => {
  assert.equal((await invoke({ path: 'verses/by_page/42' }, null)).status, 401);
  assert.equal((await invoke({ path: 'verses/by_page/42' }, 'Bearer invalid')).status, 401);
  assert.equal(upstreamCalls, 0);
});
test('rejects arbitrary URLs, traversal, invalid pages and other Mushafs', async () => {
  for (const path of ['https://evil.test', '../admin', 'verses/by_page/0', 'verses/by_page/605', 'resources/snapshots/mushafs/1']) {
    assert.equal((await invoke({ path })).status, 400, path);
  }
  assert.equal(upstreamCalls, 0);
});
test('valid pages use Mushaf 19, bounded pagination and cached OAuth token', async () => {
  for (const page of [1, 42, 604]) {
    const response = await invoke({ path: `verses/by_page/${page}`, query: { mushaf: '1', per_page: '1000' } });
    assert.equal(response.status, 200);
    assert.equal(lastURL.searchParams.get('mushaf'), '19');
    assert.equal(lastURL.searchParams.get('per_page'), '50');
    assert.ok(!(await response.text()).includes('private-test-token'));
  }
  assert.equal(oauthCalls, 1);
});
test('Content Sync always restricts resource selection to Mushaf 19', async () => {
  assert.equal((await invoke({ path: 'resources/sync', query: { bootstrap: 'true', resources: 'mushafs:1' } })).status, 200);
  assert.equal(lastURL.searchParams.get('resources'), 'mushafs:19');
});
test('upstream errors omit private bodies and preserve retryable 429', async () => {
  upstreamStatus = 429;
  const response = await invoke({ path: 'verses/by_page/42' });
  assert.equal(response.status, 429);
  assert.deepEqual(await response.json(), { error: 'foundation_unavailable', upstreamStatus: 429 });
  upstreamStatus = 200;
});
test('401 renews only once', async () => {
  upstreamStatus = 401;
  const previous = upstreamCalls;
  assert.equal((await invoke({ path: 'verses/by_page/42' })).status, 502);
  assert.equal(upstreamCalls - previous, 2);
  assert.equal(oauthCalls, 2);
});
