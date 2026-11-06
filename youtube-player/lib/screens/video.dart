import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../downloads.dart';
import '../format.dart';
import '../main.dart';
import '../native.dart';
import '../player.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../yt.dart';
import 'channel.dart';
import 'web.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  static final openCount = ValueNotifier<int>(0);

  static bool _opening = false;
  static void open(BuildContext context) {
    if (openCount.value > 0 || _opening) return;
    _opening = true;
    Future.delayed(const Duration(milliseconds: 400), () => _opening = false);
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const VideoScreen()));
  }

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final p = PlayerCtl.i;
  String? _loadedFor;
  Video? full;
  Channel? channel;
  List<VideoItem> related = [];
  bool relatedLoading = false;
  bool descOpen = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => VideoScreen.openCount.value++);
    p.addListener(_onPlayer);
    _onPlayer();
  }

  @override
  void dispose() {
    p.removeListener(_onPlayer);
    Future.microtask(() => VideoScreen.openCount.value--);
    super.dispose();
  }

  void _onPlayer() {
    final v = p.item;
    if (v == null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (_loadedFor != v.id) {
      _loadedFor = v.id;
      _loadDetails(v);
    }
  }

  Future<void> _loadDetails(VideoItem v) async {
    setState(() {
      full = null;
      channel = null;
      related = [];
      relatedLoading = true;
      descOpen = false;
    });
    try {
      final f = await yt.videos.get(v.id);
      if (_loadedFor != v.id || !mounted) return;
      setState(() => full = f);
      unawaited(() async {
        try {
          final c = await yt.channels.get(f.channelId);
          if (_loadedFor == v.id && mounted) setState(() => channel = c);
        } catch (_) {}
      }());
      final rel = await yt.videos.getRelatedVideos(f);
      if (_loadedFor != v.id || !mounted) return;
      setState(() => related = (rel ?? const <Video>[]).map(itemFromVideo).toList());
    } catch (_) {}
    if (mounted && _loadedFor == v.id) setState(() => relatedLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          const AspectRatio(aspectRatio: 16 / 9, child: PlayerView()),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([p, Store.i]),
              builder: (context, _) => _details(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _details() {
    final v = p.item;
    if (v == null) return const SizedBox.shrink();
    final f = full;
    final muted = mutedOf(context);
    final views = f?.engagement.viewCount ?? v.views;
    final date = f?.uploadDate ?? f?.publishDate;
    final meta = [
      if (views != null) fmtViews(views),
      if (date != null) '${date.year}/${date.month}/${date.day}' else if (fmtWhen(v.when).isNotEmpty) fmtWhen(v.when),
      if (f?.engagement.likeCount != null) '${fmtCount(f!.engagement.likeCount!)} إعجاب',
    ].join(' · ');
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(f?.title ?? v.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4)),
      ),
      if (meta.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(meta, style: TextStyle(color: muted, fontSize: 12.5)),
        ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          _Action(
            icon: p.audioOnly ? Icons.videocam_rounded : Icons.headphones_rounded,
            label: p.audioOnly ? 'عرض الفيديو' : 'صوت فقط',
            onTap: p.localUri != null && p.localAudio ? null : () => p.setAudioOnly(!p.audioOnly),
          ),
          _Action(
            icon: Store.i.isFavorite(v.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: 'المفضلة',
            active: Store.i.isFavorite(v.id),
            onTap: () => Store.i.toggleFavorite(v),
          ),
          _Action(icon: Icons.download_rounded, label: 'تنزيل', onTap: () => showDownloadSheet(context, v)),
          _Action(icon: Icons.share_outlined, label: 'مشاركة', onTap: () => Native.share(v.url)),
          _Action(
            icon: Icons.public_rounded,
            label: 'صفحة يوتيوب',
            onTap: () => openWebPlayer(context, v),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      ListTile(
        onTap: v.channelId.isEmpty
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChannelScreen(id: v.channelId, name: v.author))),
        leading: CircleAvatar(
          backgroundColor: C.accent.withValues(alpha: 0.15),
          foregroundImage: (channel?.logoUrl.isNotEmpty ?? false) ? NetworkImage(channel!.logoUrl) : null,
          child: Text(v.author.isEmpty ? '؟' : v.author.characters.first,
              style: const TextStyle(color: C.accent, fontWeight: FontWeight.w600)),
        ),
        title: Text(f?.author ?? v.author, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: channel?.subscribersCount != null
            ? Text('${fmtCount(channel!.subscribersCount!)} مشترك', style: TextStyle(color: muted, fontSize: 12))
            : null,
        trailing: v.channelId.isEmpty ? null : const Icon(Icons.chevron_left_rounded),
      ),
      if (f != null && f.description.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Material(
            color: Theme.of(context).brightness == Brightness.dark ? C.nightCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => descOpen = !descOpen),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SelectableText.rich(
                    TextSpan(text: f.description.trim()),
                    maxLines: descOpen ? null : 3,
                    style: const TextStyle(fontSize: 13.5, height: 1.55),
                    onTap: () => setState(() => descOpen = !descOpen),
                  ),
                  const SizedBox(height: 4),
                  Text(descOpen ? 'عرض أقل' : 'المزيد',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12.5)),
                ]),
              ),
            ),
          ),
        ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
        child: Text('مقاطع ذات صلة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      if (relatedLoading && related.isEmpty)
        const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      if (!relatedLoading && related.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('لا توجد مقاطع مقترحة.', style: TextStyle(color: muted)),
        ),
      for (final r in related) VideoRow(r, onTap: () => openVideo(context, r)),
    ]);
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  const _Action({required this.icon, required this.label, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color)),
        onPressed: onTap,
      ),
    );
  }
}

void openWebPlayer(BuildContext context, VideoItem v) {
  PlayerCtl.i.pause();
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => WebScreen.watch(v)));
}

Future<void> showDownloadSheet(BuildContext context, VideoItem v) async {
  final p = PlayerCtl.i;
  Resolved? r = p.item?.id == v.id ? p.resolved : null;
  final messenger = ScaffoldMessenger.of(context);
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: FutureBuilder<Resolved>(
        future: r != null ? Future.value(r) : resolve(v.id),
        builder: (c, snap) {
          if (snap.hasError) {
            return const Padding(
              padding: EdgeInsets.all(28),
              child: Text('هذا المقطع غير متاح للتنزيل.', textAlign: TextAlign.center),
            );
          }
          if (!snap.hasData) {
            return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
          }
          final opts = downloadOptions(snap.data!);
          if (opts.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(28),
              child: Text('لا توجد صيغة قابلة للتنزيل لهذا المقطع.', textAlign: TextAlign.center),
            );
          }
          return ListView(shrinkWrap: true, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('اختر صيغة التنزيل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            for (final o in opts)
              ListTile(
                leading: Icon(o.audio ? Icons.music_note_rounded : Icons.movie_outlined),
                title: Text(o.label),
                trailing: Text(fmtBytes(o.bytes), textDirection: TextDirection.rtl),
                onTap: () {
                  Downloads.i.add(v, o);
                  Navigator.pop(c);
                  messenger.showSnackBar(const SnackBar(content: Text('بدأ التنزيل. تابعه من صفحة التنزيلات.')));
                },
              ),
          ]);
        },
      ),
    ),
  );
}

/// The video surface with its controls. Used inline and in full screen.
class PlayerView extends StatefulWidget {
  final bool fullscreen;
  const PlayerView({super.key, this.fullscreen = false});
  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  final p = PlayerCtl.i;
  bool controls = true;
  Timer? _hide;
  double? _drag;
  String? _flash;
  Timer? _flashT;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _flashT?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && p.playing && _drag == null) setState(() => controls = false);
    });
  }

  void _tap() {
    setState(() => controls = !controls);
    if (controls) _scheduleHide();
  }

  void _seekBy(int s) {
    p.seek(p.pos + s * 1000);
    setState(() => _flash = s > 0 ? '+$s' : '$s');
    _flashT?.cancel();
    _flashT = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _fullscreen() async {
    if (widget.fullscreen) {
      Navigator.of(context).pop();
      return;
    }
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, _, _) => const FullscreenPlayer(),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        return Container(
          color: Colors.black,
          child: Stack(fit: StackFit.expand, children: [
            _surface(),
            if (p.failure == null && !_hardError)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tap,
                onDoubleTapDown: (d) {
                  final w = context.size?.width ?? 1;
                  // Screen is RTL but the timeline reads left→right: left side rewinds.
                  _seekBy(d.localPosition.dx < w / 2 ? -10 : 10);
                },
                onDoubleTap: () {},
              ),
            if (_flash != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text('$_flash ث', style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            if (p.failure == null && !_hardError && (controls || !p.playing)) _controls(),
            if ((p.loading || p.buffering) && p.failure == null && !_hardError)
              const Center(
                child: SizedBox(width: 44, height: 44, child: CircularProgressIndicator(color: Colors.white)),
              ),
          ]),
        );
      },
    );
  }

  bool get _hardError => p.playError != null && !p.playing && !p.buffering && p.pos == 0 && !p.loading;

  Widget _poster() {
    final v = p.item;
    if (v == null) return const SizedBox.shrink();
    return Image.network(v.bigThumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink());
  }

  Widget _surface() {
    final v = p.item;
    if (v == null) return const SizedBox.shrink();
    if (p.failure != null) return _failureView(p.failure!);
    if (_hardError) {
      return _message(
        'تعذّر تشغيل المقطع',
        'قد يكون يوتيوب غيّر شيئًا مؤقتًا. جرّب مرة أخرى أو افتحه عبر صفحة يوتيوب.',
        [
          _btn('إعادة المحاولة', Icons.refresh_rounded, p.retry),
          _btn('صفحة يوتيوب', Icons.public_rounded, () => openWebPlayer(context, v)),
        ],
      );
    }
    if (p.loading || p.audioOnly || p.videoW == 0) {
      return Stack(fit: StackFit.expand, children: [
        Opacity(opacity: p.audioOnly ? 0.45 : 0.8, child: _poster()),
        if (p.audioOnly && !p.loading)
          const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.headphones_rounded, color: Colors.white, size: 46),
              SizedBox(height: 6),
              Text('وضع الصوت', style: TextStyle(color: Colors.white)),
            ]),
          ),
      ]);
    }
    return Center(
      child: AspectRatio(
        aspectRatio: p.aspect,
        child: p.textureId >= 0 ? Texture(textureId: p.textureId) : const SizedBox.shrink(),
      ),
    );
  }

  Widget _failureView(ResolveError e) {
    final v = p.item!;
    switch (e.kind) {
      case FailKind.ageRestricted:
        return _message(
          'هذا المقطع مقيّد بالعمر',
          'يتطلّب يوتيوب تسجيل الدخول لتأكيد عمرك. شغّله عبر صفحة يوتيوب بحسابك.',
          [_btn('تشغيل بحسابي', Icons.lock_open_rounded, () => openWebPlayer(context, v))],
        );
      case FailKind.botCheck:
        return _message(
          'يطلب يوتيوب التحقق',
          'طلب يوتيوب تسجيل الدخول لهذا المقطع. جرّب مرة أخرى بعد قليل، أو شغّله عبر صفحة يوتيوب.',
          [
            _btn('إعادة المحاولة', Icons.refresh_rounded, p.retry),
            _btn('صفحة يوتيوب', Icons.public_rounded, () => openWebPlayer(context, v)),
          ],
        );
      case FailKind.unavailable:
        return _message('المقطع غير متاح', 'ربما حُذف أو أصبح خاصًا.', [
          _btn('صفحة يوتيوب', Icons.public_rounded, () => openWebPlayer(context, v)),
        ]);
      case FailKind.network:
        return _message('لا يوجد اتصال', 'تحقّق من اتصالك بالإنترنت.', [
          _btn('إعادة المحاولة', Icons.refresh_rounded, p.retry),
        ]);
      case FailKind.other:
        return _message('تعذّر جلب المقطع', 'جرّب مرة أخرى أو افتحه عبر صفحة يوتيوب.', [
          _btn('إعادة المحاولة', Icons.refresh_rounded, p.retry),
          _btn('صفحة يوتيوب', Icons.public_rounded, () => openWebPlayer(context, v)),
        ]);
    }
  }

  Widget _btn(String t, IconData i, VoidCallback f) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonalIcon(
          onPressed: f,
          icon: Icon(i, size: 18),
          label: Text(t),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
          ),
        ),
      );

  Widget _message(String title, String body, List<Widget> actions) {
    return Stack(fit: StackFit.expand, children: [
      Opacity(opacity: 0.25, child: _poster()),
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.5)),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, runSpacing: 6, children: actions),
          ]),
        ),
      ),
      if (!widget.fullscreen) _topBar(simple: true),
    ]);
  }

  Widget _topBar({bool simple = false}) {
    return Align(
      alignment: Alignment.topCenter,
      child: Row(children: [
        IconButton(
          color: Colors.white,
          icon: Icon(widget.fullscreen ? Icons.arrow_back_rounded : Icons.keyboard_arrow_down_rounded, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const Spacer(),
        if (!simple && p.localUri == null && p.resolved != null)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => _settingsSheet(context),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(p.audioOnly ? 'صوت' : (p.quality?.label ?? ''), textDirection: TextDirection.ltr),
          ),
        if (!simple && p.localUri != null)
          IconButton(color: Colors.white, icon: const Icon(Icons.speed_rounded), onPressed: () => _settingsSheet(context)),
      ]),
    );
  }

  Widget _controls() {
    final dur = p.dur > 0 ? p.dur : 1;
    final value = (_drag ?? p.pos.toDouble()).clamp(0, dur.toDouble()).toDouble();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87],
          stops: [0, 0.3, 0.6, 1],
        ),
      ),
      child: Stack(children: [
        _topBar(),
        if (!p.loading && !p.buffering)
          Center(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  color: Colors.white,
                  iconSize: 34,
                  icon: const Icon(Icons.replay_10_rounded),
                  onPressed: () {
                    _seekBy(-10);
                    _scheduleHide();
                  },
                ),
                const SizedBox(width: 18),
                IconButton(
                  color: Colors.white,
                  iconSize: 56,
                  icon: Icon(p.ended
                      ? Icons.replay_rounded
                      : (p.wantsPlay ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded)),
                  onPressed: () {
                    p.toggle();
                    _scheduleHide();
                  },
                ),
                const SizedBox(width: 18),
                IconButton(
                  color: Colors.white,
                  iconSize: 34,
                  icon: const Icon(Icons.forward_10_rounded),
                  onPressed: () {
                    _seekBy(10);
                    _scheduleHide();
                  },
                ),
              ]),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 4, widget.fullscreen ? 14 : 0),
              child: Row(children: [
                Text(fmtMs(value.toInt()), style: const TextStyle(color: Colors.white, fontSize: 12)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: C.accent,
                      thumbColor: C.accent,
                      inactiveTrackColor: Colors.white24,
                      secondaryActiveTrackColor: Colors.white54,
                    ),
                    child: Slider(
                      value: value,
                      max: dur.toDouble(),
                      secondaryTrackValue: p.buf.clamp(0, dur).toDouble(),
                      onChangeStart: (_) => _hide?.cancel(),
                      onChanged: (x) => setState(() => _drag = x),
                      onChangeEnd: (x) {
                        p.seek(x.toInt());
                        setState(() => _drag = null);
                        _scheduleHide();
                      },
                    ),
                  ),
                ),
                Text(p.item?.live == true ? 'مباشر' : fmtMs(p.dur), style: const TextStyle(color: Colors.white, fontSize: 12)),
                IconButton(
                  color: Colors.white,
                  icon: Icon(widget.fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                  onPressed: _fullscreen,
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  void _settingsSheet(BuildContext context) {
    final r = p.resolved;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('سرعة التشغيل', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(spacing: 6, children: [
                for (final s in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
                  ChoiceChip(
                    label: Text(s == 1.0 ? 'عادية' : '×$s'),
                    selected: p.speed == s,
                    onSelected: (_) {
                      p.setSpeed(s);
                      Navigator.pop(c);
                    },
                  ),
              ]),
            ),
            if (r != null) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('الجودة', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              ListTile(
                leading: const Icon(Icons.headphones_rounded),
                title: const Text('صوت فقط (يوفّر البيانات)'),
                trailing: p.audioOnly ? const Icon(Icons.check_rounded, color: C.accent) : null,
                onTap: () {
                  p.setAudioOnly(true);
                  Navigator.pop(c);
                },
              ),
              for (final q in r.qualities)
                ListTile(
                  leading: const Icon(Icons.hd_outlined),
                  title: Text(q.label, textDirection: TextDirection.ltr, textAlign: TextAlign.right),
                  subtitle: q.isMuxed ? const Text('الأكثر توافقًا') : null,
                  trailing: !p.audioOnly && p.quality == q ? const Icon(Icons.check_rounded, color: C.accent) : null,
                  onTap: () {
                    p.setQuality(q);
                    Navigator.pop(c);
                  },
                ),
            ],
          ]),
        ),
      ),
    );
  }
}

class FullscreenPlayer extends StatefulWidget {
  const FullscreenPlayer({super.key});
  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  @override
  void initState() {
    super.initState();
    final p = PlayerCtl.i;
    final portrait = p.videoH > p.videoW && p.videoW > 0;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(portrait
        ? [DeviceOrientation.portraitUp]
        : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.black, body: PlayerView(fullscreen: true));
  }
}
