import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../theme.dart';

/// صورة مصغرة لملف من المعرض، مع تخزين مؤقت بسيط.
class AssetThumb extends StatefulWidget {
  const AssetThumb(this.asset, {super.key, this.size = 400, this.fit = BoxFit.cover, this.whole = false});
  final AssetEntity asset;
  final int size;
  final BoxFit fit;

  /// يعرض الصورة كاملة بدون قص، والفراغ حولها نسخة مغبشة منها.
  final bool whole;

  @override
  State<AssetThumb> createState() => _AssetThumbState();
}

class _AssetThumbState extends State<AssetThumb> {
  static final Map<String, Uint8List> _cache = {};
  Future<Uint8List?>? _future;

  String get _key => '${widget.asset.id}@${widget.size}${widget.whole ? 'w' : ''}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AssetThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id || oldWidget.size != widget.size || oldWidget.whole != widget.whole) _load();
  }

  void _load() {
    if (_cache.containsKey(_key)) {
      _future = Future.value(_cache[_key]);
      return;
    }
    final key = _key;
    _future = widget.asset.thumbnailDataWithSize(_requestSize(), quality: 85).then((b) {
      if (b != null) {
        if (_cache.length > 300) _cache.remove(_cache.keys.first);
        _cache[key] = b;
      }
      return b;
    });
  }

  /// في وضع العرض الكامل نطلب الصورة بنفس نسبة أبعادها الأصلية.
  ThumbnailSize _requestSize() {
    if (!widget.whole) return ThumbnailSize.square(widget.size);
    final w = widget.asset.orientatedWidth, h = widget.asset.orientatedHeight;
    if (w <= 0 || h <= 0) return ThumbnailSize.square(widget.size);
    final scale = widget.size / (w > h ? w : h);
    if (scale >= 1) return ThumbnailSize(w, h);
    return ThumbnailSize((w * scale).round().clamp(1, widget.size), (h * scale).round().clamp(1, widget.size));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _future,
    builder: (context, snap) {
      final bytes = snap.data;
      if (bytes == null) return const ColoredBox(color: Color(0xFFD9CFBF));
      if (!widget.whole) {
        return Image.memory(bytes, fit: widget.fit, gaplessPlayback: true, width: double.infinity, height: double.infinity);
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22, tileMode: TileMode.clamp),
              child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 120),
            ),
          ),
          const ColoredBox(color: Color(0x26000000)),
          Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
        ],
      );
    },
  );
}

/// شريط لاصق صغير فوق الصور.
class Tape extends StatelessWidget {
  const Tape({super.key, this.width = 44, this.angle = 0.06});
  final double width;
  final double angle;
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(width: width, height: 16, color: Palette.tape),
  );
}
