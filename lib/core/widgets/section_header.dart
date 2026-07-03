import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Small all-caps mono section label, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  const SectionHeader(this.title, {super.key, this.trailingLabel, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.lg, bottom: Insets.md),
      child: Row(
        children: [
          Expanded(
            child: Text(title.toUpperCase(),
                style: t.labelSmall?.copyWith(letterSpacing: 1.6)),
          ),
          if (trailingLabel != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(trailingLabel!,
                  style: t.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
            ),
        ],
      ),
    );
  }
}
