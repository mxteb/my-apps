import 'package:flutter/material.dart';

import 'format.dart';
import 'store.dart';
import 'theme.dart';

class Thumb extends StatelessWidget {
  final VideoItem v;
  final double radius;
  final bool big;
  const Thumb(this.v, {super.key, this.radius = 10, this.big = false});

  @override
  Widget build(BuildContext context) {
    final p = Store.i.positions[v.id] ?? 0;
    final frac = v.seconds > 0 ? (p / 1000 / v.seconds).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(fit: StackFit.expand, children: [
          Container(color: Theme.of(context).brightness == Brightness.dark ? C.nightCard : const Color(0xFFE9E1D6)),
          Image.network(
            big ? v.bigThumb : v.thumb,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined, color: Colors.black26),
          ),
          if (v.live || v.seconds > 0)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: v.live ? C.accent : Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  v.live ? 'مباشر' : fmtDuration(v.seconds),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                ),
              ),
            ),
          if (frac > 0.02)
            Align(
              alignment: Alignment.bottomCenter,
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 3,
                backgroundColor: Colors.white24,
                color: C.accent,
              ),
            ),
        ]),
      ),
    );
  }
}

String metaLine(VideoItem v, {bool author = true}) {
  final parts = <String>[
    if (author && v.author.isNotEmpty) v.author,
    if (v.views != null) fmtViews(v.views),
    if (fmtWhen(v.when).isNotEmpty) fmtWhen(v.when),
  ];
  return parts.join(' · ');
}

/// Big card used in search results.
class VideoCard extends StatelessWidget {
  final VideoItem v;
  final VoidCallback onTap;
  final VoidCallback? onLong;
  const VideoCard(this.v, {super.key, required this.onTap, this.onLong});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLong,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Thumb(v, big: true, radius: 14),
          const SizedBox(height: 9),
          Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, height: 1.35)),
          const SizedBox(height: 3),
          Text(metaLine(v), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: mutedOf(context))),
        ]),
      ),
    );
  }
}

/// Compact row used in lists (related, history, favourites).
class VideoRow extends StatelessWidget {
  final VideoItem v;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? extra;
  const VideoRow(this.v, {super.key, required this.onTap, this.trailing, this.extra});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Thumb(v)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.35)),
              const SizedBox(height: 3),
              Text(v.author, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: mutedOf(context))),
              Text(extra ?? metaLine(v, author: false), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: mutedOf(context))),
            ]),
          ),
          ?trailing,
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55)),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, textAlign: TextAlign.center, style: TextStyle(color: mutedOf(context), height: 1.5)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

void toast(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));
