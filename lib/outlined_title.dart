import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

/// Renders text with a solid outline behind a solid fill — used for the
/// "PXLR" title. A single flat drop-shadow gives it depth without the
/// legibility problems that offset-duplicate shadows caused on digits.
class OutlinedTitle extends StatelessWidget {
  const OutlinedTitle(
    this.text, {
    super.key,
    this.fontSize = 44,
    this.fillColor = PxlrColors.babyBlue,
    this.strokeColor = PxlrColors.outline,
    this.strokeWidth = 3,
  });

  final String text;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  TextStyle get _base => GoogleFonts.pixelifySans(
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
        letterSpacing: 2,
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Flat drop shadow, offset down, no color duplication of the glyph.
        Transform.translate(
          offset: const Offset(0, 6),
          child: Text(
            text,
            style: _base.copyWith(color: Colors.black.withOpacity(0.45)),
          ),
        ),
        // Solid outline pass — no `color` set, only `foreground`.
        Text(
          text,
          style: _base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        // Fill pass on top.
        Text(
          text,
          style: _base.copyWith(color: fillColor),
        ),
      ],
    );
  }
}
