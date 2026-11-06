import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'native.dart';
import 'store.dart';
import 'yt.dart';

/// A choice in the download sheet.
class DownloadOption {
  final String label;
  final bool audio;
  final StreamInfo main; // video-only, muxed, or audio
  final AudioOnlyStreamInfo? extraAudio; // joined with a video-only stream
  DownloadOption(this.label, this.audio, this.main, [this.extraAudio]);

  int get bytes => main.size.totalBytes + (extraAudio?.size.totalBytes ?? 0);
}

List<DownloadOption> downloadOptions(Resolved r) {
  final out = <DownloadOption>[];
  final m = r.manifest;
  final audios = m.audioOnly.where((a) => a.fragments.isEmpty).toList()
    ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
  final aac = audios.where((a) => a.container == StreamContainer.mp4).firstOrNull;
  if (aac != null) out.add(DownloadOption('صوت فقط (m4a)', true, aac));

  final seen = <int>{};
  final videos = m.videoOnly
      .where((v) =>
          v.fragments.isEmpty &&
          v.container == StreamContainer.mp4 &&
          v.videoCodec.toLowerCase().startsWith('avc'))
      .toList()
    ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
  if (aac != null) {
    for (final v in videos) {
      final h = v.videoResolution.height;
      if (h > 1080 || !seen.add(h)) continue;
      out.add(DownloadOption('فيديو ${h}p', false, v, aac));
    }
  }
  final muxed = r.muxed;
  if (muxed != null && muxed.container == StreamContainer.mp4 && !seen.contains(muxed.videoResolution.height)) {
    out.add(DownloadOption('فيديو ${muxed.videoResolution.height}p', false, muxed));
  }
  return out;
}

class Task {
  final String key;
  final VideoItem video;
  final DownloadOption option;
  double progress = 0;
  String stage = 'ينتظر';
  String? error;
  bool cancelled = false;
  Task(this.key, this.video, this.option);
}

class Downloads extends ChangeNotifier {
  Downloads._();
  static final Downloads i = Downloads._();

  final List<Task> tasks = [];
  bool _running = false;

  void add(VideoItem v, DownloadOption o) {
    final key = '${v.id}-${o.label}-${DateTime.now().millisecondsSinceEpoch}';
    tasks.add(Task(key, v, o));
    notifyListeners();
    _pump();
  }

  void cancel(Task t) {
    t.cancelled = true;
    if (t.error != null || t.stage == 'ينتظر') tasks.remove(t);
    notifyListeners();
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    while (true) {
      final t = tasks.where((e) => e.error == null && !e.cancelled).firstOrNull;
      if (t == null) break;
      try {
        await _run(t);
        tasks.remove(t);
      } catch (e) {
        if (t.cancelled) {
          tasks.remove(t);
        } else {
          t.error = 'تعذّر التنزيل';
          t.stage = 'فشل';
        }
      }
      notifyListeners();
    }
    _running = false;
  }

  Future<void> _fetch(Task t, StreamInfo s, File f, int done, int total) async {
    final sink = f.openWrite();
    var got = 0;
    try {
      await for (final chunk in yt.videos.streams.get(s)) {
        if (t.cancelled) throw Exception('cancelled');
        sink.add(chunk);
        got += chunk.length;
        t.progress = total > 0 ? (done + got) / total : 0;
        notifyListeners();
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> _run(Task t) async {
    final dir = await getTemporaryDirectory();
    final o = t.option;
    final total = o.bytes;
    final base = '${dir.path}/${t.video.id}_${DateTime.now().millisecondsSinceEpoch}';
    final safe = t.video.title.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), ' ').trim();
    final short = safe.length > 80 ? safe.substring(0, 80) : safe;
    String finalPath;
    String name;
    String mime;
    t.stage = 'جارٍ التنزيل';
    notifyListeners();
    if (o.audio) {
      finalPath = '$base.m4a';
      await _fetch(t, o.main, File(finalPath), 0, total);
      name = '$short.m4a';
      mime = 'audio/mp4';
    } else if (o.extraAudio != null) {
      final v = File('$base.v.mp4');
      final a = File('$base.a.m4a');
      await _fetch(t, o.main, v, 0, total);
      await _fetch(t, o.extraAudio!, a, o.main.size.totalBytes, total);
      t.stage = 'جارٍ الدمج';
      notifyListeners();
      finalPath = '$base.mp4';
      await Native.mux(v.path, a.path, finalPath);
      await v.delete();
      await a.delete();
      name = '$short (${o.label.replaceAll('فيديو ', '')}).mp4';
      mime = 'video/mp4';
    } else {
      finalPath = '$base.mp4';
      await _fetch(t, o.main, File(finalPath), 0, total);
      name = '$short.mp4';
      mime = 'video/mp4';
    }
    t.stage = 'جارٍ الحفظ';
    notifyListeners();
    final size = await File(finalPath).length();
    final uri = await Native.save(finalPath, name, mime, o.audio);
    Store.i.addDownload(DownloadItem(
      id: t.key,
      video: t.video,
      label: o.audio ? 'صوت' : o.label.replaceAll('فيديو ', ''),
      audio: o.audio,
      uri: uri,
      bytes: size,
      at: DateTime.now().millisecondsSinceEpoch,
    ));
  }
}
