import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/journal_providers.dart';
import '../data/journal_kind.dart';

const _danger = Color(0xFFE5484D);

Future<void> showBurnRitual(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _BurnRitualSheet(),
  );
}

/// "What are you ready to let go of?" — lists entries; each can be archived or
/// burned forever (cryptographic destruction + a dissolve-into-stars animation).
class _BurnRitualSheet extends ConsumerWidget {
  const _BurnRitualSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final entries = ref.watch(decryptedJournalProvider).asData?.value ?? const [];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: const BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
      ),
      padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.md, Insets.xl, Insets.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.borderStrong, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Row(children: [
            const Icon(Icons.local_fire_department_outlined, color: AppColors.warmAmber),
            const SizedBox(width: Insets.sm),
            Text('What are you ready to let go of?', style: t.titleLarge),
          ]),
          const SizedBox(height: 6),
          Text(
            'Archive to keep it quietly, or burn it forever — burned entries are '
            'cryptographically destroyed and cannot be recovered.',
            style: t.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.lg),
              child: Text('Nothing to release. Your journal is clear.',
                  style: t.bodyMedium?.copyWith(color: AppColors.muted)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
                itemBuilder: (_, i) {
                  final e = entries[i];
                  final title = e.title.trim().isEmpty ? e.kind.label : e.title.trim();
                  return Container(
                    padding: const EdgeInsets.all(Insets.md),
                    decoration: BoxDecoration(
                      color: AppColors.graphiteHi,
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(e.kind.icon, color: e.kind.color, size: 18),
                        const SizedBox(width: Insets.md),
                        Expanded(
                            child: Text(title,
                                style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        TextButton(
                          onPressed: () {
                            ref.read(journalServiceProvider).archive(e.meta.id);
                          },
                          child: const Text('Archive'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: _danger),
                          onPressed: () => _confirmBurn(context, ref, e, title),
                          child: const Text('Burn'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmBurn(
      BuildContext context, WidgetRef ref, DecryptedEntry entry, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.graphiteHi,
        title: const Text('Burn forever?'),
        content: Text(
            '“$title” will be cryptographically destroyed. This is permanent and cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Keep')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _danger),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Burn forever'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Destroy FIRST — the promise is cryptographic destruction, so it must
    // never depend on an animation finishing (back button, app kill, etc.).
    await ref.read(journalServiceProvider).burn(entry.meta.id);
    if (!context.mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => BurnOverlay(
        title: title,
        color: entry.kind.color,
      ),
    );
  }
}

/// The paper-dissolving-into-stars animation — purely cosmetic; the entry is
/// already destroyed before this is shown.
class BurnOverlay extends StatefulWidget {
  final String title;
  final Color color;
  const BurnOverlay({super.key, required this.title, required this.color});

  @override
  State<BurnOverlay> createState() => _BurnOverlayState();
}

class _BurnOverlayState extends State<BurnOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
  late final List<_Star> _stars;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _stars = List.generate(80, (_) {
      return _Star(
        x: rnd.nextDouble(),
        y: 0.36 + rnd.nextDouble() * 0.28,
        delay: rnd.nextDouble() * 0.35,
        rise: 0.25 + rnd.nextDouble() * 0.5,
        size: 1.2 + rnd.nextDouble() * 2.8,
        drift: (rnd.nextDouble() - 0.5) * 0.12,
        twinkle: 1 + rnd.nextDouble() * 3,
      );
    });
    _c.forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_done) {
        _done = true;
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final paperOpacity = (1 - ((t - 0.25) / 0.4)).clamp(0.0, 1.0);
        final paperRise = -60 * Curves.easeIn.transform(t);
        final blur = 8 * Curves.easeIn.transform(t);
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _StarFieldPainter(t, _stars, widget.color))),
            Center(
              child: Opacity(
                opacity: paperOpacity,
                child: Transform.translate(
                  offset: Offset(0, paperRise),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: _paper(context),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: (Curves.easeIn.transform(t) * 1.4).clamp(0.0, 1.0),
                child: Text('Released.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
              ),
            ),
          ],
        );
      },
      ),
    );
  }

  Widget _paper(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: AppColors.graphiteHi,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: widget.color.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, color: widget.color, size: 26),
          const SizedBox(height: Insets.md),
          Text(widget.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Star {
  final double x, y, delay, rise, size, drift, twinkle;
  const _Star({
    required this.x,
    required this.y,
    required this.delay,
    required this.rise,
    required this.size,
    required this.drift,
    required this.twinkle,
  });
}

class _StarFieldPainter extends CustomPainter {
  final double progress;
  final List<_Star> stars;
  final Color accent;
  _StarFieldPainter(this.progress, this.stars, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final local = ((progress - s.delay) / (1 - s.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final op = sin(local * pi).clamp(0.0, 1.0);
      if (op <= 0.01) continue;
      final dx = (s.x + s.drift * local) * size.width + sin(local * pi * 2 * s.twinkle) * 5;
      final dy = (s.y - s.rise * Curves.easeOut.transform(local)) * size.height;
      final color = (local > 0.5 ? Colors.white : Color.lerp(accent, Colors.white, local * 2))!;

      final glow = Paint()
        ..color = color.withValues(alpha: op * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(dx, dy), s.size * 2.2, glow);

      final core = Paint()..color = color.withValues(alpha: op);
      canvas.drawCircle(Offset(dx, dy), s.size, core);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter old) => old.progress != progress;
}
