# Google Drive sync — one-time setup (~5 minutes)

Quantum Habits syncs through a **private, hidden app folder in your own
Google Drive**. There are no third-party servers: each device talks straight
to Google using an OAuth client that *you* own. You create that client once,
then paste the same ID + secret into the app on every device.

## 1. Create the OAuth client (once, in any browser)

1. Go to <https://console.cloud.google.com/> and sign in with the Google
   account you want to sync with.
2. Create a project (top bar → project picker → **New project** → name it
   `Quantum Habits` → **Create**).
3. Enable the Drive API: **APIs & Services → Library → Google Drive API →
   Enable**.
4. Configure the consent screen: **APIs & Services → OAuth consent screen** →
   External → fill in just the app name (`Quantum Habits`) and your email →
   save through the remaining steps.
   - Under **Audience → Test users**, add your own Gmail address.
5. Create the client: **APIs & Services → Credentials → Create credentials →
   OAuth client ID** → Application type **Desktop app** → **Create**.
6. Copy the **Client ID** (`…apps.googleusercontent.com`) and the
   **Client secret** (`GOCSPX-…`).

> The "secret" of a desktop OAuth client is not actually confidential —
> Google's own docs say installed apps cannot keep secrets. It only lets an
> app *ask* for access; your data is still protected by your Google login.

## 2. Connect each device

1. Open Quantum Habits → Home → cloud icon.
2. Paste the Client ID and Client secret → **Connect Google Drive**.
3. Your browser opens; pick the same Google account everywhere and approve.
4. Done. The app now syncs on its own:
   - every change you make is pushed a few seconds after you make it,
   - changes from your other devices land within ~40 seconds
     (immediately when you re-open the app),
   - offline edits queue up and sync when you're back online.

## How it stays safe

- Data lives in Drive's `appDataFolder` — invisible in your Drive UI,
  accessible only to this app, counted against your own storage.
- Sync merges **per record**: two devices edited offline interleave instead
  of one overwriting the other. Deletes propagate as tombstones and can never
  "resurrect".
- Journal entries stay end-to-end encrypted (AES-256-GCM) — Drive only ever
  stores their ciphertext. A burned entry is cryptographically destroyed on
  every device.

## Troubleshooting

- **"Google did not return a refresh token"** — remove the app's access at
  <https://myaccount.google.com/permissions> and connect again.
- **"access_denied" during consent** — your Gmail isn't in the OAuth client's
  test users (step 1.4), or you picked a different account.
- **Sync says offline but you're online** — a firewall may be blocking
  `googleapis.com`.
- **Disconnect** never deletes data: it only stops this device from syncing.
