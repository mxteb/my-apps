import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

/// حدث يظهر للمستخدم كتنبيه: رفع مستوى، إنجاز جديد، أو هدف اليوم.
class GameEvent {
  const GameEvent(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

class GameBadge {
  const GameBadge(this.id, this.icon, this.arTitle, this.enTitle, this.arDesc, this.enDesc);
  final String id;
  final IconData icon;
  final String arTitle, enTitle, arDesc, enDesc;
  String get title => tr(arTitle, enTitle);
  String get desc => tr(arDesc, enDesc);
}

const badges = [
  GameBadge('first', Icons.flag_rounded, 'الخطوة الأولى', 'First Step', 'افرز أول ملف', 'Sort your first file'),
  GameBadge('s100', Icons.collections_rounded, 'مئة ملف', 'A Hundred', 'افرز 100 ملف', 'Sort 100 files'),
  GameBadge('s1000', Icons.auto_awesome_rounded, 'ألف ملف', 'A Thousand', 'افرز 1000 ملف', 'Sort 1,000 files'),
  GameBadge('dup10', Icons.content_copy_rounded, 'صائد المكرر', 'Dupe Hunter', 'حدّد 10 ملفات مكررة للحذف', 'Mark 10 duplicates for deletion'),
  GameBadge('combo50', Icons.bolt_rounded, 'نَفَس طويل', 'In the Zone', '50 قرارًا متتاليًا في جلسة واحدة', '50 decisions in a row in one session'),
  GameBadge('goal', Icons.check_circle_rounded, 'هدف اليوم', 'Daily Goal', 'أنجز هدف اليوم', 'Reach the daily goal'),
  GameBadge('streak3', Icons.local_fire_department_rounded, 'ثلاثة أيام', 'Three Days', 'أنجز الهدف ثلاثة أيام متتالية', 'Reach the goal 3 days in a row'),
  GameBadge('streak7', Icons.whatshot_rounded, 'أسبوع كامل', 'Full Week', 'أنجز الهدف سبعة أيام متتالية', 'Reach the goal 7 days in a row'),
  GameBadge('gb1', Icons.sd_storage_rounded, 'مساحة جديدة', 'Fresh Space', 'وفّر 1 GB من المساحة', 'Free up 1 GB'),
  GameBadge('clean', Icons.emoji_events_rounded, 'ألبوم مرتّب', 'Tidy Album', 'أنهِ فرز كل ملفاتك', 'Finish sorting all your files'),
];

const _levelTitles = [
  ['مبتدئ', 'Beginner'],
  ['مرتِّب ناشئ', 'Junior Sorter'],
  ['مرتِّب', 'Sorter'],
  ['منظِّم', 'Organizer'],
  ['منظِّم ماهر', 'Skilled Organizer'],
  ['خبير الألبوم', 'Album Expert'],
  ['حارس الذكريات', 'Memory Keeper'],
  ['سيّد الترتيب', 'Master of Order'],
  ['أسطورة الألبوم', 'Album Legend'],
];

const _thresholds = [0, 100, 300, 600, 1000, 1600, 2500, 4000, 6000];

/// منطق وضع اللعبة. كل شيء محلي على الجهاز.
class Game {
  static const _k = 'game_v1';
  static const dailyGoal = 50;
  static const basePoints = 10;
  static const duplicateBonus = 15;
  static const comboStep = 10;
  static const comboBonus = 20;

  late SharedPreferences _prefs;
  final _events = StreamController<GameEvent>.broadcast();
  Stream<GameEvent> get events => _events.stream;

  int points = 0;
  int lifetimeSorted = 0;
  int dupDeletes = 0;
  int freedBytes = 0;
  int bestCombo = 0;
  String today = '';
  int todayCount = 0;
  String lastGoalDay = '';
  int streak = 0;
  final Set<String> unlocked = {};

  /// سلسلة القرارات في الجلسة الحالية (لا تُحفظ).
  int combo = 0;

  void load(SharedPreferences prefs) {
    _prefs = prefs;
    final raw = prefs.getString(_k);
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      points = m['points'] ?? 0;
      lifetimeSorted = m['sorted'] ?? 0;
      dupDeletes = m['dup'] ?? 0;
      freedBytes = m['freed'] ?? 0;
      bestCombo = m['bestCombo'] ?? 0;
      today = m['today'] ?? '';
      todayCount = m['todayCount'] ?? 0;
      lastGoalDay = m['lastGoal'] ?? '';
      streak = m['streak'] ?? 0;
      unlocked.addAll(((m['badges'] ?? []) as List).cast<String>());
    }
    _rollDay();
  }

  void _save() => _prefs.setString(
    _k,
    jsonEncode({
      'points': points,
      'sorted': lifetimeSorted,
      'dup': dupDeletes,
      'freed': freedBytes,
      'bestCombo': bestCombo,
      'today': today,
      'todayCount': todayCount,
      'lastGoal': lastGoalDay,
      'streak': streak,
      'badges': unlocked.toList(),
    }),
  );

  static String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  void _rollDay() {
    final now = _day(DateTime.now());
    if (today != now) {
      today = now;
      todayCount = 0;
    }
  }

  // ---------------- المستويات ----------------

  int get level {
    var l = 0;
    while (l + 1 < _thresholds.length && points >= _thresholds[l + 1]) {
      l++;
    }
    if (l == _thresholds.length - 1) l += (points - _thresholds.last) ~/ 5000;
    return l + 1;
  }

  int _floorOf(int lvl) {
    final i = lvl - 1;
    if (i < _thresholds.length) return _thresholds[i];
    return _thresholds.last + (i - (_thresholds.length - 1)) * 5000;
  }

  /// تقدم المستوى الحالي من 0 إلى 1.
  double get levelProgress {
    final lo = _floorOf(level), hi = _floorOf(level + 1);
    return ((points - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  int get pointsToNext => _floorOf(level + 1) - points;

  String levelTitle([int? lvl]) {
    final t = _levelTitles[((lvl ?? level) - 1).clamp(0, _levelTitles.length - 1)];
    return tr(t[0], t[1]);
  }

  /// السلسلة المعروضة: تنقطع إذا مر يوم كامل بدون إنجاز الهدف.
  int get currentStreak {
    final now = DateTime.now();
    final yesterday = _day(now.subtract(const Duration(days: 1)));
    return (lastGoalDay == _day(now) || lastGoalDay == yesterday) ? streak : 0;
  }

  bool get goalDoneToday => lastGoalDay == _day(DateTime.now());

  // ---------------- الأحداث ----------------

  /// يرجع النقاط المكتسبة في هذا القرار (لعرض +10 على الشاشة).
  int onDecide({required bool delete, required bool duplicate, required bool allDone}) {
    _rollDay();
    final before = level;
    var gained = basePoints + (delete && duplicate ? duplicateBonus : 0);
    combo++;
    if (combo > bestCombo) bestCombo = combo;
    if (combo % comboStep == 0) gained += comboBonus;
    points += gained;
    lifetimeSorted++;
    todayCount++;
    if (delete && duplicate) dupDeletes++;

    if (todayCount == dailyGoal && !goalDoneToday) {
      final yesterday = _day(DateTime.now().subtract(const Duration(days: 1)));
      streak = lastGoalDay == yesterday ? streak + 1 : 1;
      lastGoalDay = today;
      _emit(
        GameEvent(
          Icons.check_circle_rounded,
          tr('أنجزت هدف اليوم!', 'Daily goal reached!'),
          streak > 1 ? tr('سلسلة $streak أيام متتالية', '$streak-day streak') : tr('عُد غدًا لتبدأ سلسلة', 'Come back tomorrow to start a streak'),
        ),
      );
    }
    if (level > before) {
      _emit(GameEvent(Icons.arrow_upward_rounded, tr('المستوى $level', 'Level $level'), levelTitle()));
    }
    _checkBadges(allDone: allDone);
    _save();
    return gained;
  }

  void onUndo({required bool delete, required bool duplicate}) {
    _rollDay();
    var lost = basePoints + (delete && duplicate ? duplicateBonus : 0);
    if (combo > 0 && combo % comboStep == 0) lost += comboBonus;
    points = (points - lost).clamp(0, 1 << 62);
    lifetimeSorted = (lifetimeSorted - 1).clamp(0, 1 << 62);
    if (todayCount > 0) todayCount--;
    if (delete && duplicate && dupDeletes > 0) dupDeletes--;
    if (combo > 0) combo--;
    _save();
  }

  void onDeleted(int bytes) {
    freedBytes += bytes;
    _checkBadges(allDone: false);
    _save();
  }

  void resetCombo() => combo = 0;

  void _checkBadges({required bool allDone}) {
    final checks = {
      'first': lifetimeSorted >= 1,
      's100': lifetimeSorted >= 100,
      's1000': lifetimeSorted >= 1000,
      'dup10': dupDeletes >= 10,
      'combo50': bestCombo >= 50,
      'goal': lastGoalDay.isNotEmpty,
      'streak3': streak >= 3,
      'streak7': streak >= 7,
      'gb1': freedBytes >= 1 << 30,
      'clean': allDone,
    };
    for (final b in badges) {
      if (checks[b.id] == true && unlocked.add(b.id)) {
        _emit(GameEvent(b.icon, tr('إنجاز جديد: ${b.arTitle}', 'New badge: ${b.enTitle}'), b.desc));
      }
    }
  }

  void _emit(GameEvent e) {
    if (settings.gameMode) _events.add(e);
  }
}
