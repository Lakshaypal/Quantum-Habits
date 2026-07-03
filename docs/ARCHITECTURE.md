# Quantum Habits — Architecture

> "Small actions compounded daily create extraordinary outcomes."
> A private laboratory for self-improvement. The contribution heatmap is always the hero.

## 1. Platforms & stack

| Concern | Choice | Why |
|---|---|---|
| Framework | **Flutter** (single codebase) | Native macOS `.app` + Android `.apk`, identical design language & feature parity |
| State | **Riverpod** | Compile-safe DI, testable, async-first |
| Local store | **SQLite via `drift`** + `drift_flutter` | Type-safe, offline-first, runs on macOS + Android |
| Sync (Phase 2+) | **Supabase** (Postgres + Auth + Realtime) | E2E-encrypted blobs, conflict resolution |
| Auth | Email · Google · Apple | Supabase GoTrue |
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

## 4. Sync & conflict resolution (Phase 2+)

- Every row carries `updatedAt` + `deviceId`; per-row **last-writer-wins** with a tombstone table
  for deletes. Journals & sensitive fields are stored as **AES-256-GCM ciphertext** — Supabase
  never sees plaintext (E2E). Key derived from the user passphrase (Argon2id) + device keychain.
- Outbox pattern: local writes enqueue a sync op; a background worker flushes on reconnect.
- **Sunday Journal Burn** = cryptographic destruction: delete the row locally *and* server-side and
  drop/rotate its data key so the ciphertext is unrecoverable. Irreversible by design.

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
