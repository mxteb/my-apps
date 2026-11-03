import 'package:flutter/material.dart';

import '../game.dart';
import '../l10n.dart';
import '../theme.dart';

/// شريط علوي في شاشة الفرز: المستوى والنقاط والسلسلة.
class GameHud extends StatelessWidget {
  const GameHud({super.key, required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      LevelSeal(level: game.level, size: 44),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 18, color: Palette.gold),
                const SizedBox(width: 3),
                Text('${game.points}', style: hand(22)),
              ],
            ),
            Text(
              game.combo >= 3 ? tr('${game.combo} متتالية', 'Combo ×${game.combo}') : game.levelTitle(),
              style: TextStyle(fontSize: 12, color: game.combo >= 3 ? Palette.red : Palette.muted, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
    ],
  );
}

/// ختم دائري برقم المستوى، بروح ختم البريد.
class LevelSeal extends StatelessWidget {
  const LevelSeal({super.key, required this.level, this.size = 52});
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.08,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Palette.card,
        border: Border.all(color: Palette.gold, width: 2.5),
        boxShadow: paperShadow(0.5),
      ),
      alignment: Alignment.center,
      child: Text('$level', style: hand(size * 0.45, color: Palette.gold)),
    ),
  );
}

/// شريط هدف اليوم.
class DailyGoalBar extends StatelessWidget {
  const DailyGoalBar({super.key, required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final done = game.todayCount.clamp(0, Game.dailyGoal);
    final reached = game.goalDoneToday;
    return Row(
      children: [
        Icon(reached ? Icons.check_circle_rounded : Icons.flag_rounded, size: 16, color: reached ? Palette.blue : Palette.muted),
        const SizedBox(width: 6),
        Text(
          reached ? tr('هدف اليوم مكتمل', 'Daily goal done') : tr('هدف اليوم $done/${Game.dailyGoal}', 'Today $done/${Game.dailyGoal}'),
          style: const TextStyle(fontSize: 12, color: Palette.body),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done / Game.dailyGoal,
              minHeight: 6,
              backgroundColor: const Color(0xFFDDD3C2),
              color: reached ? Palette.blue : Palette.gold,
            ),
          ),
        ),
        if (game.currentStreak > 0) ...[
          const SizedBox(width: 10),
          const Icon(Icons.local_fire_department_rounded, size: 16, color: Palette.red),
          Text(
            '${game.currentStreak}',
            style: const TextStyle(fontSize: 12, color: Palette.red, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

/// "+10" يطفو للأعلى ثم يختفي بعد كل قرار.
class GainFloater extends StatefulWidget {
  const GainFloater({super.key, required this.points, required this.combo});
  final int points;
  final int combo;

  @override
  State<GainFloater> createState() => _GainFloaterState();
}

class _GainFloaterState extends State<GainFloater> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final big = widget.points > Game.basePoints;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_c.value);
          return Opacity(
            opacity: (1 - _c.value).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 20 - 50 * t),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: Palette.card, borderRadius: BorderRadius.circular(20), boxShadow: paperShadow(0.6)),
                  child: Text(
                    '+${widget.points}',
                    textDirection: TextDirection.ltr,
                    style: hand(big ? 28 : 22, color: big ? Palette.red : Palette.gold),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// بطاقة اللعبة في الشاشة الرئيسية.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(color: Palette.card, boxShadow: paperShadow(0.8)),
    child: Row(
      children: [
        LevelSeal(level: game.level),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(game.levelTitle(), style: hand(20)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: game.levelProgress, minHeight: 6, backgroundColor: const Color(0xFFDDD3C2), color: Palette.gold),
              ),
              const SizedBox(height: 4),
              Text(
                tr('${game.points} نقطة · بقي ${game.pointsToNext} للمستوى التالي', '${game.points} pts · ${game.pointsToNext} to next level'),
                style: const TextStyle(fontSize: 11, color: Palette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department_rounded, size: 20, color: game.currentStreak > 0 ? Palette.red : Palette.muted),
                Text('${game.currentStreak}', style: hand(18, color: game.currentStreak > 0 ? Palette.red : Palette.muted)),
              ],
            ),
            InkWell(
              onTap: () => showBadges(context, game),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_rounded, size: 18, color: Palette.gold),
                    Text(' ${game.unlocked.length}/${badges.length}', style: const TextStyle(fontSize: 12, color: Palette.ink)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

void showBadges(BuildContext context, Game game) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Palette.paper,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (c) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('الإنجازات', 'Badges'), style: hand(30)),
          Text(
            tr('أفضل سلسلة: ${game.bestCombo} · ملفات فرزتها: ${game.lifetimeSorted}', 'Best combo: ${game.bestCombo} · Files sorted: ${game.lifetimeSorted}'),
            style: const TextStyle(fontSize: 12, color: Palette.muted),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.3,
              children: [for (final b in badges) _BadgeTile(badge: b, unlocked: game.unlocked.contains(b.id))],
            ),
          ),
        ],
      ),
    ),
  ),
);

class BadgeTileForTest extends _BadgeTile {
  const BadgeTileForTest({super.key, required super.badge, required super.unlocked});
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({super.key, required this.badge, required this.unlocked});
  final GameBadge badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: unlocked ? 1 : 0.45,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Palette.card,
        border: Border.all(color: unlocked ? Palette.gold : const Color(0xFFCFC4B2), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(unlocked ? badge.icon : Icons.lock_rounded, color: unlocked ? Palette.gold : Palette.muted, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  badge.desc,
                  style: const TextStyle(fontSize: 10.5, color: Palette.muted, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
