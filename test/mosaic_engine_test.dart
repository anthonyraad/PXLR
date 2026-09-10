import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pxlr/mosaic_engine.dart';

List<List<Color>> _grid(Color fill, {Color? border}) {
  const n = 9;
  return List.generate(n, (y) {
    return List.generate(n, (x) {
      final onEdge = y == 0 || y == n - 1 || x == 0 || x == n - 1;
      if (border != null && onEdge) return border;
      return fill;
    });
  });
}

void main() {
  test('dominantColors skips near-white cells', () {
    final colors = _grid(const Color(0xFF3366CC), border: const Color(0xFFFFFFFF));
    final dominant = MosaicEngine.dominantColors(colors);
    expect(dominant, isNotEmpty);
    for (final c in dominant) {
      final r = (c.r * 255).round();
      final g = (c.g * 255).round();
      final b = (c.b * 255).round();
      expect(r < 230 || (r - g).abs() > 45 || (r - b).abs() > 45, isTrue);
    }
    expect(
      dominant.any((c) {
        final r = (c.r * 255).round();
        final g = (c.g * 255).round();
        final b = (c.b * 255).round();
        return r > 200 && g < 120 && b < 120; // reddish subject absent; expect blue
      }),
      isFalse,
    );
    // Subject blue should be represented.
    expect(
      dominant.any((c) {
        final b = (c.b * 255).round();
        final r = (c.r * 255).round();
        return b > r;
      }),
      isTrue,
    );
  });

  test('dominantColors excludes perimeter backdrop color', () {
    const subject = Color(0xFFE85A2A);
    const backdrop = Color(0xFF1A6B3C);
    final colors = _grid(subject, border: backdrop);
    final dominant = MosaicEngine.dominantColors(colors);

    expect(dominant, isNotEmpty);
    for (final c in dominant) {
      final g = (c.g * 255).round();
      final r = (c.r * 255).round();
      // Backdrop is green-forward; subject is orange-forward.
      expect(g > r + 20, isFalse, reason: 'backdrop green should not appear as a swatch');
    }
    expect(
      dominant.any((c) {
        final r = (c.r * 255).round();
        final g = (c.g * 255).round();
        return r > g;
      }),
      isTrue,
    );
  });
}
