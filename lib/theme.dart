import 'package:flutter/material.dart';

class Palette {
  static const bg = Color(0xFF0D1020);
  static const surface = Color(0xFF161B33);
  static const surfaceHi = Color(0xFF1F2545);
  static const line = Color(0x1AFFFFFF);
  static const text = Color(0xFFEEF0FA);
  static const muted = Color(0xFF8089AD);
  static const accent = Color(0xFFFFB547);
  static const danger = Color(0xFFFF6B7A);
  static const good = Color(0xFF4FD6A0);
}

Color alpha(Color c, double o) => c.withAlpha((o * 255).round().clamp(0, 255));

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Palette.bg,
    colorScheme: const ColorScheme.dark(
      primary: Palette.accent,
      surface: Palette.surface,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: const TextTheme(
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: Palette.text),
      bodyMedium: TextStyle(fontSize: 14, color: Palette.text),
      labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Palette.muted,
          letterSpacing: .2),
    ),
  );
}
