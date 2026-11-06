import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'store.dart';

final yt = YoutubeExplode();

/// Same user agent the extractor uses, so the stream servers accept us.
const streamUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.18 Safari/537.36';

VideoItem itemFromVideo(Video v) => VideoItem(
      id: v.id.value,
      title: v.title,
      author: v.author,
      channelId: v.channelId.value,
      seconds: v.duration?.inSeconds ?? 0,
      views: v.engagement.viewCount,
      when: v.uploadDateRaw ?? (v.uploadDate != null ? _ago(v.uploadDate!) : null),
      live: v.isLive,
    );

String _ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inDays >= 365) return '${diff.inDays ~/ 365} years ago';
  if (diff.inDays >= 30) return '${diff.inDays ~/ 30} months ago';
  if (diff.inDays >= 7) return '${diff.inDays ~/ 7} weeks ago';
  if (diff.inDays >= 1) return '${diff.inDays} days ago';
  return '${diff.inHours} hours ago';
}

/// One choice in the quality menu.
class Quality {
  final String label;
  final int height;
  final VideoOnlyStreamInfo? video;
  final AudioOnlyStreamInfo? audio;
  final MuxedStreamInfo? muxed;

  Quality({required this.label, required this.height, this.video, this.audio, this.muxed});

  bool get isMuxed => muxed != null;
  String? get videoUrl => (muxed ?? video)?.url.toString();
  String? get audioUrl => muxed != null ? null : audio?.url.toString();
}

class Resolved {
  final List<Quality> qualities;
  final AudioOnlyStreamInfo? audio;
  final MuxedStreamInfo? muxed;
  final StreamManifest manifest;
  final DateTime at = DateTime.now();

  Resolved(this.qualities, this.audio, this.muxed, this.manifest);

  Quality? pick(int wanted) {
    if (qualities.isEmpty) return null;
    // Highest quality not above the wanted height.
    for (final q in qualities) {
      if (q.height <= wanted) return q;
    }
    return qualities.last;
  }

  Quality? get muxedQuality => qualities.where((q) => q.isMuxed).firstOrNull;
}

enum FailKind { ageRestricted, botCheck, unavailable, network, other }

class ResolveError implements Exception {
  final FailKind kind;
  final String detail;
  ResolveError(this.kind, this.detail);
  @override
  String toString() => detail;
}

final _cache = <String, Resolved>{};

bool _direct(StreamInfo s) => s.fragments.isEmpty;

Future<Resolved> resolve(String id, {bool fresh = false}) async {
  final c = _cache[id];
  if (!fresh && c != null && DateTime.now().difference(c.at).inHours < 4) return c;
  StreamManifest m;
  try {
    m = await yt.videos.streams.getManifest(id);
  } on VideoUnavailableException catch (e) {
    throw ResolveError(FailKind.unavailable, e.toString());
  } on VideoUnplayableException catch (e) {
    throw _classify(e.toString());
  } on YoutubeExplodeException catch (e) {
    throw _classify(e.toString());
  } catch (e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup')) {
      throw ResolveError(FailKind.network, s);
    }
    throw _classify(s);
  }

  // Audio: prefer AAC (m4a) for widest compatibility and for muxing into mp4.
  final audios = m.audioOnly.where(_direct).toList()
    ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
  AudioOnlyStreamInfo? audio = audios
          .where((a) => a.container == StreamContainer.mp4 && (a.audioTrack?.audioIsDefault ?? true))
          .firstOrNull ??
      audios.where((a) => a.container == StreamContainer.mp4).firstOrNull ??
      audios.firstOrNull;

  final byHeight = <int, VideoOnlyStreamInfo>{};
  int rank(VideoOnlyStreamInfo v) {
    final c = v.videoCodec.toLowerCase();
    if (c.startsWith('avc')) return 3; // works everywhere
    if (c.startsWith('vp9') || c.startsWith('vp09')) return 2;
    return 0; // av01 and friends: skip unless nothing else
  }

  for (final v in m.videoOnly.where(_direct)) {
    if (rank(v) == 0) continue;
    final h = v.videoResolution.height;
    final cur = byHeight[h];
    if (cur == null ||
        rank(v) > rank(cur) ||
        (rank(v) == rank(cur) && v.framerate.framesPerSecond > cur.framerate.framesPerSecond)) {
      byHeight[h] = v;
    }
  }

  final muxed = (m.muxed.where(_direct).toList()
        ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height)))
      .firstOrNull;

  final qualities = <Quality>[];
  if (audio != null) {
    final heights = byHeight.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final h in heights) {
      final v = byHeight[h]!;
      final fps = v.framerate.framesPerSecond.round();
      qualities.add(Quality(
        label: '${h}p${fps > 30 ? fps : ''}',
        height: h,
        video: v,
        audio: audio,
      ));
    }
  }
  if (muxed != null) {
    final h = muxed.videoResolution.height;
    // Insert the muxed one at its place; it is the safest fallback.
    final q = Quality(label: '${h}p', height: h, muxed: muxed);
    final idx = qualities.indexWhere((e) => e.height == h);
    if (idx >= 0) {
      qualities.insert(idx + 1, q);
    } else {
      qualities.add(q);
      qualities.sort((a, b) => b.height.compareTo(a.height));
    }
  }
  if (qualities.isEmpty && audio == null) {
    throw ResolveError(FailKind.unavailable, 'no streams');
  }
  final r = Resolved(qualities, audio, muxed, m);
  _cache[id] = r;
  return r;
}

void forget(String id) => _cache.remove(id);

ResolveError _classify(String s) {
  final l = s.toLowerCase();
  if (l.contains('age') || l.contains('inappropriate') || l.contains('confirm your age')) {
    return ResolveError(FailKind.ageRestricted, s);
  }
  if (l.contains('bot') || l.contains('sign in')) {
    return ResolveError(FailKind.botCheck, s);
  }
  if (l.contains('unavailable') || l.contains('private') || l.contains('removed')) {
    return ResolveError(FailKind.unavailable, s);
  }
  return ResolveError(FailKind.other, s);
}

/// Pulls a video id out of anything the user pastes or shares.
String? videoIdFrom(String text) {
  final t = text.trim();
  final m = RegExp(r'(?:v=|youtu\.be/|shorts/|embed/|live/)([A-Za-z0-9_-]{11})').firstMatch(t);
  if (m != null) return m.group(1);
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(t) && !t.contains(' ') && RegExp(r'[0-9_-]').hasMatch(t)) {
    return t;
  }
  return null;
}

String? playlistIdFrom(String text) {
  final m = RegExp(r'list=([A-Za-z0-9_-]{13,})').firstMatch(text);
  return m?.group(1);
}
