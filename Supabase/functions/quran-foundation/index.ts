// Server-only credentials. Deploy with JWT verification enabled.
// No credential or access token is ever returned to the iPhone.
let token: { value: string; expiresAt: number } | undefined;
let tokenRequest: Promise<string> | undefined;

async function accessToken(): Promise<string> {
  if (token && token.expiresAt > Date.now() + 60_000) return token.value;
  if (tokenRequest) return tokenRequest;
  tokenRequest = (async () => {
    const id = Deno.env.get("QF_PRODUCTION_CLIENT_ID");
    const secret = Deno.env.get("QF_PRODUCTION_CLIENT_SECRET");
    if (!id || !secret) throw new Error("Foundation credentials missing");
    const response = await fetch("https://oauth2.quran.foundation/oauth2/token", {
      method: "POST",
      headers: {
        Authorization: "Basic " + btoa(id + ":" + secret),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: "grant_type=client_credentials&scope=content",
      signal: AbortSignal.timeout(20_000),
    });
    if (!response.ok) throw new Error("Foundation authentication failed");
    const result = await response.json();
    if (typeof result.access_token !== "string" || typeof result.expires_in !== "number") {
      throw new Error("Invalid Foundation token response");
    }
    token = { value: result.access_token, expiresAt: Date.now() + result.expires_in * 1000 };
    return token.value;
  })();
  try { return await tokenRequest; } finally { tokenRequest = undefined; }
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { "Content-Type": "application/json", "Cache-Control": "private, no-store" },
});

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401);
    // Verify the existing Supabase user, even if the gateway configuration changes.
    const identity = await fetch(Deno.env.get("SUPABASE_URL") + "/auth/v1/user", {
      headers: { Authorization: authorization, apikey: Deno.env.get("SUPABASE_ANON_KEY") ?? "" },
      signal: AbortSignal.timeout(15_000),
    });
    if (!identity.ok) return json({ error: "unauthorized" }, 401);
    const user = await identity.json();
    if (!user.id) return json({ error: "unauthorized" }, 401);
    const input = await request.text();
    if (input.length > 8192) return json({ error: "invalid_request" }, 400);
    const { path, query = {} } = JSON.parse(input);
    // Fixed host and narrowly allowed read-only paths; no arbitrary URL proxy.
    const allowed = typeof path === "string" && (
      /^verses\/by_page\/([1-9]|[1-9]\d|[1-5]\d\d|60[0-4])$/.test(path) ||
      path === "resources/sync" || path === "resources/snapshots/mushafs/19"
    );
    if (!allowed || !query || Array.isArray(query) || typeof query !== "object") {
      return json({ error: "invalid_request" }, 400);
    }
    const url = new URL("https://apis.quran.foundation/content/api/v4/" + path);
    for (const [name, value] of Object.entries(query)) {
      if (typeof value !== "string" || value.length > 4096) return json({ error: "invalid_request" }, 400);
      url.searchParams.set(name, value);
    }
    if (path.startsWith("verses/")) {
      url.searchParams.set("mushaf", "19"); url.searchParams.set("words", "true");
      url.searchParams.set("word_fields", "code_v2"); url.searchParams.set("per_page", "50");
    } else if (path === "resources/sync") {
      url.searchParams.set("resources", "mushafs:19");
    }
    let response: Response | undefined;
    for (let attempt = 0; attempt < 2; attempt++) {
      response = await fetch(url, {
        headers: { "x-auth-token": await accessToken(), "x-client-id": Deno.env.get("QF_PRODUCTION_CLIENT_ID")! },
        signal: AbortSignal.timeout(60_000),
      });
      if (response.status !== 401 || attempt > 0) break;
      await response.body?.cancel(); token = undefined;
    }
    if (!response) throw new Error("No Foundation response");
    if (!response.ok) {
      await response.body?.cancel();
      return json({ error: "foundation_unavailable", upstreamStatus: response.status }, response.status === 429 ? 429 : 502);
    }
    return new Response(response.body, {
      headers: { "Content-Type": "application/json", "Cache-Control": "private, no-store" },
    });
  } catch {
    // Do not log secrets, user bearer tokens, or Foundation response bodies.
    return json({ error: "foundation_unavailable" }, 503);
  }
});
