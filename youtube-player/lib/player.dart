import 'dart:async';

import 'package:flutter/foundation.dart';

import 'native.dart';
import 'store.dart';
import 'yt.dart';

/// The one playback session of the app. The native side owns the real player;
/// this mirrors its state for the UI.
class PlayerCtl extends ChangeNotifier {
  PlayerCtl._();
  static final PlayerCtl i = PlayerCtl._();

  int textureId = -1;
  VideoItem? item;
  Resolved? resolved;
  Quality? quality;
  bool audioOnly = false;
  bool loading = false;
  ResolveError? failure;
  String? playError;
  String? localUri; // set when playing a downloaded file
  bool localAudio = false;

  int pos = 0, dur = 0, buf = 0;
  bool playing = false, wantsPlay = false, buffering = false, ended = false;
  int videoW = 0, videoH = 0;
  double speed = 1.0;

  Timer? _timer;
  int _session = 0;
  int _fallbacks = 0;
  int _lastSaved = 0;

  double get aspect => videoW > 0 && videoH > 0 ? videoW / videoH : 16 / 9;
  bool get active => item != null;

  Future<void> ensureInit() async {
    if (textureId >= 0) return;
    textureId = await Native.init();
  }

  Future<void> load(VideoItem v, {bool asAudio = false}) async {
    if (item?.id == v.id && localUri == null && (resolved != null || loading)) {
      if (asAudio != audioOnly && resolved != null) await setAudioOnly(asAudio);
      return;
    }
    await _persistPosition();
    final s = ++_session;
    item = v;
    resolved = null;
    quality = null;
    failure = null;
    playError = null;
    localUri = null;
    audioOnly = asAudio || Store.i.dataSaver && asAudio;
    loading = true;
    _fallbacks = 0;
    pos = dur = buf = 0;
    videoW = videoH = 0;
    ended = false;
    notifyListeners();
    await ensureInit();
    await Native.stop();
    Store.i.addHistory(v);
    try {
      final r = await resolve(v.id);
      if (s != _session) return;
      resolved = r;
      final wanted = Store.i.dataSaver ? 360 : Store.i.defaultHeight;
      quality = r.pick(wanted);
      loading = false;
      await _open(start: _resumePoint(v));
    } on ResolveError catch (e) {
      if (s != _session) return;
      loading = false;
      failure = e;
      notifyListeners();
    }
    _startPolling();
  }

  /// Plays a downloaded file.
  Future<void> loadLocal(DownloadItem d) async {
    await _persistPosition();
    ++_session;
    await ensureInit();
    item = d.video;
    resolved = null;
    quality = null;
    failure = null;
    playError = null;
    localUri = d.uri;
    localAudio = d.audio;
    audioOnly = d.audio;
    loading = false;
    pos = dur = buf = 0;
    videoW = videoH = 0;
    notifyListeners();
    await Native.open(
      video: d.audio ? null : d.uri,
      audio: d.audio ? d.uri : null,
      title: d.video.title,
      artist: d.video.author,
      art: d.video.bigThumb,
      startMs: _resumePoint(d.video),
    );
    _startPolling();
  }

  int _resumePoint(VideoItem v) {
    final p = Store.i.positions[v.id] ?? 0;
    if (v.seconds > 0 && p > (v.seconds - 15) * 1000) return 0;
    return p;
  }

  Future<void> _open({int start = 0}) async {
    final v = item;
    final r = resolved;
    if (v == null || r == null) return;
    playError = null;
    ended = false;
    String? video, audio;
    if (audioOnly) {
      audio = r.audio?.url.toString() ?? r.muxed?.url.toString();
    } else {
      final q = quality ?? r.muxedQuality;
      if (q == null) {
        audio = r.audio?.url.toString();
        audioOnly = true;
      } else {
        video = q.videoUrl;
        audio = q.audioUrl;
      }
    }
    notifyListeners();
    await Native.open(
      video: video,
      audio: audio,
      title: v.title,
      artist: v.author,
      art: v.bigThumb,
      startMs: start,
      ua: streamUserAgent,
    );
    if (speed != 1.0) await Native.speed(speed);
  }

  Future<void> setQuality(Quality q) async {
    quality = q;
    audioOnly = false;
    _fallbacks = 0;
    await _open(start: pos);
  }

  Future<void> setAudioOnly(bool v) async {
    if (localUri != null) return;
    audioOnly = v;
    _fallbacks = 0;
    await _open(start: pos);
  }

  Future<void> setSpeed(double v) async {
    speed = v;
    await Native.speed(v);
    notifyListeners();
  }

  Future<void> toggle() async {
    if (ended) {
      await seek(0);
      await Native.play();
    } else if (wantsPlay) {
      await Native.pause();
    } else {
      await Native.play();
    }
    wantsPlay = !wantsPlay;
    notifyListeners();
  }

  Future<void> pause() => Native.pause();

  Future<void> seek(int ms) async {
    final d = dur > 0 ? dur : ms;
    pos = ms.clamp(0, d);
    ended = false;
    notifyListeners();
    await Native.seek(pos);
  }

  Future<void> retry() async {
    final v = item;
    if (v == null) return;
    forget(v.id);
    item = null;
    await load(v);
  }

  Future<void> close() async {
    await _persistPosition();
    ++_session;
    _timer?.cancel();
    _timer = null;
    item = null;
    resolved = null;
    quality = null;
    failure = null;
    localUri = null;
    playing = wantsPlay = false;
    notifyListeners();
    await Native.stop();
    await Native.keepOn(false);
  }

  Future<void> _persistPosition() async {
    final v = item;
    if (v == null || pos <= 0) return;
    Store.i.savePosition(v.id, ended ? 0 : pos);
  }

  void _startPolling() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 400), (_) => _poll());
  }

  bool _keepOn = false;

  Future<void> _poll() async {
    if (item == null) return;
    final m = await Native.state();
    if (m['ready'] != true) return;
    final st = m['state'] as int? ?? 1; // 1 idle, 2 buffering, 3 ready, 4 ended
    pos = (m['pos'] as num?)?.toInt() ?? 0;
    final d = (m['dur'] as num?)?.toInt() ?? 0;
    dur = d < 0 ? (item!.seconds * 1000) : d;
    buf = (m['buf'] as num?)?.toInt() ?? 0;
    playing = m['playing'] == true;
    wantsPlay = m['pwr'] == true;
    buffering = st == 2;
    ended = st == 4;
    final w = (m['w'] as num?)?.toInt() ?? 0;
    final h = (m['h'] as num?)?.toInt() ?? 0;
    final ratio = (m['ratio'] as num?)?.toDouble() ?? 1.0;
    videoW = (w * ratio).round();
    videoH = h;
    final err = m['err'] as String?;
    if (err != null && playError == null) {
      playError = err;
      await _onPlayError();
    }
    final on = playing && !audioOnly;
    if (on != _keepOn) {
      _keepOn = on;
      Native.keepOn(on);
    }
    if (DateTime.now().millisecondsSinceEpoch - _lastSaved > 5000) {
      _lastSaved = DateTime.now().millisecondsSinceEpoch;
      _persistPosition();
    }
    notifyListeners();
  }

  Future<void> _onPlayError() async {
    final r = resolved;
    if (r == null || localUri != null) return;
    _fallbacks++;
    // Separate video+audio failed: fall back to the single muxed stream.
    final mq = r.muxedQuality;
    if (_fallbacks == 1 && !audioOnly && mq != null && quality != mq) {
      quality = mq;
      await _open(start: pos);
      return;
    }
    // Links may have expired: fetch fresh ones once.
    if (_fallbacks <= 2) {
      try {
        final fresh = await resolve(item!.id, fresh: true);
        resolved = fresh;
        quality = audioOnly ? null : (fresh.muxedQuality ?? fresh.pick(360));
        await _open(start: pos);
      } catch (_) {}
    }
  }
}
