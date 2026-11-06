import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoof/main.dart';
import 'package:shoof/player.dart';
import 'package:shoof/screens/video.dart';
import 'package:shoof/store.dart';
import 'package:shoof/yt.dart';

void main() {
  testWidgets('tabs and player render without errors', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('shoof/native'), (c) async {
      if (c.method == 'init') return 1;
      if (c.method == 'state') return {'ready': true, 'pos': 1000, 'dur': 60000, 'state': 3, 'playing': true, 'pwr': true, 'w': 0, 'h': 0};
      return null;
    });
    SharedPreferences.setMockInitialValues({});
    await Store.i.load();
    const v = VideoItem(id: 'dQw4w9WgXcQ', title: 'مقطع تجريبي بعنوان طويل جدًا لاختبار الالتفاف في السطرين', author: 'قناة', channelId: 'UC1', seconds: 213, views: 123456, when: '3 weeks ago');
    Store.i.addHistory(v);
    Store.i.addSearch('قرآن');
    await t.pumpWidget(const ShoofApp());
    await t.pump();
    for (final label in ['مكتبتي', 'التنزيلات', 'الإعدادات', 'بحث']) {
      await t.tap(find.text(label).last);
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('شاهدتَ مؤخرًا'), findsOneWidget);
    // Simulate a failure state in the player.
    final p = PlayerCtl.i;
    p.item = v;
    p.failure = ResolveError(FailKind.ageRestricted, 'x');
    navKey.currentState!.push(MaterialPageRoute(builder: (_) => const VideoScreen()));
    await t.pump(const Duration(milliseconds: 500)); await t.pump(const Duration(milliseconds: 500));
    expect(find.text('هذا المقطع مقيّد بالعمر'), findsOneWidget);
    expect(fmtTest(), isTrue);
  });
}

bool fmtTest() => videoIdFrom('https://youtu.be/dQw4w9WgXcQ?si=abc') == 'dQw4w9WgXcQ' &&
    videoIdFrom('https://www.youtube.com/shorts/dQw4w9WgXcQ') == 'dQw4w9WgXcQ' &&
    videoIdFrom('قرآن كريم') == null;
