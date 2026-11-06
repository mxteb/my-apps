String fmtDuration(int seconds) {
  if (seconds <= 0) return '';
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

String fmtMs(int ms) => fmtDuration((ms / 1000).floor()).isEmpty ? '0:00' : fmtDuration((ms / 1000).floor());

String fmtCount(int n) {
  String trim(double v) {
    final s = v.toStringAsFixed(v < 10 ? 1 : 0);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  if (n >= 1000000000) return '${trim(n / 1e9)} مليار';
  if (n >= 1000000) return '${trim(n / 1e6)} مليون';
  if (n >= 1000) return '${trim(n / 1e3)} ألف';
  return '$n';
}

String fmtViews(int? n) => n == null ? '' : '${fmtCount(n)} مشاهدة';

String fmtBytes(int b) {
  if (b <= 0) return '';
  if (b >= 1 << 30) return '${(b / (1 << 30)).toStringAsFixed(1)} غ.ب';
  if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} م.ب';
  return '${(b / 1024).round()} ك.ب';
}

/// Turns "3 weeks ago" / "Streamed 2 days ago" into Arabic.
String fmtWhen(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final m = RegExp(r'(\d+)\s+(second|minute|hour|day|week|month|year)s?\s+ago', caseSensitive: false)
      .firstMatch(raw);
  if (m == null) return raw;
  final n = int.parse(m.group(1)!);
  const one = {
    'second': 'ثانية', 'minute': 'دقيقة', 'hour': 'ساعة', 'day': 'يوم',
    'week': 'أسبوع', 'month': 'شهر', 'year': 'سنة',
  };
  const two = {
    'second': 'ثانيتين', 'minute': 'دقيقتين', 'hour': 'ساعتين', 'day': 'يومين',
    'week': 'أسبوعين', 'month': 'شهرين', 'year': 'سنتين',
  };
  const few = {
    'second': 'ثوانٍ', 'minute': 'دقائق', 'hour': 'ساعات', 'day': 'أيام',
    'week': 'أسابيع', 'month': 'أشهر', 'year': 'سنوات',
  };
  final u = m.group(2)!.toLowerCase();
  final prefix = raw.toLowerCase().contains('stream') ? 'بُثّ منذ' : 'منذ';
  if (n == 1) return '$prefix ${one[u]}';
  if (n == 2) return '$prefix ${two[u]}';
  if (n <= 10) return '$prefix $n ${few[u]}';
  return '$prefix $n ${one[u]}';
}
