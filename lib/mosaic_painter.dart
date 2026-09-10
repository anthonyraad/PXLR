import 'package:flutter/material.dart';
import 'mosaic_engine.dart';

/// Paints the mosaic grid: each cell as a solid flat-color block, with a
/// thin line at every cell boundary and a bolder line every [boldEvery]
/// cells (default 9 — the "ninths" grouping on a 27×27 grid).
class MosaicPainter extends CustomPainter {
  MosaicPainter({
    required this.cellColors,
    required this.showLines,
    this.boldEvery = MosaicEngine.ninthSize,
  });

  final List<List<Color>> cellColors;
  final bool showLines;
  final int boldEvery;

  @override
  void paint(Canvas canvas, Size size) {
    final n = cellColors.length;
    final cellSize = size.width / n;

    for (var gy = 0; gy < n; gy++) {
      for (var gx = 0; gx < n; gx++) {
        final paint = Paint()..color = cellColors[gy][gx];
        final x0 = (gx * cellSize).roundToDouble();
        final x1 = ((gx + 1) * cellSize).roundToDouble();
        final y0 = (gy * cellSize).roundToDouble();
        final y1 = ((gy + 1) * cellSize).roundToDouble();
        canvas.drawRect(Rect.fromLTRB(x0, y0, x1, y1), paint);
      }
    }

    if (!showLines) return;

    final thin = Paint()
      ..color = Colors.black.withOpacity(0.32)
      ..strokeWidth = 1.0;
    final bold = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..strokeWidth = 2.5;

    for (var i = 0; i <= n; i++) {
      final p = (i * cellSize).roundToDouble();
      final paint = (i % boldEvery == 0) ? bold : thin;
      canvas.drawLine(Offset(p, 0), Offset(p, size.height), paint);
      canvas.drawLine(Offset(0, p), Offset(size.width, p), paint);
    }
  }

  @override
  bool shouldRepaint(covariant MosaicPainter oldDelegate) {
    return oldDelegate.cellColors != cellColors ||
        oldDelegate.showLines != showLines ||
        oldDelegate.boldEvery != boldEvery;
  }
}
