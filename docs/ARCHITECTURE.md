# Quantum Habits — Architecture

> "Small actions compounded daily create extraordinary outcomes."
> A private laboratory for self-improvement. The contribution heatmap is always the hero.

## 1. Platforms & stack

| Concern | Choice | Why |
|---|---|---|
| Framework | **Flutter** (single codebase) | Native macOS `.app` + Android `.apk`, identical design language & feature parity |
| State | **Riverpod** | Compile-safe DI, testable, async-first |
| Local store | **SQLite via `drift`** + `drift_flutter` | Type-safe, offline-first, runs on macOS + Android |
| Sync | **Google Drive appDataFolder** (user's own Drive, no third-party server) | Per-record LWW merge, auto-sync |
| Auth | Google OAuth 2.0 installed-app flow (loopback + PKCE) | One Desktop client works on macOS/Windows/Android |
| Crypto | **AES-256-GCM** (journals, synced blobs) | Encrypt before leaving device |
| Type | Inter (UI) · JetBrains Mono (numerics) | Linear-grade clarity; mono gives the "lab" feel |

Offline-first is the contract: **the app is fully usable with no network.** SQLite is the source of
truth on-device; the cloud is a sync target. Widgets read the local cache and refresh after sync.

## 2. Design language (dark-first)

Color tokens (`core/theme/app_colors.dart`):

| Token | Hex | Role |
|---|---|---|
| Deep Space Black | `#0A0B0D` | App background |
| Graphite | `#16181D` / `#1F232B` | Panels, raised surfaces |
| Frost White | `#F4F6FB` | Primary text |
| Muted | `#8A90A0` | Secondary text |
| Electric Blue | `#3B82F6` | Primary accent |
| Soft Purple | `#8B7CF6` | Secondary accent |
| Warm Amber | `#F4A340` | Tertiary / streak accent |

Heatmap palette ("Frost Blue", default; user-swappable):
`L0 #14161B · L1 #16324F · L2 #1E5694 · L3 #2D7FE0 · L4 #5BA8FF`

Surfaces: frosted glass (`BackdropFilter` blur 18–24, thin 1px `white@8%` border, radius 18–24,
soft shadow). Neobrutalist accent blocks: flat fill, hard 2px border, offset hard shadow — used
sparingly for emphasis (today's CTA, milestone markers). Motion: **< 250ms**, gentle spring,
nothing decorative. No bright/flashy color, no social/gamification dopamine loops.

Core widgets: `GlassCard`, `FrostedPanel`, `NeoBlock`, `SectionHeader`.

## 3. Data model (local, drift)

```
Habit        id, name, type{binary,count,time,goal}, colorValue, iconCodePoint,
             category?, targetValue?, unit?, createdAt, archived, sortOrder
HabitEntry   id, habitId→Habit, date(day), value, completed, note?, createdAt
Challenge    id, name, startDate, endDate, mode{strict,flexible}, ruleJson, createdAt   (Phase 2)
ChallengeHabit  challengeId, habitId, mandatory                                         (Phase 2)
JournalEntry id, kind, encryptedBody(blob), createdAt, burnedAt?                        (Phase 2)
PetState     id, stage, mood, lastFedAt, xp                                             (Phase 2)
Settings     key→value (theme, palette, recoveryDays, layout)                           (Phase 2)
```

**Daily intensity → heatmap level**: `completed habits / active habits` for the day, bucketed
into L0–L4 (0, <0.34, <0.67, <1.0, =1.0 perfect day). Count/time habits count as "completed" when
they meet their `targetValue`.

## 4. Sync & conflict resolution (v2 — SHIPPED)

- Backend: a single gzipped-JSON **vault file in the user's Google Drive `appDataFolder`**
  (`features/sync/drive_client.dart`). No servers of ours; each device holds an OAuth refresh
  token in the platform keychain. One-time setup per device: paste the OAuth client id/secret
  (docs/GOOGLE_DRIVE.md) and approve in the browser.
- Every synced row carries `updatedAtMs` + a tombstone. Merge (`vault_merge.dart`) is per-record
  **last-writer-wins**, deterministic (ties: tombstone wins, then canonical JSON), convergent in
  both directions, and canonicalizes logical duplicates (two devices logging the same habit+day
  offline collapse to one row). There is **no destructive replace path** — offline edits from two
  devices interleave. Unit-tested in test/vault_merge_test.dart.
- Engine (`sync_engine.dart`): debounced push ~3s after any local mutation, remote poll every ~40s
  while foregrounded, immediate sync on app resume, offline queuing with automatic retry.
  Day-keyed fields travel as `yyyy-MM-dd` strings so calendar days survive timezone changes.
- Journal entries remain **AES-256-GCM ciphertext inside the vault** (key from the journal
  passphrase; salt+verifier sync so the same passphrase unlocks everywhere). **Sunday Burn** zeroes
  the ciphertext AND tombstones the row, so destruction propagates to every device.
- In-app updates: `features/updates/update_service.dart` checks GitHub Releases
  (docs/RELEASING.md); CI builds macOS/Windows/Android artifacts on tag push.

## 5. Widgets

- **Android**: home-screen widgets (Heatmap, Streak, Daily Quote, Challenge Progress) via a
  Kotlin `AppWidgetProvider` backed by `home_widget`, reading the shared local cache.
- **macOS**: WidgetKit extension (Heatmap, Daily Quote, Active Challenge, Consistency Score) via an
  App Group shared container.
- Both render from the on-device cache and refresh post-sync — never block on network.

## 6. Module / folder layout (feature-first)

```
lib/
  main.dart · app.dart
  core/  theme/ · widgets/ · db/ · util/
  features/
    heatmap/   data · application · presentation
    habits/    data · application · presentation
    home/      presentation
    (phase 2) challenges/ streak/ pet/ journal/ quotes/ analytics/ settings/ sync/
```

## 7. Delivery roadmap

1. **Foundation (now)** — toolchain, scaffold, design system, offline SQLite, **hero heatmap**,
   home screen, habit CRUD, runs on macOS. ← *this iteration*
2. Quote-of-the-day data + widget · Streak engine + recovery days
3. Challenge system (strict/flexible, milestones, certificate) · Researcher's Dashboard mode
4. Encrypted journaling + Sunday Burn ritual · Quantum Pet
5. Analytics (weekly/monthly/annual review) · Customization + theme editor
6. Supabase auth + E2E sync + conflict resolution · Android & macOS widgets · packaging (.apk/.app)

> Build order is bottom-up: every layer runs and is verified before the next is added. Sync and
> encryption are layered on only once the local experience is solid.
