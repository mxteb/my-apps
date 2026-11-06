import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../main.dart';
import '../store.dart';
import '../widgets.dart';
import '../yt.dart';

class PlaylistScreen extends StatefulWidget {
  final String id;
  const PlaylistScreen({super.key, required this.id});
  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  Playlist? pl;
  final items = <VideoItem>[];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      pl = await yt.playlists.get(widget.id);
      if (mounted) setState(() {});
      await for (final v in yt.playlists.getVideos(widget.id).take(300)) {
        items.add(itemFromVideo(v));
        if (items.length % 20 == 0 && mounted) setState(() {});
      }
    } catch (_) {
      if (items.isEmpty) error = 'تعذّر تحميل قائمة التشغيل.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pl?.title ?? 'قائمة تشغيل')),
      body: error != null
          ? EmptyState(icon: Icons.error_outline_rounded, title: error!)
          : items.isEmpty && loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: items.length + (loading ? 1 : 0),
                  itemBuilder: (c, i) => i == items.length
                      ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
                      : VideoRow(items[i], onTap: () => openVideo(context, items[i])),
                ),
    );
  }
}
