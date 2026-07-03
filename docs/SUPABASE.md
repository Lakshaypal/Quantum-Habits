# Quantum Habits — Cloud Sync setup (Supabase)

Sync is **end-to-end encrypted**: your data is sealed with AES-256-GCM using a key
derived from your *sync passphrase* (PBKDF2) before it ever leaves the device.
Supabase only stores opaque ciphertext + a non-secret salt — it can never read
your habits, challenges, or journals.

## 1. Create a free Supabase project
1. Go to https://supabase.com → **New project** (free tier is plenty).
2. After it provisions, open **Project Settings → API** and copy:
   - **Project URL** (e.g. `https://abcd1234.supabase.co`)
   - **anon public** key (the long `eyJ...` string — safe to share/embed)
3. **Authentication → Providers → Email**: for easy testing, turn **off**
   "Confirm email" so sign-up logs you in immediately.

## 2. Create the vault table
Open **SQL Editor** and run:

```sql
create table public.vault (
  user_id    uuid        primary key references auth.users on delete cascade,
  payload    jsonb       not null,   -- AES-256-GCM ciphertext {n, c, m}
  salt       text        not null,   -- PBKDF2 salt (not secret)
  updated_at timestamptz not null,
  device_id  text        not null
);

alter table public.vault enable row level security;

create policy "own vault"
  on public.vault for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

Row-Level Security guarantees each user can only ever touch their own row.

## 3. Connect in the app
1. **Home → cloud icon → Cloud Sync**.
2. Paste your **Project URL** + **anon key**, tap **Save & connect**.
3. **Sign up / sign in** with an email + password (your password is sent only to
   your own Supabase project).
4. Set a **sync passphrase** (this is the E2E key — use the same one on every
   device; if you lose it, the data is unrecoverable by design).
5. Tap **Sync now**. Install on a second device, sign in with the same account +
   sync passphrase, and your full system appears.

## Model
- Whole-vault snapshot with **last-sync-wins** resolution (simple and robust for
  a single user across devices; per-row merge can come later).
- Fully **offline-first** — the app never blocks on the network; sync is additive.
