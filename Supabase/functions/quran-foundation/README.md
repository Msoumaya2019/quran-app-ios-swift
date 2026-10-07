# Quran Foundation — native app backend

Deploy this function as `quran-foundation` in the existing Supabase project.
Keep JWT verification enabled. The function also verifies the authenticated
Supabase user through `/auth/v1/user`; an anonymous key alone is insufficient.

Configure these **Edge Function secrets**, never in Swift, GitHub, or a plist:

- `QF_PRODUCTION_CLIENT_ID`: the Quran Foundation **production** Client ID.
- `QF_PRODUCTION_CLIENT_SECRET`: the corresponding production secret, entered securely
  by the account owner.

Supabase provides `SUPABASE_URL` and `SUPABASE_ANON_KEY` automatically.
No database migration or service-role key is required.

Requests are POST JSON with `path` and string-valued `query`. Allowed paths:

- `verses/by_page/1` through `verses/by_page/604` (Mushaf 19 forced).
- `resources/sync` (resource filter `mushafs:19` forced).
- `resources/snapshots/mushafs/19`.

Use bootstrap and the returned sync checkpoint according to the official
Content Sync documentation. Do not mark the offline installation complete
until the snapshot, fonts, page mappings and all 604 pages are validated.
The snapshot's actual schema must be checked against production before the
Swift snapshot importer is finalized.

OAuth client credentials and `scope=content` are used only server-side.
Tokens are cached until 60 seconds before expiry; a 401 causes one renewal.
Errors do not include private credentials or raw upstream bodies.

Deployed through the Supabase dashboard on 2026-10-08. Legacy JWT verification
remains enabled. Six local handler tests pass (mocked upstream calls).
The account owner updated the production secret; its changed digest and timestamp were verified in the dashboard without revealing its value. Authenticated production calls remain to be verified with an app user session.
The existing qcf-v4-page function was inspected and left unchanged.
