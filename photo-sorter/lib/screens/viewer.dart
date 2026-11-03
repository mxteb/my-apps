import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../l10n.dart';
import '../sorter.dart';
import '../theme.dart';

/// ماذا يُعرض أسفل شاشة العرض.
enum ViewerMode {
  /// أثناء الفرز: أزرار حذف وإبقاء، وتُرجع الشاشة القرار.
  sort,

  /// في قائمة الحذف: زر استعادة، والتنقل بين الملفات بالسحب.
  review,
}

/// يعرض صورة أو فيديو بملء الشاشة قبل اتخاذ القرار.
/// في وضع الفرز تُرجع [Decision] إن اختار المستخدم، أو null إن أغلق الشاشة.
class MediaViewer extends StatefulWidget {
  const MediaViewer({super.key, required this.assets, required this.sorter, required this.mode, this.initialIndex = 0});
  final List<AssetEntity> assets;
  final Sorter sorter;
  final ViewerMode mode;
  final int initialIndex;

  static Future<Decision?> open(BuildContext context, {required List<AssetEntity> assets, required Sorter sorter, required ViewerMode mode, int index = 0}) {
    return Navigator.of(context).push<Decision>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => MediaViewer(assets: assets, sorter: sorter, mode: mode, initialIndex: index),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late final List<AssetEntity> _items = List.of(widget.assets);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  AssetEntity get _current => _items[_index];

  void _restoreCurrent() {
    widget.sorter.restore(_current);
    if (_items.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _items.removeAt(_index);
      if (_index >= _items.length) _index = _items.length - 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.blue,
        duration: const Duration(milliseconds: 1400),
        content: Text(tr('تمت الاستعادة، لن يُحذف هذا الملف', 'Restored, this file will not be deleted')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sorter;
    final a = _current;
    final size = s.sizes[a.id];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pages,
              physics: _zoomed || _items.length < 2 ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
              itemCount: _items.length,
              onPageChanged: (i) => setState(() {
                _index = i;
                _zoomed = false;
              }),
              itemBuilder: (_, i) {
                final item = _items[i];
                return s.isVideo(item)
                    ? _VideoView(key: ValueKey('v${item.id}'), asset: item, active: i == _index)
                    : _PhotoView(
                        key: ValueKey('p${item.id}'),
                        asset: item,
                        onZoom: (z) {
                          if (z != _zoomed) setState(() => _zoomed = z);
                        },
                      );
              },
            ),
          ),
          // الشريط العلوي: إغلاق + معلومات الملف
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x00000000)]),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: tr('إغلاق', 'Close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatDate(s.dateOf(a)), style: hand(20, color: Colors.white)),
                            Text(
                              [
                                s.isVideo(a) ? tr('فيديو', 'Video') : tr('صورة', 'Photo'),
                                if (size != null) formatBytes(size),
                                if (s.isDuplicate(a)) tr('مكررة', 'Duplicate'),
                              ].join(' · '),
                              style: const TextStyle(fontSize: 12, color: Color(0xCCFFFFFF)),
                            ),
                          ],
                        ),
                      ),
                      if (_items.length > 1) Text('${_index + 1} / ${_items.length}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // الأزرار السفلية
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: widget.mode == ViewerMode.sort ? _sortButtons(context) : _reviewButtons(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortButtons(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      children: [
        Expanded(
          child: _ViewerButton(label: tr('حذف', 'Delete'), color: Palette.red, onPressed: () => Navigator.pop(context, Decision.delete)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ViewerButton(label: tr('إبقاء', 'Keep'), color: Palette.blue, onPressed: () => Navigator.pop(context, Decision.keep)),
        ),
      ],
    ),
  );

  Widget _reviewButtons() => _ViewerButton(label: tr('استعادة (لا تحذفه)', "Restore (don't delete)"), color: Palette.blue, onPressed: _restoreCurrent);
}

class _ViewerButton extends StatelessWidget {
  const _ViewerButton({required this.label, required this.color, required this.onPressed});
  final String label;
  final Color color;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
      ),
      child: Text(label, textDirection: isAr ? TextDirection.rtl : TextDirection.ltr),
    ),
  );
}

/// صورة بدقة عالية مع إمكانية التكبير بإصبعين أو بالضغط مرتين.
class _PhotoView extends StatefulWidget {
  const _PhotoView({super.key, required this.asset, required this.onZoom});
  final AssetEntity asset;
  final ValueChanged<bool> onZoom;
  @override
  State<_PhotoView> createState() => _PhotoViewState();
}

class _PhotoViewState extends State<_PhotoView> {
  final _tc = TransformationController();
  late final Future<Uint8List?> _bytes = _load();
  TapDownDetails? _doubleTap;

  Future<Uint8List?> _load() {
    const maxSide = 2400;
    final w = widget.asset.orientatedWidth, h = widget.asset.orientatedHeight;
    ThumbnailSize size;
    if (w <= 0 || h <= 0) {
      size = const ThumbnailSize.square(maxSide);
    } else {
      final scale = maxSide / (w > h ? w : h);
      size = scale >= 1 ? ThumbnailSize(w, h) : ThumbnailSize((w * scale).round().clamp(1, maxSide), (h * scale).round().clamp(1, maxSide));
    }
    return widget.asset.thumbnailDataWithSize(size, quality: 92);
  }

  @override
  void initState() {
    super.initState();
    _tc.addListener(() => widget.onZoom(_tc.value.getMaxScaleOnAxis() > 1.01));
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_tc.value.getMaxScaleOnAxis() > 1.01) {
      _tc.value = Matrix4.identity();
    } else {
      final p = _doubleTap?.localPosition ?? Offset.zero;
      _tc.value = Matrix4.identity()
        ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _bytes,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator(color: Colors.white54));
      }
      final b = snap.data;
      if (b == null) {
        return Center(
          child: Text(tr('تعذر فتح الصورة', 'Could not open the photo'), style: const TextStyle(color: Colors.white70)),
        );
      }
      return GestureDetector(
        onDoubleTapDown: (d) => _doubleTap = d,
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _tc,
          minScale: 1,
          maxScale: 6,
          child: SizedBox.expand(child: Image.memory(b, fit: BoxFit.contain, gaplessPlayback: true)),
        ),
      );
    },
  );
}

/// مشغل فيديو بسيط: تشغيل/إيقاف، شريط تقدم يمكن سحبه، وكتم الصوت.
class _VideoView extends StatefulWidget {
  const _VideoView({super.key, required this.asset, required this.active});
  final AssetEntity asset;
  final bool active;
  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  VideoPlayerController? _c;
  bool _failed = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      VideoPlayerController c;
      final url = Platform.isAndroid ? await widget.asset.getMediaUrl() : null;
      if (url != null && url.startsWith('content://')) {
        c = VideoPlayerController.contentUri(Uri.parse(url));
      } else {
        final f = await widget.asset.file;
        if (f == null) throw Exception('no file');
        c = VideoPlayerController.file(f);
      }
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      c.addListener(_tick);
      setState(() => _c = c);
      if (widget.active) c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_VideoView old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active) _c?.pause();
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
      setState(() => _showControls = true);
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
    }
  }

  String _fmt(Duration d) => formatDuration(d.inSeconds);

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(tr('تعذر تشغيل هذا الفيديو', 'Could not play this video'), style: const TextStyle(color: Colors.white70)),
        ),
      );
    }
    final c = _c;
    if (c == null) return const Center(child: CircularProgressIndicator(color: Colors.white54));
    final v = c.value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        children: [
          Center(
            child: AspectRatio(aspectRatio: v.aspectRatio > 0 ? v.aspectRatio : 16 / 9, child: VideoPlayer(c)),
          ),
          if (_showControls || !v.isPlaying)
            Center(
              child: GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x66000000),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 46),
                ),
              ),
            ),
          // شريط التقدم فوق الأزرار السفلية
          Positioned(
            left: 18,
            right: 18,
            bottom: MediaQuery.paddingOf(context).bottom + 84,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  Text(_fmt(v.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 24,
                      child: Center(
                        child: VideoProgressIndicator(
                          c,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          colors: const VideoProgressColors(playedColor: Colors.white, bufferedColor: Color(0x66FFFFFF), backgroundColor: Color(0x33FFFFFF)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_fmt(v.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  IconButton(
                    tooltip: tr('الصوت', 'Sound'),
                    onPressed: () => c.setVolume(v.volume > 0 ? 0 : 1),
                    icon: Icon(v.volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
