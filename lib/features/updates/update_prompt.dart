import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'update_service.dart';

/// Slim banner pinned under the status bar when a new version is waiting.
/// One tap updates in place; "Later" dismisses until the next launch check.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingUpdateProvider);
    if (pending == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.sm, Insets.xl, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg, vertical: Insets.sm),
        decoration: BoxDecoration(
          color: AppColors.electricBlue.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(Radii.md),
          border:
              Border.all(color: AppColors.electricBlue.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.system_update_alt_rounded,
                size: 16, color: AppColors.electricBlue),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text('Version ${pending.update.version} is ready',
                  style: t.bodyMedium),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(pendingUpdateProvider.notifier).set(null),
              child: Text('Later',
                  style: t.bodySmall?.copyWith(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => runUpdateFlow(context, ref, pending.update),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Downloads with a progress dialog, then installs. On desktop the app
/// restarts itself; on Android the system installer prompts.
Future<void> runUpdateFlow(
    BuildContext context, WidgetRef ref, UpdateInfo info) async {
  final progress = ValueNotifier<double>(0);
  var failed = false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.graphiteHi,
        title: Text('Updating to ${info.version}'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, p, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: p > 0 ? p : null),
              const SizedBox(height: Insets.md),
              Text(
                p >= 1
                    ? 'Installing… the app will reopen by itself.'
                    : 'Downloading… ${(p * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    await ref
        .read(updateServiceProvider)
        .downloadAndInstall(info, onProgress: (p) => progress.value = p);
  } catch (_) {
    failed = true;
  }
  // Android reaches here (installer takes over) — desktop exits before this.
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
    if (failed) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text(
              'In-place update failed — opened the download page instead.')));
    }
  }
  ref.read(pendingUpdateProvider.notifier).set(null);
}
