import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../format.dart';
import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../yt.dart';

class ChannelScreen extends StatefulWidget {
  final String id;
  final String name;
  const ChannelScreen({super.key, required this.id, required this.name});
  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  Channel? channel;
  ChannelUploadsList? page;
  final items = <VideoItem>[];
  bool loading = true, more = false, end = false;
  String? error;
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    scroll.addListener(() {
      if (scroll.position.pixels > scroll.position.maxScrollExtent - 500) _more();
    });
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      channel = await yt.channels.get(widget.id);
      page = await yt.channels.getUploadsFromPage(widget.id);
      items
        ..clear()
        ..addAll(page!.map(itemFromVideo));
      end = page!.isEmpty;
    } catch (_) {
      error = 'تعذّر تحميل القناة.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _more() async {
    if (loading || more || end || page == null) return;
    setState(() => more = true);
    try {
      final n = await page!.nextPage();
      if (n == null || n.isEmpty) {
        end = true;
      } else {
        page = n;
        items.addAll(n.map(itemFromVideo));
      }
    } catch (_) {
      end = true;
    }
    if (mounted) setState(() => more = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = channel;
    return Scaffold(
      appBar: AppBar(title: Text(c?.title ?? widget.name)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: error!,
                  action: FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')))
              : ListView.builder(
                  controller: scroll,
                  itemCount: items.length + 2,
                  itemBuilder: (ctx, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: C.accent.withValues(alpha: 0.15),
                            foregroundImage: (c?.logoUrl.isNotEmpty ?? false) ? NetworkImage(c!.logoUrl) : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c?.title ?? widget.name,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                              if (c?.subscribersCount != null)
                                Text('${fmtCount(c!.subscribersCount!)} مشترك',
                                    style: TextStyle(color: mutedOf(context))),
                            ]),
                          ),
                        ]),
                      );
                    }
                    if (i == items.length + 1) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(child: more ? const CircularProgressIndicator() : const SizedBox()),
                      );
                    }
                    final v = items[i - 1];
                    return VideoRow(v, onTap: () => openVideo(context, v));
                  },
                ),
    );
  }
}
