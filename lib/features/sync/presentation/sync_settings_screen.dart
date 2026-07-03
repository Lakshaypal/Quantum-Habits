import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/neo_block.dart';
import '../../habits/application/habit_providers.dart' show databaseProvider;
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
        _field(_clientId, 'OAuth client ID',
            hint: 'xxxx.apps.googleusercontent.com'),
        const SizedBox(height: Insets.md),
        _field(_clientSecret, 'OAuth client secret',
            hint: 'GOCSPX-…', obscure: true),
        const SizedBox(height: Insets.lg),
        NeoBlock(
          color: AppColors.electricBlue,
          foreground: Colors.white,
          onTap: _busy
              ? null
              : () => _run(() async {
                    if (_clientId.text.trim().isEmpty ||
                        _clientSecret.text.trim().isEmpty) {
                      throw Exception(
                          'Paste your OAuth client ID and secret first — '
                          'docs/GOOGLE_DRIVE.md is the 5-minute walkthrough.');
                    }
                    await engine.connect(
                        _clientId.text, _clientSecret.text);
                  }),
          child: const Center(child: Text('Connect Google Drive')),
        ),
        const SizedBox(height: Insets.md),
        Text(
          'One-time setup: create a free "Desktop app" OAuth client in Google '
          'Cloud Console and paste it above — the full walkthrough lives in '
          'docs/GOOGLE_DRIVE.md. The same client ID works on all your devices.',
          style: t.bodySmall,
        ),
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
