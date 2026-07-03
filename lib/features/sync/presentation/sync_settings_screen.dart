import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/neo_block.dart';
import '../application/sync_service.dart';

const _ok = Color(0xFF34D399);
const _err = Color(0xFFE5484D);

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});
  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  final _url = TextEditingController();
  final _anon = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passphrase = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _msgIsError = false;

  @override
  void initState() {
    super.initState();
    _passphrase.text = ref.read(syncPassphraseProvider) ?? '';
    // Try to bring up Supabase from any saved config.
    ref.read(syncServiceProvider).ensureInitialized().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _anon.dispose();
    _email.dispose();
    _password.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  void _say(String m, {bool error = false}) =>
      setState(() { _msg = m; _msgIsError = error; });

  Future<void> _guard(Future<void> Function() action) async {
    setState(() { _busy = true; _msg = null; });
    try {
      await action();
    } catch (e) {
      _say(_friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('SecretBox') || s.contains('Mac') || s.contains('authentication')) {
      return 'Wrong sync passphrase for this account’s data.';
    }
    return s.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final service = ref.watch(syncServiceProvider);
    final configured = ref.watch(syncConfiguredProvider).asData?.value ?? false;
    final initialized = service.isInitialized;
    final signedIn = service.isSignedIn;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Cloud Sync', style: t.titleLarge),
      ),
      body: AuroraBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xxl),
            children: [
              GlassCard(
                child: Row(children: [
                  Icon(signedIn ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      color: signedIn ? _ok : AppColors.muted),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      !configured
                          ? 'Not configured'
                          : !initialized
                              ? 'Configured — connecting…'
                              : !signedIn
                                  ? 'Connected — sign in to sync'
                                  : 'Signed in as ${service.currentUser?.email ?? 'account'}',
                      style: t.bodyMedium,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: Insets.lg),

              if (!configured || !initialized) ...[
                Text('SUPABASE PROJECT', style: t.labelSmall),
                const SizedBox(height: Insets.md),
                _field(_url, 'Project URL', hint: 'https://xxxx.supabase.co'),
                const SizedBox(height: Insets.md),
                _field(_anon, 'anon public key', hint: 'eyJ...'),
                const SizedBox(height: Insets.lg),
                _primary('Save & connect', () => _guard(() async {
                      await service.saveConfig(_url.text, _anon.text);
                      ref.invalidate(syncConfiguredProvider);
                      final ok = await service.ensureInitialized();
                      _say(ok
                          ? 'Connected. Now sign in below.'
                          : 'Could not connect — double-check the URL/key, then restart the app.');
                    })),
                const SizedBox(height: Insets.md),
                Text('See docs/SUPABASE.md for the 2-minute setup + schema.', style: t.bodySmall),
              ] else if (!signedIn) ...[
                Text('ACCOUNT', style: t.labelSmall),
                const SizedBox(height: Insets.md),
                _field(_email, 'Email'),
                const SizedBox(height: Insets.md),
                _field(_password, 'Password', obscure: true),
                const SizedBox(height: Insets.lg),
                Row(children: [
                  Expanded(
                    child: _primary('Sign in', () => _guard(() async {
                          await service.signIn(_email.text, _password.text);
                          _say('Signed in.');
                        })),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: _secondary('Sign up', () => _guard(() async {
                          await service.signUp(_email.text, _password.text);
                          _say(service.isSignedIn
                              ? 'Account created.'
                              : 'Check your email to confirm, then sign in.');
                        })),
                  ),
                ]),
              ] else ...[
                Text('SYNC PASSPHRASE', style: t.labelSmall),
                const SizedBox(height: 6),
                Text('Your end-to-end key. Use the same one on every device.', style: t.bodySmall),
                const SizedBox(height: Insets.md),
                _field(_passphrase, 'Sync passphrase', obscure: true),
                const SizedBox(height: Insets.lg),
                _primary('Sync now', () => _guard(() async {
                      if (_passphrase.text.length < 4) {
                        _say('Enter your sync passphrase (4+ chars).', error: true);
                        return;
                      }
                      ref.read(syncPassphraseProvider.notifier).set(_passphrase.text);
                      final r = await service.syncNow(_passphrase.text);
                      _say(r.message);
                    })),
                const SizedBox(height: Insets.md),
                _secondary('Sign out', () => _guard(() async {
                      await service.signOut();
                      _say('Signed out.');
                    })),
              ],

              if (_msg != null) ...[
                const SizedBox(height: Insets.lg),
                Row(children: [
                  Icon(_msgIsError ? Icons.error_outline : Icons.check_circle_outline,
                      size: 16, color: _msgIsError ? _err : _ok),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                      child: Text(_msg!,
                          style: t.bodySmall?.copyWith(color: _msgIsError ? _err : _ok))),
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

  Widget _field(TextEditingController c, String label, {String? hint, bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.graphiteHi,
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: AppColors.faint),
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: const BorderSide(color: AppColors.electricBlue),
        ),
      ),
    );
  }

  Widget _primary(String label, VoidCallback onTap) => NeoBlock(
        color: AppColors.electricBlue,
        foreground: Colors.white,
        onTap: _busy ? null : onTap,
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Center(child: Text(label)),
      );

  Widget _secondary(String label, VoidCallback onTap) => GestureDetector(
        onTap: _busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Insets.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
}
