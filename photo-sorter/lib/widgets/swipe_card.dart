import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../l10n.dart';
import '../sorter.dart';
import '../theme.dart';
import 'thumb.dart';

/// بطاقة بولارويد تُسحب: يمين = إبقاء، يسار = حذف.
class SwipeCard extends StatefulWidget {
  const SwipeCard({super.key, required this.asset, required this.sorter, required this.onDecide, this.onOpen});
  final AssetEntity asset;

  /// الضغط على البطاقة يفتح الملف بملء الشاشة.
  final VoidCallback? onOpen;
  final Sorter sorter;
  final void Function(Decision) onDecide;

  @override
  State<SwipeCard> createState() => SwipeCardState();
}

class SwipeCardState extends State<SwipeCard> with SingleTickerProviderStateMixin {
  static const _threshold = 110.0;
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Offset _drag = Offset.zero;
  Animation<Offset>? _anim;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _drag = _anim!.value));
    widget.sorter.ensureSize(widget.asset);
  }

  @override
  void didUpdateWidget(SwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _drag = Offset.zero;
      widget.sorter.ensureSize(widget.asset);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _animateTo(Offset target) async {
    _anim = Tween(begin: _drag, end: target).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    await _ctrl.forward(from: 0);
  }

  /// تُستدعى من الأزرار أو من نهاية السحب.
  Future<void> fling(Decision d) async {
    if (_ctrl.isAnimating) return;
    final w = MediaQuery.sizeOf(context).width;
    await _animateTo(Offset(d == Decision.keep ? w * 1.3 : -w * 1.3, _drag.dy + 40));
    widget.onDecide(d);
  }

  void _onEnd(DragEndDetails e) {
    final vx = e.velocity.pixelsPerSecond.dx;
    if (_drag.dx > _threshold || vx > 900) {
      fling(Decision.keep);
    } else if (_drag.dx < -_threshold || vx < -900) {
      fling(Decision.delete);
    } else {
      _animateTo(Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    final s = widget.sorter;
    final angle = (_drag.dx / 400) * 0.35 - 0.017;
    final keepOpacity = (_drag.dx / _threshold).clamp(0.0, 1.0);
    final delOpacity = (-_drag.dx / _threshold).clamp(0.0, 1.0);
    final origId = s.duplicateOf[a.id];
    final orig = origId == null ? null : s.byId(origId);
    final size = s.sizes[a.id];

    return GestureDetector(
      onTap: widget.onOpen,
      onPanUpdate: (d) => setState(() => _drag += d.delta),
      onPanEnd: _onEnd,
      child: Transform.translate(
        offset: _drag,
        child: Transform.rotate(
          angle: angle,
          child: LayoutBuilder(
            builder: (context, c) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: c.maxWidth,
                    height: c.maxHeight,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    decoration: BoxDecoration(color: Palette.card, boxShadow: paperShadow(1.6)),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AssetThumb(a, size: 1080, whole: true),
                              if (s.isVideo(a)) ...[
                                Center(
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Palette.card, width: 2),
                                      color: const Color(0x33000000),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, color: Palette.card, size: 36),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Text(
                                    formatDuration(a.duration),
                                    style: const TextStyle(color: Palette.card, fontSize: 12, shadows: [Shadow(blurRadius: 4)]),
                                  ),
                                ),
                              ] else
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x55000000)),
                                    child: const Icon(Icons.open_in_full_rounded, color: Palette.card, size: 18),
                                  ),
                                ),
                              Positioned(
                                top: 22,
                                left: 16,
                                child: Opacity(opacity: delOpacity, child: _Stamp(tr('حذف', 'DELETE'), Palette.red, -0.2)),
                              ),
                              Positioned(
                                top: 22,
                                right: 16,
                                child: Opacity(opacity: keepOpacity, child: _Stamp(tr('إبقاء', 'KEEP'), Palette.blue, 0.17)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 80,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatDate(s.dateOf(a)), style: hand(22)),
                                Text(
                                  [s.isVideo(a) ? tr('فيديو', 'Video') : tr('صورة', 'Photo'), if (size != null) formatBytes(size)].join(' · '),
                                  style: const TextStyle(fontSize: 11, color: Palette.muted),
                                ),
                                if (s.addedLater(a))
                                  Text(
                                    tr('أُضيفت إلى الجهاز في ${formatDate(a.createDateTime)}', 'Added to device ${formatDate(a.createDateTime)}'),
                                    style: const TextStyle(fontSize: 10.5, color: Palette.muted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else if (s.dateChecked(a) && s.takenDate(a) == null)
                                  Text(
                                    tr('تاريخ التصوير غير معروف، هذا تاريخ إضافتها', 'Original date unknown, showing date added'),
                                    style: const TextStyle(fontSize: 10.5, color: Palette.muted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (orig != null)
                    Positioned(
                      top: -18,
                      left: -12,
                      child: Transform.rotate(
                        angle: -0.14,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            Container(
                              width: 96,
                              padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                              decoration: BoxDecoration(color: Palette.card, boxShadow: paperShadow()),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(width: 84, height: 66, child: AssetThumb(orig, size: 200)),
                                  Text(tr('مكررة', 'Duplicate'), style: hand(14, color: Palette.red)),
                                ],
                              ),
                            ),
                            const Positioned(top: -9, child: Tape(width: 40)),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp(this.text, this.color, this.angle);
  final String text;
  final Color color;
  final double angle;
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.85),
        border: Border.all(color: color, width: 3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: hand(30, color: color)),
    ),
  );
}

/// بطاقات خلفية مائلة توحي بكومة صور.
class PileBackdrop extends StatelessWidget {
  const PileBackdrop({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Stack(
      alignment: Alignment.center,
      children: [
        for (final r in [math.pi / 45, -math.pi / 60])
          Transform.rotate(
            angle: r,
            child: Container(
              width: c.maxWidth * 0.95,
              height: c.maxHeight * 0.95,
              decoration: BoxDecoration(color: Palette.card, boxShadow: paperShadow(0.6)),
            ),
          ),
      ],
    ),
  );
}
