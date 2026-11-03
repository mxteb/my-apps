import 'package:flutter/material.dart';

import 'l10n.dart';

/// ألوان التطبيق: ورق دافئ وحبر، بروح ألبوم صور.
class Palette {
  static const paper = Color(0xFFEFE8DC);
  static const card = Color(0xFFFFFDF8);
  static const ink = Color(0xFF2A241D);
  static const body = Color(0xFF4A4136);
  static const muted = Color(0xFF6B6052);
  static const red = Color(0xFFC2482D);
  static const blue = Color(0xFF2F5D8C);
  static const tape = Color(0xBFD6C496);
  static const gold = Color(0xFFB8862B);
}

TextStyle hand(double size, {Color color = Palette.ink, FontWeight weight = FontWeight.w700}) =>
    TextStyle(fontFamily: 'ArefRuqaa', fontSize: size, color: color, fontWeight: weight, height: 1.3);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'ReadexPro',
    scaffoldBackgroundColor: Palette.paper,
    colorScheme: ColorScheme.fromSeed(seedColor: Palette.blue, surface: Palette.paper),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'ReadexPro', bodyColor: Palette.ink, displayColor: Palette.ink),
  );
}

List<BoxShadow> paperShadow([double depth = 1]) => [BoxShadow(color: const Color(0x40452D14), blurRadius: 10 * depth, offset: Offset(0, 3 * depth))];

/// زر رئيسي ممتلئ.
class SolidButton extends StatelessWidget {
  const SolidButton(this.label, {super.key, required this.onPressed, this.color = Palette.ink, this.height = 56});
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Palette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    ),
  );
}

/// زر بإطار حبر.
class OutlineInkButton extends StatelessWidget {
  const OutlineInkButton(this.label, {super.key, required this.onPressed, this.height = 50});
  final String label;
  final VoidCallback? onPressed;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        side: const BorderSide(color: Palette.ink, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15),
      ),
      child: Text(label),
    ),
  );
}

String formatBytes(int bytes) {
  if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
  if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).round()} MB';
  return '${(bytes / 1024).round()} KB';
}

String formatDuration(int seconds) {
  final m = seconds ~/ 60, s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

const _monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
String formatDate(DateTime d) => isAr ? '${d.day} ${_monthsAr[d.month - 1]} ${d.year}' : '${_monthsEn[d.month - 1]} ${d.day}, ${d.year}';
