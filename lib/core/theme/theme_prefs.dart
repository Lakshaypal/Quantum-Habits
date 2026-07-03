import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/habits/application/habit_providers.dart'
    show databaseProvider;
import 'heatmap_palette.dart';

const _kPaletteKey = 'pref_heatmap_palette';

/// The user's heatmap palette. Persisted in KeyValues, which syncs — pick a
/// palette on one device and every device follows.
final heatmapPaletteProvider =
    NotifierProvider<HeatmapPaletteNotifier, HeatmapPalette>(
        HeatmapPaletteNotifier.new);

class HeatmapPaletteNotifier extends Notifier<HeatmapPalette> {
  @override
  HeatmapPalette build() {
    // Stay live: a palette change synced in from another device applies here.
    final sub = ref
        .read(databaseProvider)
        .watchKV(_kPaletteKey)
        .listen((name) => state = HeatmapPalette.byName(name));
    ref.onDispose(sub.cancel);
    return HeatmapPalette.frostBlue;
  }

  Future<void> set(HeatmapPalette palette) async {
    state = palette;
    await ref.read(databaseProvider).setKV(_kPaletteKey, palette.name);
  }
}
