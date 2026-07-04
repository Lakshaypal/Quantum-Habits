import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/neo_block.dart';
import '../../habits/application/habit_providers.dart' show databaseProvider;
import '../../updates/update_prompt.dart';
import '../../updates/update_service.dart';
import '../application/oauth_defaults.dart';
import '../application/sync_engine.dart';

const _ok = Color(0xFF34D399);
const _warn = Color(0xFFFBBF24);
const _err = Color(0xFFE5484D);

/// Google Drive sync: connect once, then everything syncs on its own — every
/// edit pushes within seconds, other devices' changes pull automatically.
class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});
  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  bool _busy = false;
  String? _localError;
  bool _checkingUpdate = false;
  UpdateCheck? _updateCheck;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    ref.read(databaseProvider).getKV('gdrive_client_id').then((v) {
      if (mounted && v != null && _clientId.text.isEmpty) {
        setState(() => _clientId.text = v);
      }
    });
  }

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() =>
            _localError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final status = ref.watch(syncEngineProvider);
    final engine = ref.read(syncEngineProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Sync', style: t.titleLarge),
      ),
      body: AuroraBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xxl),
            children: [
              _StatusCard(status: status),
              const SizedBox(height: Insets.lg),
              if (!status.connected)
                ..._buildConnect(t, engine)
              else
                ..._buildConnected(t, status, engine),
              const SizedBox(height: Insets.xl),
              ..._buildUpdates(t),
              if (_localError != null) ...[
                const SizedBox(height: Insets.lg),
                Row(children: [
                  const Icon(Icons.error_outline, size: 16, color: _err),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                      child: Text(_localError!,
                          style: t.bodySmall?.copyWith(color: _err))),
                ]),
              ],
              if (_busy) ...[
                const SizedBox(height: Insets.lg),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connect(SyncEngine engine) => _run(() async {
        final customId = _clientId.text.trim();
        final customSecret = _clientSecret.text.trim();
        if (customId.isNotEmpty && customSecret.isNotEmpty) {
          await engine.connect(customId, customSecret);
        } else if (hasEmbeddedGoogleClient) {
          await engine.connect(
              kDefaultGoogleClientId, kDefaultGoogleClientSecret);
        } else {
          throw Exception(
              'This build has no embedded Google client yet — either fill '
              'the advanced fields below, or (as the developer) set it in '
              'lib/features/sync/application/oauth_defaults.dart. '
              'docs/GOOGLE_DRIVE.md walks through both.');
        }
      });

  List<Widget> _buildConnect(TextTheme t, SyncEngine engine) => [
        Text('GOOGLE DRIVE', style: t.labelSmall),
        const SizedBox(height: 6),
        Text(
          'Your data lives in a private app folder inside your own Google '
          'Drive — no third-party servers. Connect every device to the same '
          'Google account and they stay in step automatically.',
          style: t.bodySmall,
        ),
        const SizedBox(height: Insets.lg),
        // The whole flow for customers: one tap → Google consent → done.
        NeoBlock(
          color: AppColors.electricBlue,
          foreground: Colors.white,
          onTap: _busy ? null : () => _connect(engine),
          child: const Center(child: Text('Connect Google Drive')),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          'Your browser opens; pick your Google account and approve. That’s it.',
          style: t.bodySmall,
        ),
        const SizedBox(height: Insets.lg),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Row(
            children: [
              Text('ADVANCED — USE YOUR OWN GOOGLE CLIENT',
                  style: t.labelSmall),
              const SizedBox(width: Insets.sm),
              Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: AppColors.muted),
            ],
          ),
        ),
        if (_showAdvanced) ...[
          const SizedBox(height: Insets.md),
          _field(_clientId, 'OAuth client ID',
              hint: 'xxxx.apps.googleusercontent.com'),
          const SizedBox(height: Insets.md),
          _field(_clientSecret, 'OAuth client secret',
              hint: 'GOCSPX-…', obscure: true),
          const SizedBox(height: Insets.sm),
          Text(
            'Only for self-hosting your own OAuth client '
            '(docs/GOOGLE_DRIVE.md). Leave empty to use the app’s built-in one.',
            style: t.bodySmall,
          ),
        ],
      ];

  List<Widget> _buildConnected(
          TextTheme t, SyncStatus status, SyncEngine engine) =>
      [
        Text('AUTOMATIC SYNC', style: t.labelSmall),
        const SizedBox(height: Insets.sm),
        GlassCard(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg, vertical: Insets.sm),
          child: Row(children: [
            Expanded(
              child: Text(
                'Sync changes as they happen',
                style: t.bodyMedium,
              ),
            ),
            Switch(
              value: status.autoSync,
              onChanged: (v) => engine.setAutoSync(v),
            ),
          ]),
        ),
        const SizedBox(height: Insets.lg),
        NeoBlock(
          color: AppColors.electricBlue,
          foreground: Colors.white,
          onTap: _busy || status.phase == SyncPhase.syncing
              ? null
              : () => _run(() => engine.syncNow()),
          child: Center(
              child: Text(status.phase == SyncPhase.syncing
                  ? 'Syncing…'
                  : 'Sync now')),
        ),
        const SizedBox(height: Insets.md),
        GlassCard(
          onTap: _busy
              ? null
              : () => _run(() async {
                    final sure = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Disconnect Google Drive?'),
                        content: const Text(
                            'This device stops syncing. Nothing is deleted — '
                            'your data stays here, on Drive, and on your '
                            'other devices.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Disconnect')),
                        ],
                      ),
                    );
                    if (sure == true) await engine.disconnect();
                  }),
          padding: const EdgeInsets.all(Insets.md),
          child: Center(
              child: Text('Disconnect',
                  style: t.bodyMedium?.copyWith(color: AppColors.muted))),
        ),
      ];

  List<Widget> _buildUpdates(TextTheme t) {
    final check = _updateCheck;
    return [
      Text('APP UPDATES', style: t.labelSmall),
      const SizedBox(height: Insets.sm),
      GlassCard(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            switch (check) {
              null => Text(
                  'New versions install straight from the app — no store '
                  'needed.',
                  style: t.bodySmall),
              UpToDate(:final current) => Text(
                  'You’re on the latest version ($current).',
                  style: t.bodySmall?.copyWith(color: _ok)),
              UpdateCheckFailed(:final reason) =>
                Text(reason, style: t.bodySmall?.copyWith(color: _warn)),
              UpdateAvailable(:final current, :final update) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Version ${update.version} is out (you have $current).',
                        style: t.bodyMedium),
                    if (update.notes.trim().isNotEmpty) ...[
                      const SizedBox(height: Insets.sm),
                      Text(update.notes.trim(),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall),
                    ],
                  ],
                ),
            },
            const SizedBox(height: Insets.md),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _checkingUpdate
                      ? null
                      : () async {
                          setState(() => _checkingUpdate = true);
                          final result =
                              await ref.read(updateServiceProvider).check();
                          if (mounted) {
                            setState(() {
                              _updateCheck = result;
                              _checkingUpdate = false;
                            });
                          }
                        },
                  icon: _checkingUpdate
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text('Check for updates'),
                ),
                const Spacer(),
                if (check is UpdateAvailable)
                  NeoBlock(
                    color: AppColors.electricBlue,
                    foreground: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg, vertical: Insets.sm),
                    onTap: () => runUpdateFlow(context, ref, check.update),
                    child: const Text('Update now'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _field(TextEditingController c, String label,
          {String? hint, bool obscure = false}) =>
      TextField(
        controller: c,
        obscureText: obscure,
        autocorrect: false,
        decoration: InputDecoration(labelText: label, hintText: hint),
      );
}

class _StatusCard extends StatelessWidget {
  final SyncStatus status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (icon, color, headline) = switch (status.phase) {
      SyncPhase.disconnected => (
          Icons.cloud_off_outlined,
          AppColors.muted,
          'Not connected'
        ),
      SyncPhase.idle => (
          Icons.cloud_done_outlined,
          _ok,
          'Synced with ${status.email ?? 'Google Drive'}'
        ),
      SyncPhase.syncing => (
          Icons.cloud_sync_outlined,
          _ok,
          'Syncing…'
        ),
      SyncPhase.offline => (
          Icons.cloud_queue_outlined,
          _warn,
          'Offline — changes saved here, will sync when back'
        ),
      SyncPhase.error => (
          Icons.cloud_off_outlined,
          _err,
          'Sync hit a snag'
        ),
    };
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: Insets.md),
          Expanded(child: Text(headline, style: t.bodyMedium)),
        ]),
        if (status.lastSyncedAt != null) ...[
          const SizedBox(height: Insets.sm),
          Text('Last synced ${_ago(status.lastSyncedAt!)}',
              style: t.bodySmall),
        ],
        if (status.message != null) ...[
          const SizedBox(height: Insets.sm),
          Text(status.message!, style: t.bodySmall?.copyWith(color: color)),
        ],
      ]),
    );
  }

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
