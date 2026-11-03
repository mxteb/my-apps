import 'package:flutter_test/flutter_test.dart';
import 'package:photo_sorter/sorter.dart';

void main() {
  test('year period', () {
    final p = DatePeriod.year(2025);
    expect(p.contains(DateTime(2025, 1, 1)), isTrue);
    expect(p.contains(DateTime(2025, 12, 31, 23, 59)), isTrue);
    expect(p.contains(DateTime(2026, 1, 1)), isFalse);
    expect(DatePeriod.parse(p.code), p);
  });
  test('last 3 months', () {
    final p = DatePeriod.lastMonths(3);
    final now = DateTime.now();
    expect(p.contains(now.subtract(const Duration(days: 30))), isTrue);
    expect(p.contains(now.subtract(const Duration(days: 120))), isFalse);
  });
  test('custom inclusive end', () {
    final p = DatePeriod.parse(DatePeriod.custom(DateTime(2024, 3, 1), DateTime(2024, 3, 10)).code);
    expect(p.contains(DateTime(2024, 3, 10, 22)), isTrue);
    expect(p.contains(DateTime(2024, 3, 11)), isFalse);
    expect(p.contains(DateTime(2024, 2, 29)), isFalse);
    expect(p.customTo, DateTime(2024, 3, 10));
  });
  test('bad code falls back to all', () {
    expect(DatePeriod.parse('year:x').isAll, isTrue);
    expect(DatePeriod.parse(null).isAll, isTrue);
  });
}
