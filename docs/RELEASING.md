# Shipping a release (macOS + Windows + Android)

The app is standalone and self-updating: every installed copy checks the
GitHub Releases of `lakshayfeb/quantum-habits` (see `kUpdateRepo` in
`lib/features/updates/update_service.dart`) and offers "Download & install"
in-app when a newer version exists.

## One-time setup

1. Create the GitHub repo and push:
   ```bash
   cd "~/Desktop/Personal OS"
   gh repo create lakshayfeb/quantum-habits --private --source=. --push
   ```
   (Private repos work for CI, but the in-app updater downloads release
   assets anonymously — make the repo **public**, or at least its releases.)
2. That's it — no tokens or secrets needed. The workflow only uses the
   built-in `GITHUB_TOKEN`.

## Every release

1. Bump `version:` in `pubspec.yaml` (e.g. `2.1.0+3`) **and** `kAppVersion`
   in `lib/core/app_version.dart` (the updater compares against it).
2. Commit, tag, push:
   ```bash
   git commit -am "v2.1.0"
   git tag v2.1.0
   git push && git push --tags
   ```
3. GitHub Actions builds and attaches:
   - `QuantumHabits-macos.zip`
   - `QuantumHabits-windows.zip`  ← the only way to get Windows builds
     (Flutter Windows apps can't be built from a Mac)
   - `QuantumHabits-android.apk`
4. Every device sees the update under Home → cloud icon → App updates.

Notes:
- Builds are unsigned. macOS users may need right-click → Open the first
  time; Android needs "install unknown apps" approved once.
- `--no-tree-shake-icons` is required (habit icons are chosen dynamically).
- Windows local builds: install Flutter on a Windows machine and run
  `flutter build windows --release` — the `windows/` platform folder is
  already committed.
