import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../game.dart';
import '../l10n.dart';
import '../sorter.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import '../widgets/swipe_card.dart';
import 'review.dart';
import 'viewer.dart';

/// شاشة الفرز: بطاقة واحدة في كل مرة.
class SortScreen extends StatefulWidget {
  const SortScreen({super.key, required this.sorter});
  final Sorter sorter;

  @override
  State<SortScreen> createState() => _SortScreenState();
}

class _SortScreenState extends State<SortScreen> {
  final _cardKey = GlobalKey<SwipeCardState>();
  StreamSubscription<GameEvent>? _sub;
  int _seenTick = 0;

  static String _filterLabel(MediaFilter f) => switch (f) {
    MediaFilter.all => tr('الكل', 'All'),
    MediaFilter.duplicates => tr('المكررة', 'Duplicates'),
    MediaFilter.photos => tr('الصور', 'Photos'),
    MediaFilter.videos => tr('الفيديوهات', 'Videos'),
  };

  @override
  void initState() {
    super.initState();
    widget.sorter.game.resetCombo();
    _seenTick = widget.sorter.gainTick;
    _sub = widget.sorter.game.events.listen(_showEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _showEvent(GameEvent e) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    // بدون إخفاء السابق: لو جاء أكثر من حدث معًا (هدف + مستوى + إنجاز) تظهر بالتتابع
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.ink,
        duration: const Duration(milliseconds: 2600),
        margin: const EdgeInsets.fromLTRB(22, 0, 22, 120),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(e.icon, color: Palette.gold, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, style: hand(20, color: Palette.card)),
                  Text(e.subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFFE6DCCB))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _decide(Sorter s, AssetEntity current, Decision d) {
    s.decide(current, d);
    if (settings.gameMode) HapticFeedback.selectionClick();
  }

  Future<void> _open(Sorter s, AssetEntity current) async {
    final d = await MediaViewer.open(context, assets: [current], sorter: s, mode: ViewerMode.sort);
    if (d == null || !mounted || s.current?.id != current.id) return;
    await _cardKey.currentState?.fling(d);
  }

  void _review() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ReviewScreen(sorter: widget.sorter)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.sorter,
      builder: (context, _) {
        final s = widget.sorter;
        final current = s.current;
        final game = settings.gameMode;
        final showGain = game && s.gainTick != _seenTick;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (game)
                        Expanded(child: GameHud(game: s.game))
                      else ...[
                        Text('${s.sortedCount + (current == null ? 0 : 1)}', style: hand(30)),
                        const SizedBox(width: 6),
                        Text(tr('من ${s.total}', 'of ${s.total}'), style: const TextStyle(fontSize: 13, color: Palette.muted)),
                        const Spacer(),
                      ],
                      OutlinedButton.icon(
                        onPressed: _review,
                        icon: const Icon(Icons.pause_rounded, size: 18),
                        label: Text(tr('استراحة', 'Break')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Palette.ink,
                          backgroundColor: Palette.card,
                          side: const BorderSide(color: Palette.ink, width: 1.5),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final f in MediaFilter.values)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: Text('${_filterLabel(f)}  ${s.countFor(f)}'),
                              selected: s.filter == f,
                              onSelected: (_) => s.setFilter(f),
                              showCheckmark: false,
                              selectedColor: Palette.ink,
                              backgroundColor: Palette.card,
                              labelStyle: TextStyle(color: s.filter == f ? Palette.card : Palette.ink, fontSize: 13),
                              side: const BorderSide(color: Palette.ink, width: 1.5),
                              shape: const StadiumBorder(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (game) ...[const SizedBox(height: 10), DailyGoalBar(game: s.game)],
                  const SizedBox(height: 16),
                  Expanded(
                    child: current == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(tr('انتهيت!', 'All done!'), style: hand(36)),
                                const SizedBox(height: 6),
                                Text(
                                  s.filter == MediaFilter.all
                                      ? tr('لنراجع الملفات المحددة قبل حذفها', "Let's review the marked files before deleting")
                                      : tr('لا توجد ملفات أخرى في هذا التصنيف', 'No more files in this category'),
                                  style: const TextStyle(color: Palette.body),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Stack(
                              children: [
                                const Positioned.fill(child: PileBackdrop()),
                                Positioned.fill(
                                  child: SwipeCard(
                                    key: _cardKey,
                                    asset: current,
                                    sorter: s,
                                    onDecide: (d) => _decide(s, current, d),
                                    onOpen: () => _open(s, current),
                                  ),
                                ),
                                if (showGain)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: GainFloater(key: ValueKey(s.gainTick), points: s.lastGain, combo: s.game.combo),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  // الأزرار بترتيب فيزيائي ثابت: الحذف يسارًا والإبقاء يمينًا
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: tr('حذف', 'Delete'),
                            icon: Icons.chevron_left_rounded,
                            color: Palette.red,
                            filled: false,
                            onPressed: current == null ? null : () => _cardKey.currentState?.fling(Decision.delete),
                          ),
                        ),
                        IconButton(
                          tooltip: tr('تراجع عن آخر اختيار', 'Undo last choice'),
                          onPressed: s.history.isEmpty ? null : s.undo,
                          icon: const Icon(Icons.undo_rounded, color: Palette.muted),
                          iconSize: 24,
                          constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                        ),
                        Expanded(
                          child: _ActionButton(
                            label: tr('إبقاء', 'Keep'),
                            icon: Icons.chevron_right_rounded,
                            color: Palette.blue,
                            filled: true,
                            iconAfter: true,
                            onPressed: current == null ? null : () => _cardKey.currentState?.fling(Decision.keep),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, color: Palette.muted),
                      children: [
                        TextSpan(text: tr('للحذف ', 'Delete ')),
                        TextSpan(
                          text: '${s.deleteCount}',
                          style: const TextStyle(color: Palette.red, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: tr('  ·  للإبقاء ', '  ·  Keep ')),
                        TextSpan(
                          text: '${s.keepCount}',
                          style: const TextStyle(color: Palette.blue, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.color, required this.filled, required this.onPressed, this.iconAfter = false});
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final bool iconAfter;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final children = [Icon(icon), const SizedBox(width: 4), Text(label, textDirection: isAr ? TextDirection.rtl : TextDirection.ltr)];
    final content = Row(mainAxisAlignment: MainAxisAlignment.center, children: iconAfter ? children.reversed.toList() : children);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const text = TextStyle(fontSize: 17, fontWeight: FontWeight.w500);
    return SizedBox(
      height: 60,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Palette.card, shape: shape, textStyle: text),
              child: content,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                backgroundColor: Palette.card,
                side: BorderSide(color: color, width: 2),
                shape: shape,
                textStyle: text,
              ),
              child: content,
            ),
    );
  }
}
