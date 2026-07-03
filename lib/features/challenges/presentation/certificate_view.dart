import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/neo_block.dart';
import '../../habits/data/habit_type.dart';
import '../application/challenge_providers.dart';
import '../data/challenge_model.dart';

const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _fmt(DateTime d) => '${_mon[d.month]} ${d.day}, ${d.year}';

class CertificateView extends StatefulWidget {
  final Challenge challenge;
  final ChallengeProgress progress;
  const CertificateView({super.key, required this.challenge, required this.progress});

  @override
  State<CertificateView> createState() => _CertificateViewState();
}

class _CertificateViewState extends State<CertificateView> {
  final _boundaryKey = GlobalKey();
  bool _saving = false;

  Future<void> _export() async {
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getApplicationDocumentsDirectory();
      final safe = widget.challenge.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final file = File('${dir.path}/quantum_habits_certificate_$safe.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Certificate saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.challenge.colorValue);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, size: 20),
                    ),
                    const SizedBox(width: 4),
                    Text('Certificate', style: t.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(Insets.xl),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: _Certificate(challenge: widget.challenge, progress: widget.progress, color: color),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Insets.xl),
                child: NeoBlock(
                  color: color,
                  onTap: _saving ? null : _export,
                  padding: const EdgeInsets.symmetric(horizontal: Insets.xl, vertical: Insets.md),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.download_rounded, size: 18),
                    const SizedBox(width: Insets.sm),
                    Text(_saving ? 'Saving…' : 'Save as image'),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Certificate extends StatelessWidget {
  final Challenge challenge;
  final ChallengeProgress progress;
  final Color color;
  const _Certificate({required this.challenge, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = challenge.iconCodePoint != null
        ? habitIconData(challenge.iconCodePoint!)
        : Icons.flag_rounded;
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: Insets.xl, vertical: Insets.xxl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111319), Color(0xFF0A0B0D)],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 40, spreadRadius: -6),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: Insets.xl),
          Text('CERTIFICATE OF',
              style: AppType.mono(size: 11, color: AppColors.muted).copyWith(letterSpacing: 3)),
          const SizedBox(height: 4),
          Text('COMPLETION',
              style: AppType.mono(size: 16, weight: FontWeight.w700, color: AppColors.frostWhite)
                  .copyWith(letterSpacing: 4)),
          const SizedBox(height: Insets.lg),
          Container(width: 40, height: 2, color: color),
          const SizedBox(height: Insets.lg),
          Text(challenge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: color, height: 1.15)),
          const SizedBox(height: Insets.sm),
          Text(
            '${progress.totalDays} days · ${ChallengeModeX.fromIndex(challenge.mode).label} mode',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            '${_fmt(challenge.startDate)}  —  ${_fmt(challenge.endDate)}',
            style: AppType.mono(size: 11, color: AppColors.faint),
          ),
          const SizedBox(height: Insets.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_outlined, size: 16, color: color),
              const SizedBox(width: 6),
              Text('QUANTUM HABITS',
                  style: AppType.mono(size: 10, weight: FontWeight.w600, color: AppColors.frostWhite)
                      .copyWith(letterSpacing: 2)),
            ],
          ),
        ],
      ),
    );
  }
}
