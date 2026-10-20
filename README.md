# Quantum Habits

An offline-first Flutter application for habit tracking, daily planning and reflection. It combines a contribution-style habit heatmap, tasks, focus sessions, analytics and encrypted journaling, with optional Google Drive synchronisation.

## Features

- Habit schedules, daily check-ins and a contribution heatmap.
- Task planning and a focus timer.
- Journal entries protected by a passphrase-based encryption flow and optional device authentication.
- Local SQLite persistence through Drift and Riverpod state management.
- Optional Google Drive app-data sync with per-record conflict merging.
- Desktop tray integration, Android widget support and a GitHub-release update checker.

Platform support varies by feature. The repository contains Android, macOS, Windows and iOS project scaffolding; published downloads are maintained separately in [quantum-habits-releases](https://github.com/Lakshaypal/quantum-habits-releases/releases).

## Development

Install Flutter with Dart compatible with the `pubspec.yaml` constraint (Dart 3.12.2 or newer within the supported major version):

```sh
git clone https://github.com/Lakshaypal/quantum-habits.git
cd quantum-habits
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run -d macos
```

Use the appropriate device ID for Android or another supported target. Native features need the corresponding platform tools and permissions.

## Optional Drive sync

The app works locally without Google sign-in. Drive sync uses the installed-app OAuth flow and each user's own `appDataFolder`; account access still requires that user's consent. For your own distribution, configure your own OAuth project/client and review the setup in [docs/GOOGLE_DRIVE.md](docs/GOOGLE_DRIVE.md).

Do not commit user tokens, local databases, exported journals or private signing material. The included installed-app OAuth client configuration is not a user's access or refresh token. See [Google's installed-app OAuth documentation](https://developers.google.com/identity/protocols/oauth2/native-app).

## Structure

```text
lib/core/                  Persistence, theme, notifications and shared widgets
lib/features/habits/       Habits and schedules
lib/features/heatmap/      Daily activity views
lib/features/tasks/        Task planning
lib/features/focus/        Focus timer
lib/features/journal/      Journal UI and encryption
lib/features/sync/         Drive authorisation, vault encoding and merging
lib/features/updates/      Release checks
lib/features/analytics/    Progress views
android/ macos/ windows/   Native integrations
test/                     Automated tests
```

[Architecture notes](docs/ARCHITECTURE.md) also contain roadmap/design material; they should not be read as a guarantee that every planned feature is implemented. [Release instructions](docs/RELEASING.md) describe packaging and the separate download feed.
