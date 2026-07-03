import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_habits/features/heatmap/application/heatmap_providers.dart';

void main() {
  group('levelFor', () {
    test('no completions is level 0', () {
      expect(levelFor(0, 5), 0);
      expect(levelFor(3, 0), 0);
    });

    test('all active habits done is a perfect day (level 4)', () {
      expect(levelFor(5, 5), 4);
    });

    test('buckets partial completion into 1–3', () {
      expect(levelFor(1, 5), 1); // 0.2  -> low
      expect(levelFor(2, 5), 2); // 0.4  -> moderate
      expect(levelFor(4, 5), 3); // 0.8  -> high
    });
  });
}
