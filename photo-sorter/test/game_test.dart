import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_sorter/game.dart';
import 'package:photo_sorter/l10n.dart';
import 'package:photo_sorter/theme.dart';
import 'package:photo_sorter/widgets/game_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Game> _game() async {
  SharedPreferences.setMockInitialValues({});
  await settings.load();
  settings.setGameMode(true);
  final g = Game()..load(await SharedPreferences.getInstance());
  return g;
}

Future<void> _loadFonts() async {
  Future<void> fam(String name, List<String> files) async {
    final l = FontLoader(name);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await l.load();
  }

  await fam('ReadexPro', ['ReadexPro-Regular.ttf', 'ReadexPro-Medium.ttf', 'ReadexPro-SemiBold.ttf', 'ReadexPro-Bold.ttf']);
  await fam('ArefRuqaa', ['ArefRuqaa-Regular.ttf', 'ArefRuqaa-Bold.ttf']);
  final mi = Directory('${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts');
  final icons = File('${mi.path}/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}

void main() {
  test('points, combo bonus, duplicate bonus and undo', () async {
    final g = await _game();
    expect(g.onDecide(delete: false, duplicate: false, allDone: false), 10);
    expect(g.onDecide(delete: true, duplicate: true, allDone: false), 25);
    expect(g.points, 35);
    g.onUndo(delete: true, duplicate: true);
    expect(g.points, 10);
    expect(g.lifetimeSorted, 1);
    for (var i = 0; i < 9; i++) {
      g.onDecide(delete: false, duplicate: false, allDone: false);
    }
    expect(g.combo, 10);
    expect(g.points, 10 * 10 + 20); // المكافأة عند كل 10 متتالية
    expect(g.unlocked, contains('first'));
  });

  test('daily goal starts a streak and levels go up', () async {
    final g = await _game();
    final events = <GameEvent>[];
    g.events.listen(events.add);
    for (var i = 0; i < Game.dailyGoal; i++) {
      g.onDecide(delete: false, duplicate: false, allDone: false);
    }
    await Future<void>.delayed(Duration.zero);
    expect(g.goalDoneToday, isTrue);
    expect(g.currentStreak, 1);
    expect(g.level, greaterThan(1));
    expect(events.any((e) => e.icon == Icons.check_circle_rounded), isTrue);
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('render game widgets ($lang)', (tester) async {
      await tester.runAsync(_loadFonts);
      final g = await tester.runAsync(_game);
      settings.setLang(lang);
      for (var i = 0; i < 57; i++) {
        g!.onDecide(delete: i % 5 == 0, duplicate: i % 10 == 0, allDone: false);
      }
      await tester.binding.setSurfaceSize(const Size(390, 700));
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              body: RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: Palette.paper,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GameHud(game: g!),
                        const SizedBox(height: 12),
                        DailyGoalBar(game: g),
                        const SizedBox(height: 20),
                        GameCard(game: g),
                        const SizedBox(height: 20),
                        const GainFloater(points: 30, combo: 10),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 330,
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2.3,
                            children: [for (final b in badges.take(6)) BadgeTileForTest(badge: b, unlocked: g.unlocked.contains(b.id))],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('/tmp/game_$lang.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
