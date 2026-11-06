import 'package:flutter/material.dart';

class C {
  static const accent = Color(0xFFC2462E); // terracotta
  static const paper = Color(0xFFF7F2EA);
  static const ink = Color(0xFF2B2622);
  static const muted = Color(0xFF7A7068);
  static const nightBg = Color(0xFF1A1714);
  static const nightCard = Color(0xFF25211D);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: C.accent,
    brightness: b,
    primary: dark ? const Color(0xFFE77B62) : C.accent,
    surface: dark ? C.nightBg : C.paper,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'ReadexPro',
    scaffoldBackgroundColor: dark ? C.nightBg : C.paper,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? C.nightBg : C.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 19,
        fontWeight: FontWeight.w500,
        color: dark ? Colors.white : C.ink,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? C.nightCard : Colors.white,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: 'ReadexPro', fontSize: 12, color: dark ? Colors.white70 : C.ink),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: dark ? C.nightCard : Colors.white,
      side: BorderSide(color: dark ? Colors.white12 : const Color(0xFFE6DDD1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

Color mutedOf(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? Colors.white60 : C.muted;
