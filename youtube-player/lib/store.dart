import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A video as we keep it in lists (history, favourites, search results).
class VideoItem {
  final String id;
  final String title;
  final String author;
  final String channelId;
  final int seconds;
  final int? views;
  final String? when;
  final bool live;

  const VideoItem({
    required this.id,
    required this.title,
    required this.author,
    required this.channelId,
    this.seconds = 0,
    this.views,
    this.when,
    this.live = false,
  });

  String get thumb => 'https://i.ytimg.com/vi/$id/mqdefault.jpg';
  String get bigThumb => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
  String get url => 'https://www.youtube.com/watch?v=$id';

  Map<String, dynamic> toJson() => {
        'id': id,
        't': title,
        'a': author,
        'c': channelId,
        's': seconds,
        'v': views,
        'w': when,
        'l': live,
      };

  factory VideoItem.fromJson(Map<String, dynamic> j) => VideoItem(
        id: j['id'],
        title: j['t'] ?? '',
        author: j['a'] ?? '',
        channelId: j['c'] ?? '',
        seconds: j['s'] ?? 0,
        views: j['v'],
        when: j['w'],
        live: j['l'] ?? false,
      );
}

class DownloadItem {
  final String id; // unique key
  final VideoItem video;
  final String label; // e.g. "720p" or "صوت"
  final bool audio;
  final String uri;
  final int bytes;
  final int at;

  DownloadItem({
    required this.id,
    required this.video,
    required this.label,
    required this.audio,
    required this.uri,
    required this.bytes,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'v': video.toJson(),
        'l': label,
        'a': audio,
        'u': uri,
        'b': bytes,
        't': at,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> j) => DownloadItem(
        id: j['id'],
        video: VideoItem.fromJson(Map<String, dynamic>.from(j['v'])),
        label: j['l'],
        audio: j['a'] ?? false,
        uri: j['u'],
        bytes: j['b'] ?? 0,
        at: j['t'] ?? 0,
      );
}

/// Everything the app remembers, stored only on the phone.
class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();
  late SharedPreferences _p;

  List<VideoItem> history = [];
  List<VideoItem> favorites = [];
  List<String> searches = [];
  List<DownloadItem> downloads = [];
  Map<String, int> positions = {};
  int defaultHeight = 720;
  bool backgroundPlay = true;
  bool saveHistory = true;
  bool dataSaver = false;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    history = _list('history');
    favorites = _list('favorites');
    searches = _p.getStringList('searches') ?? [];
    downloads = (_p.getStringList('downloads') ?? [])
        .map((e) => DownloadItem.fromJson(jsonDecode(e)))
        .toList();
    final pos = _p.getString('positions');
    if (pos != null) positions = Map<String, int>.from(jsonDecode(pos));
    defaultHeight = _p.getInt('defaultHeight') ?? 720;
    backgroundPlay = _p.getBool('backgroundPlay') ?? true;
    saveHistory = _p.getBool('saveHistory') ?? true;
    dataSaver = _p.getBool('dataSaver') ?? false;
  }

  List<VideoItem> _list(String k) => (_p.getStringList(k) ?? [])
      .map((e) => VideoItem.fromJson(jsonDecode(e)))
      .toList();

  void _saveList(String k, List<VideoItem> l) =>
      _p.setStringList(k, l.map((e) => jsonEncode(e.toJson())).toList());

  void addHistory(VideoItem v) {
    if (!saveHistory) return;
    history.removeWhere((e) => e.id == v.id);
    history.insert(0, v);
    if (history.length > 300) history = history.sublist(0, 300);
    _saveList('history', history);
    notifyListeners();
  }

  void removeHistory(String id) {
    history.removeWhere((e) => e.id == id);
    _saveList('history', history);
    notifyListeners();
  }

  void clearHistory() {
    history = [];
    positions = {};
    _saveList('history', history);
    _p.setString('positions', '{}');
    notifyListeners();
  }

  bool isFavorite(String id) => favorites.any((e) => e.id == id);

  void toggleFavorite(VideoItem v) {
    if (isFavorite(v.id)) {
      favorites.removeWhere((e) => e.id == v.id);
    } else {
      favorites.insert(0, v);
    }
    _saveList('favorites', favorites);
    notifyListeners();
  }

  void addSearch(String q) {
    if (!saveHistory) return;
    searches.remove(q);
    searches.insert(0, q);
    if (searches.length > 20) searches = searches.sublist(0, 20);
    _p.setStringList('searches', searches);
    notifyListeners();
  }

  void removeSearch(String q) {
    searches.remove(q);
    _p.setStringList('searches', searches);
    notifyListeners();
  }

  void clearSearches() {
    searches = [];
    _p.setStringList('searches', searches);
    notifyListeners();
  }

  void savePosition(String id, int ms) {
    if (ms <= 0) {
      positions.remove(id);
    } else {
      positions[id] = ms;
    }
    if (positions.length > 400) {
      positions.remove(positions.keys.first);
    }
    _p.setString('positions', jsonEncode(positions));
  }

  void addDownload(DownloadItem d) {
    downloads.insert(0, d);
    _saveDownloads();
  }

  void removeDownload(String id) {
    downloads.removeWhere((e) => e.id == id);
    _saveDownloads();
  }

  void _saveDownloads() {
    _p.setStringList(
        'downloads', downloads.map((e) => jsonEncode(e.toJson())).toList());
    notifyListeners();
  }

  void setDefaultHeight(int h) {
    defaultHeight = h;
    _p.setInt('defaultHeight', h);
    notifyListeners();
  }

  void setBackgroundPlay(bool v) {
    backgroundPlay = v;
    _p.setBool('backgroundPlay', v);
    notifyListeners();
  }

  void setSaveHistory(bool v) {
    saveHistory = v;
    _p.setBool('saveHistory', v);
    notifyListeners();
  }

  void setDataSaver(bool v) {
    dataSaver = v;
    _p.setBool('dataSaver', v);
    notifyListeners();
  }
}
