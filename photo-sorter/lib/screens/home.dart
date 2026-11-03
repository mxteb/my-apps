import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../l10n.dart';
import '../sorter.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import '../widgets/thumb.dart';
import 'review.dart';
import 'sort.dart';

/// شاشة البداية: تعرض أين توقف المستخدم وتسمح بالمتابعة.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.sorter});
  final Sorter sorter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([sorter, settings]),
      builder: (context, _) {
        if (sorter.loading) {
          return Scaffold(
            body: Center(child: Text(tr('جارٍ تحميل معرض الصور…', 'Loading your gallery…'), style: hand(24))),
          );
        }
        if (sorter.permissionDenied) return _PermissionView(sorter: sorter);
        final s = sorter;
        final title = s.hasProgress
            ? tr('توقفت آخر مرة\nعند الملف ${s.sortedCount + 1}', 'You stopped at\nfile ${s.sortedCount + 1}')
            : tr('لنرتّب\nصورك معًا', "Let's tidy\nyour photos");
        final sub = s.hasProgress
            ? tr(
                'لا تقلق، فكل ما فرزته محفوظ. بقي لك ${s.remaining} ملفًا من صورك وفيديوهاتك${_dupText(s)}.',
                "Don't worry, everything you sorted is saved. ${s.remaining} ${filesWord(s.remaining)} left${_dupText(s)}.",
              )
            : tr(
                'سنعرض عليك ${s.total} ملفًا واحدًا تلو الآخر. اسحب يمينًا للإبقاء ويسارًا للحذف${_dupText(s)}.',
                "We'll show you ${s.total} ${filesWord(s.total)} one by one. Swipe right to keep, left to delete${_dupText(s)}.",
              );
        final preview = s.assets.where((a) => !s.decisions.containsKey(a.id)).take(3).toList();

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 36, 26, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_greeting(), style: const TextStyle(fontSize: 14, color: Palette.muted)),
                      ),
                      _GameToggle(),
                      const SizedBox(width: 6),
                      _LangButton(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(title, style: hand(38)),
                  const SizedBox(height: 10),
                  Text(sub, style: const TextStyle(fontSize: 15, color: Palette.body, height: 1.8)),
                  if (s.scanning)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${tr('جارٍ البحث عن المكرر…', 'Looking for duplicates…')} ${(s.scanProgress * 100).round()}%',
                        style: const TextStyle(fontSize: 12, color: Palette.muted),
                      ),
                    ),
                  if (settings.gameMode) ...[const SizedBox(height: 14), GameCard(game: s.game)],
                  Expanded(
                    child: _Pile(preview: preview, deleteCount: s.deleteCount),
                  ),
                  SolidButton(
                    s.hasProgress ? tr('متابعة الفرز', 'Continue sorting') : tr('ابدأ الفرز', 'Start sorting'),
                    onPressed: s.total == 0 ? null : () => _open(context, SortScreen(sorter: s)),
                  ),
                  const SizedBox(height: 10),
                  OutlineInkButton(
                    tr('مراجعة ما حددته للحذف', 'Review files marked for deletion'),
                    onPressed: s.deleteCount == 0 ? null : () => _open(context, ReviewScreen(sorter: s)),
                  ),
                  if (s.hasProgress)
                    Center(
                      child: TextButton(
                        onPressed: () => _confirmReset(context),
                        child: Text(
                          tr('البدء من جديد', 'Start over'),
                          style: const TextStyle(color: Palette.muted, decoration: TextDecoration.underline),
                        ),
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

  String _dupText(Sorter s) {
    if (s.scanning) return '';
    final d = s.remainingDuplicates;
    return d == 0 ? '' : tr('، منها $d مكررة', ', $d of them duplicates');
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? tr('صباح الخير', 'Good morning') : tr('مساء الخير', 'Good evening');
  }

  void _open(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Palette.card,
        title: Text(tr('البدء من جديد؟', 'Start over?'), style: hand(26)),
        content: Text(tr('ستُمسح كل اختياراتك السابقة، ولن يُحذف أي ملف.', 'All your previous choices will be cleared. No files will be deleted.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('إلغاء', 'Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('نعم، ابدأ من جديد', 'Yes, start over'), style: const TextStyle(color: Palette.red)),
          ),
        ],
      ),
    );
    if (ok == true) sorter.resetAll();
  }
}

class _Pile extends StatelessWidget {
  const _Pile({required this.preview, required this.deleteCount});
  final List<AssetEntity> preview;
  final int deleteCount;

  @override
  Widget build(BuildContext context) {
    const angles = [0.12, -0.09, 0.05];
    const offsets = [Offset(40, 20), Offset(110, 8), Offset(170, 30)];
    return Stack(
      children: [
        for (var i = 0; i < preview.length; i++)
          Positioned(
            right: offsets[i].dx,
            top: offsets[i].dy,
            child: Transform.rotate(
              angle: angles[i],
              child: Container(
                width: 140,
                height: 170,
                padding: const EdgeInsets.fromLTRB(9, 9, 9, 30),
                decoration: BoxDecoration(color: Palette.card, boxShadow: paperShadow()),
                child: AssetThumb(preview[i], size: 300),
              ),
            ),
          ),
        if (deleteCount > 0)
          Positioned(
            left: 4,
            bottom: 12,
            child: Transform.rotate(
              angle: -0.1,
              child: Text(tr('$deleteCount للحذف ←', '$deleteCount to delete ←'), style: hand(18, color: Palette.red)),
            ),
          ),
      ],
    );
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({required this.sorter});
  final Sorter sorter;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr('نحتاج إذنك', 'We need your permission'), style: hand(36), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              tr(
                'لكي نعرض عليك صورك وفيديوهاتك، اسمح للتطبيق بالوصول إلى معرض الصور من الإعدادات.',
                'To show you your photos and videos, allow the app to access your gallery in Settings.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Palette.body, height: 1.8),
            ),
            const SizedBox(height: 12),
            _LangButton(),
            const SizedBox(height: 24),
            SolidButton(tr('فتح الإعدادات', 'Open Settings'), onPressed: sorter.openSettings),
          ],
        ),
      ),
    ),
  );
}

/// زر تبديل اللغة.
class _LangButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: settings.toggleLang,
    style: OutlinedButton.styleFrom(
      foregroundColor: Palette.ink,
      backgroundColor: Palette.card,
      side: const BorderSide(color: Palette.ink, width: 1.2),
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: const StadiumBorder(),
    ),
    child: Text(isAr ? 'English' : 'العربية', style: const TextStyle(fontSize: 13)),
  );
}

/// زر تشغيل وضع اللعبة وإيقافه.
class _GameToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final on = settings.gameMode;
    return Tooltip(
      message: tr('وضع اللعبة', 'Game mode'),
      child: OutlinedButton.icon(
        onPressed: () {
          settings.setGameMode(!on);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Palette.ink,
                content: Text(
                  !on
                      ? tr('وضع اللعبة يعمل: اجمع النقاط وافتح الإنجازات', 'Game mode on: earn points and unlock badges')
                      : tr('أُوقف وضع اللعبة', 'Game mode off'),
                ),
              ),
            );
        },
        icon: Icon(Icons.sports_esports_rounded, size: 18, color: on ? Palette.card : Palette.ink),
        label: Text(tr('لعبة', 'Game'), style: TextStyle(fontSize: 13, color: on ? Palette.card : Palette.ink)),
        style: OutlinedButton.styleFrom(
          backgroundColor: on ? Palette.ink : Palette.card,
          side: const BorderSide(color: Palette.ink, width: 1.2),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}
