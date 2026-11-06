import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'native.dart';
import 'player.dart';
import 'screens/downloads_screen.dart';
import 'screens/home.dart';
import 'screens/library.dart';
import 'screens/playlist.dart';
import 'screens/settings.dart';
import 'screens/video.dart';
import 'store.dart';
import 'theme.dart';
import 'yt.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.i.load();
  runApp(const ShoofApp());
}

class ShoofApp extends StatelessWidget {
  const ShoofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شوف',
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Shell(),
    );
  }
}

/// Opens the watch page (or brings back the one already playing).
void openVideo(BuildContext context, VideoItem v, {bool audio = false}) {
  PlayerCtl.i.load(v, asAudio: audio);
  VideoScreen.open(context);
}

/// Handles a link shared from another app or opened from the browser.
void openLink(String text) {
  final ctx = navKey.currentContext;
  if (ctx == null) return;
  final id = videoIdFrom(text);
  if (id != null) {
    () async {
      try {
        final v = await yt.videos.get(id);
        if (!ctx.mounted) return;
        openVideo(ctx, itemFromVideo(v));
      } catch (_) {
        if (!ctx.mounted) return;
        openVideo(ctx, VideoItem(id: id, title: 'مقطع', author: '', channelId: ''));
      }
    }();
    return;
  }
  final pl = playlistIdFrom(text);
  if (pl != null) {
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => PlaylistScreen(id: pl)));
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;
  final homeKey = GlobalKey<HomeScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PlayerCtl.i.ensureInit();
    Native.onLink(openLink);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final l = await Native.takeLink();
      if (l != null) openLink(l);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final p = PlayerCtl.i;
    if (state == AppLifecycleState.paused && p.active && !Store.i.backgroundPlay && !p.audioOnly) {
      p.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: tab == 0 && !(homeKey.currentState?.hasQuery ?? false),
        onPopInvokedWithResult: (did, _) {
          if (did) return;
          if (tab != 0) {
            setState(() => tab = 0);
          } else {
            homeKey.currentState?.clearQuery();
            setState(() {});
          }
        },
        child: Scaffold(
          body: IndexedStack(index: tab, children: [
            HomeScreen(key: homeKey, onChanged: () => setState(() {})),
            const LibraryScreen(),
            const DownloadsScreen(),
            const SettingsScreen(),
          ]),
          bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) {
                if (i == tab && i == 0) homeKey.currentState?.focusSearch();
                setState(() => tab = i);
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.search_rounded), label: 'بحث'),
                NavigationDestination(
                    icon: Icon(Icons.video_library_outlined),
                    selectedIcon: Icon(Icons.video_library),
                    label: 'مكتبتي'),
                NavigationDestination(
                    icon: Icon(Icons.download_outlined),
                    selectedIcon: Icon(Icons.download),
                    label: 'التنزيلات'),
                NavigationDestination(
                    icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'الإعدادات'),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([PlayerCtl.i, VideoScreen.openCount]),
      builder: (context, _) {
        final p = PlayerCtl.i;
        final v = p.item;
        if (v == null || VideoScreen.openCount.value > 0) return const SizedBox.shrink();
        final dark = Theme.of(context).brightness == Brightness.dark;
        final frac = p.dur > 0 ? (p.pos / p.dur).clamp(0.0, 1.0) : 0.0;
        return Material(
          color: dark ? C.nightCard : Colors.white,
          child: InkWell(
            onTap: () => VideoScreen.open(context),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LinearProgressIndicator(value: frac, minHeight: 2, backgroundColor: Colors.transparent),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(v.thumb, width: 80, height: 45, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(width: 80, height: 45)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5)),
                      Text(p.audioOnly ? '${v.author} · صوت فقط' : v.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: mutedOf(context))),
                    ]),
                  ),
                  if (p.loading || p.buffering)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                    )
                  else
                    IconButton(
                      onPressed: p.toggle,
                      icon: Icon(p.wantsPlay ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
                    ),
                  IconButton(onPressed: p.close, icon: const Icon(Icons.close_rounded)),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
