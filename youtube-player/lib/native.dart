import 'package:flutter/services.dart';

/// Thin wrapper over the Android side (ExoPlayer service, muxer, media store).
class Native {
  static const _ch = MethodChannel('shoof/native');

  static Future<int> init() async => (await _ch.invokeMethod<int>('init')) ?? -1;
  static Future<String?> takeLink() => _ch.invokeMethod<String>('takeLink');
  static void onLink(void Function(String) cb) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) cb(call.arguments as String);
    });
  }

  static Future<void> open({
    String? video,
    String? audio,
    required String title,
    required String artist,
    String? art,
    int startMs = 0,
    String? ua,
  }) =>
      _ch.invokeMethod('open', {
        'video': video,
        'audio': audio,
        'title': title,
        'artist': artist,
        'art': art,
        'start': startMs,
        'ua': ua,
      });

  static Future<void> play() => _ch.invokeMethod('play');
  static Future<void> pause() => _ch.invokeMethod('pause');
  static Future<void> stop() => _ch.invokeMethod('stop');
  static Future<void> seek(int ms) => _ch.invokeMethod('seek', {'ms': ms});
  static Future<void> speed(double v) => _ch.invokeMethod('speed', {'v': v});
  static Future<Map> state() async =>
      (await _ch.invokeMethod<Map>('state')) ?? const {};
  static Future<void> keepOn(bool v) => _ch.invokeMethod('keepOn', {'v': v});
  static Future<void> share(String text) => _ch.invokeMethod('share', {'text': text});
  static Future<void> mux(String video, String audio, String out) =>
      _ch.invokeMethod('mux', {'video': video, 'audio': audio, 'out': out});
  static Future<String> save(String path, String name, String mime, bool audio) async =>
      (await _ch.invokeMethod<String>(
          'save', {'path': path, 'name': name, 'mime': mime, 'audio': audio}))!;
  static Future<void> delete(String uri) => _ch.invokeMethod('delete', {'uri': uri});
}
