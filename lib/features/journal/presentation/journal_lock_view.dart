import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/neo_block.dart';
import '../application/journal_providers.dart';

/// Gate in front of the journal. First run sets a passphrase; later runs unlock
/// with it (or biometrics if remembered on the device).
class JournalLockView extends ConsumerStatefulWidget {
  const JournalLockView({super.key});
  @override
  ConsumerState<JournalLockView> createState() => _JournalLockViewState();
}

class _JournalLockViewState extends ConsumerState<JournalLockView> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _remember = true;
  String? _error;
  bool _bioAvailable = false;
  bool _bioHasKey = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final bio = ref.read(biometricVaultProvider);
    final available = await bio.isAvailable();
    final hasKey = await bio.hasStoredKey();
    if (mounted) {
      setState(() {
        _bioAvailable = available;
        _bioHasKey = hasKey;
      });
    }
  }

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    final p = _pass.text;
    if (p.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (p != _confirm.text) {
      setState(() => _error = 'Passphrases don’t match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final vault =
          await ref.read(journalKeyServiceProvider).setupPassphrase(p);
      if (!mounted) return;
      if (_remember && _bioAvailable) {
        await ref.read(biometricVaultProvider).remember(vault);
      } else {
        await ref.read(biometricVaultProvider).forget();
      }
      if (!mounted) return;
      ref.invalidate(hasPassphraseProvider);
      ref.read(journalSessionProvider.notifier).open(vault);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Bad state: ', ''));
        ref.invalidate(hasPassphraseProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final vault =
          await ref.read(journalKeyServiceProvider).unlock(_pass.text);
      if (!mounted) return;
      if (vault == null) {
        setState(() => _error = 'Incorrect passphrase.');
        return;
      }
      if (_remember && _bioAvailable) {
        await ref.read(biometricVaultProvider).remember(vault);
      } else {
        // Respect an explicit opt-out: drop any previously stored key.
        await ref.read(biometricVaultProvider).forget();
      }
      if (!mounted) return;
      ref.read(journalSessionProvider.notifier).open(vault);
    } catch (e) {
      if (mounted) setState(() => _error = 'Unlock failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _biometricUnlock() async {
    setState(() => _error = null);
    try {
      final bio = ref.read(biometricVaultProvider);
      final vault = await bio.unlockWithBiometrics();
      if (!mounted) return;
      if (vault == null) {
        setState(() => _error = 'Biometric unlock unavailable.');
        return;
      }
      // A stored key can go stale when sync brings another device's salt —
      // verify before trusting it, else fall back to the passphrase.
      final valid =
          await ref.read(journalKeyServiceProvider).validateVault(vault);
      if (!mounted) return;
      if (!valid) {
        await bio.forget();
        if (mounted) {
          setState(() {
            _bioHasKey = false;
            _error =
                'Saved key no longer matches this journal — enter your passphrase.';
          });
        }
        return;
      }
      ref.read(journalSessionProvider.notifier).open(vault);
    } catch (e) {
      if (mounted) setState(() => _error = 'Biometric unlock failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasPass = ref.watch(hasPassphraseProvider);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: hasPass.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Journal unavailable: $e', style: t.bodyMedium),
            data: (exists) => GlassCard(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(exists ? Icons.lock_outline : Icons.shield_outlined,
                      color: AppColors.softPurple, size: 30),
                  const SizedBox(height: Insets.md),
                  Text(exists ? 'Private Journal' : 'Encrypt your journal',
                      style: t.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                    exists
                        ? 'Enter your passphrase to unlock.'
                        : 'Choose a passphrase. Entries are sealed with AES-256 — '
                            'we can’t recover them if you forget it.',
                    style: t.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Insets.lg),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    style: t.bodyLarge,
                    onSubmitted: (_) => exists ? _unlock() : null,
                    decoration: _dec('Passphrase'),
                  ),
                  if (!exists) ...[
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: _confirm,
                      obscureText: true,
                      style: t.bodyLarge,
                      decoration: _dec('Confirm passphrase'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: Insets.md),
                    Text(_error!, style: t.bodySmall?.copyWith(color: const Color(0xFFE5484D))),
                  ],
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _remember,
                          onChanged: (v) => setState(() => _remember = v ?? false),
                          side: const BorderSide(color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: Text('Remember on this device (biometric unlock)',
                            style: t.bodySmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  Align(
                    alignment: Alignment.center,
                    child: NeoBlock(
                      color: AppColors.softPurple,
                      foreground: Colors.white,
                      onTap: _busy ? null : (exists ? _unlock : _setup),
                      padding: const EdgeInsets.symmetric(horizontal: Insets.xl, vertical: Insets.md),
                      child: _busy
                          ? const SizedBox(
                              height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(exists ? 'Unlock' : 'Create & unlock'),
                    ),
                  ),
                  if (exists && _bioAvailable && _bioHasKey) ...[
                    const SizedBox(height: Insets.md),
                    TextButton.icon(
                      onPressed: _biometricUnlock,
                      icon: const Icon(Icons.fingerprint, size: 20),
                      label: const Text('Unlock with biometrics'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.graphiteHi,
        labelStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: const BorderSide(color: AppColors.softPurple),
        ),
      );
}
