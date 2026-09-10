import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central palette + type styles, mirroring the web version's retro-futurism
/// theme: dark grey-to-black background, baby-blue title, magenta/cyan/gold
/// accents, chunky pixel display font paired with a mono UI font.
class PxlrColors {
  PxlrColors._();

  static const panel = Color(0xFF171531);
  static const line = Color(0xFF332F5C);
  static const pink = Color(0xFFFF3F8E);
  static const cyan = Color(0xFF33E6CF);
  static const gold = Color(0xFFFFCB3D);
  static const babyBlue = Color(0xFFA8D8FF);
  static const text = Color(0xFFF4F1FF);
  static const muted = Color(0xFF9089C2);
  static const outline = Color(0xFF1A0A12);

  /// The page background: dark grey fading to near-black.
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.45, 1.0],
    colors: [Color(0xFF3A3A3F), Color(0xFF1A1A1D), Color(0xFF050506)],
  );
}

class PxlrText {
  PxlrText._();

  static TextStyle display({double size = 44, Color color = PxlrColors.babyBlue}) =>
      GoogleFonts.pixelifySans(
        fontWeight: FontWeight.w700,
        fontSize: size,
        letterSpacing: 2,
        color: color,
      );

  static TextStyle label({double size = 13, Color color = PxlrColors.cyan}) =>
      GoogleFonts.pixelifySans(
        fontWeight: FontWeight.w500,
        fontSize: size,
        letterSpacing: 2,
        color: color,
      );

  static TextStyle body({double size = 13, Color color = PxlrColors.muted}) =>
      GoogleFonts.spaceMono(fontSize: size, color: color);

  static TextStyle mono({double size = 12, Color color = PxlrColors.muted, FontWeight weight = FontWeight.normal}) =>
      GoogleFonts.spaceMono(fontSize: size, color: color, fontWeight: weight);
}
