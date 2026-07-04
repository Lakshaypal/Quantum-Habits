# Shipping a release (macOS + Windows + Android)

The app is standalone and self-updating. Split-repo layout:

- **`Lakshaypal/quantum-habits`** (PRIVATE) — the source code + CI.
- **`Lakshaypal/quantum-habits-releases`** (PUBLIC, binaries only) — hosts
  the GitHub Releases. Every installed copy polls it (see `kUpdateRepo` in
  `lib/features/updates/update_service.dart`), shows an in-app banner when a
  newer version exists, and installs it in place.

## One-time setup (already done on this machine)

1. Private code repo pushed; public releases repo created.
2. `RELEASE_TOKEN` secret on the private repo: any GitHub token that can
   write releases to the public repo. If CI ever fails with 401/403, mint a
   fine-grained PAT (Contents: read/write on quantum-habits-releases) and
   re-run `gh secret set RELEASE_TOKEN --repo Lakshaypal/quantum-habits`.

## Every release

1. Bump `version:` in `pubspec.yaml` (e.g. `2.1.0+3`) **and** `kAppVersion`
   in `lib/core/app_version.dart` (the updater compares against it).
2. Commit, tag, push:
   ```bash
   git commit -am "v2.1.0"
   git tag v2.1.0
   git push && git push --tags
   ```
3. GitHub Actions builds and publishes to the public releases repo:
   - `QuantumHabits-macos.zip`
   - `QuantumHabits-windows.zip`  ← the only way to get Windows builds
     (Flutter Windows apps can't be built from a Mac)
   - `QuantumHabits-android.apk`
4. Every installed app notices within ~12h of its next launch (or
   immediately via Home → cloud icon → Check for updates), shows the
   "Version X is ready" banner, and updates itself in place.

Notes:
- Builds are unsigned. macOS users may need right-click → Open the first
  time; Android needs "install unknown apps" approved once.
- `--no-tree-shake-icons` is required (habit icons are chosen dynamically).
- Windows local builds: install Flutter on a Windows machine and run
  `flutter build windows --release` — the `windows/` platform folder is
  already committed.
