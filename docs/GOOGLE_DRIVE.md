# Google Drive sync

Quantum Habits syncs through a **private, hidden app folder in each user's
own Google Drive**. No third-party servers: every device talks straight to
Google.

## What customers experience

Home → cloud icon → **Connect Google Drive** → browser opens → pick account
→ approve → done. From then on the app syncs on its own: every change pushes
a few seconds after it's made, other devices pick it up within ~40 seconds
(immediately on app open), offline edits queue and flush automatically.

That one-tap flow works because the product ships with an embedded OAuth
client — set up ONCE by you, the developer:

## Developer setup (once per product, ~10 minutes)

1. Go to <https://console.cloud.google.com/>, create a project
   (`Quantum Habits`).
2. Enable the Drive API: **APIs & Services → Library → Google Drive API →
   Enable**.
3. **OAuth consent screen** → External → app name + your email → save.
   - Then **PUBLISH the app to production** (Audience → "Publish app").
     ⚠️ This step is critical: while the consent screen sits in "Testing",
     Google expires refresh tokens after **7 days** — customers would be
     silently disconnected every week. In production they stay connected
     indefinitely.
   - Until Google verifies the app, users see an "unverified app" warning
     with a Continue link, and there's a 100-user cap. Submitting for
     verification (free) removes both; the `drive.appdata` scope is
     "sensitive", so verification is a questionnaire, not a security audit.
4. **Credentials → Create credentials → OAuth client ID → Desktop app**.
5. Paste the client ID + secret into
   `lib/features/sync/application/oauth_defaults.dart` and build/release.

> Desktop-app client secrets are explicitly **non-confidential** in Google's
> OAuth model — embedding them in a shipped binary is the standard pattern
> for installed apps. The secret can't read anyone's Drive; access is always
> gated by each user's own Google login + consent, and the `drive.appdata`
> scope can only touch this app's own hidden folder.

## Power users / self-hosters

The connect screen has an **Advanced** section where anyone can paste their
own OAuth client instead of the embedded one (same steps as above).

## How it stays safe

- Data lives in Drive's `appDataFolder` — invisible in the Drive UI,
  reachable only by this app, counted against the user's own storage.
- Sync merges **per record**: offline edits from two devices interleave;
  deletes propagate as tombstones and never resurrect.
- Journal entries stay end-to-end encrypted (AES-256-GCM) — Drive only ever
  stores ciphertext; a burned entry is destroyed on every device.

## Troubleshooting

- **"Google did not return a refresh token"** — remove the app's access at
  <https://myaccount.google.com/permissions> and connect again.
- **Disconnected after ~a week** — the consent screen is still in Testing
  mode; publish it to production (step 3).
- **"access_denied"** — the user cancelled consent, or (in Testing mode)
  isn't listed as a test user.
- **Disconnect** never deletes data; it only stops that device syncing.
