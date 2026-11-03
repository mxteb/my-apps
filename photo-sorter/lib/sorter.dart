import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';
import 'l10n.dart';

enum Decision { keep, delete }

enum MediaFilter { all, duplicates, photos, videos }

/// يمسك حالة الفرز كلها: قائمة الملفات، القرارات، التقدم المحفوظ، وكشف المكرر.
class Sorter extends ChangeNotifier {
  static const _kDecisions = 'decisions_v1';
  static const _kHistory = 'history_v1';
  static const _kSizes = 'sizes_v1';
  static const _kTaken = 'taken_v1';
  static const _kHashes = 'hashes_v1';
  static const _kFilter = 'filter_v1';
  static const _kStats = 'stats_v1';

  late SharedPreferences _prefs;
  final game = Game();

  /// آخر نقاط مكتسبة، لعرض +10 فوق البطاقة.
  int lastGain = 0;
  int gainTick = 0;

  bool loading = true;
  bool permissionDenied = false;

  List<AssetEntity> assets = [];
  final Map<String, Decision> decisions = {};
  final List<String> history = [];

  /// أحجام الملفات المعروفة (بالبايت)، تُحسب للملف المعروض فقط عشان الأداء.
  final Map<String, int> sizes = {};

  /// تاريخ التصوير الأصلي (ثوانٍ منذ 1970)، و0 يعني غير معروف.
  final Map<String, int> _taken = {};

  /// بصمة بصرية (dHash) لكل ملف، محفوظة عشان ما نعيد الحساب.
  final Map<String, int> _hashes = {};

  /// ملف مكرر ← الملف الأصلي اللي يشبهه.
  Map<String, String> duplicateOf = {};
  double scanProgress = 0;
  bool scanning = false;

  MediaFilter filter = MediaFilter.all;

  int totalDeleted = 0;
  int totalFreedBytes = 0;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    game.load(_prefs);
    _restore();
    final state = await PhotoManager.requestPermissionExtend();
    if (!state.hasAccess) {
      permissionDenied = true;
      loading = false;
      notifyListeners();
      return;
    }
    await _loadAssets();
    loading = false;
    notifyListeners();
    _scanDuplicates();
  }

  Future<void> openSettings() => PhotoManager.openSetting();

  Future<void> _loadAssets() async {
    final paths = await PhotoManager.getAssetPathList(onlyAll: true, type: RequestType.common);
    if (paths.isEmpty) {
      assets = [];
      return;
    }
    final all = paths.first;
    final count = await all.assetCountAsync;
    final list = <AssetEntity>[];
    const page = 500;
    for (var start = 0; start < count; start += page) {
      list.addAll(await all.getAssetListRange(start: start, end: start + page));
    }
    assets = list.where((a) => a.type == AssetType.image || a.type == AssetType.video).toList();
    final ids = assets.map((a) => a.id).toSet();
    // ملفات انحذفت من خارج التطبيق: نشيل قراراتها
    decisions.removeWhere((id, _) => !ids.contains(id));
    history.removeWhere((id) => !ids.contains(id));
  }

  // ---------------- الحفظ ----------------

  void _restore() {
    final d = _prefs.getString(_kDecisions);
    if (d != null) {
      (jsonDecode(d) as Map<String, dynamic>).forEach((k, v) => decisions[k] = Decision.values.byName(v as String));
    }
    history.addAll(_prefs.getStringList(_kHistory) ?? []);
    final tk = _prefs.getString(_kTaken);
    if (tk != null) (jsonDecode(tk) as Map<String, dynamic>).forEach((k, v) => _taken[k] = v as int);
    final s = _prefs.getString(_kSizes);
    if (s != null) (jsonDecode(s) as Map<String, dynamic>).forEach((k, v) => sizes[k] = v as int);
    final h = _prefs.getString(_kHashes);
    if (h != null) (jsonDecode(h) as Map<String, dynamic>).forEach((k, v) => _hashes[k] = int.parse(v as String));
    filter = MediaFilter.values.byName(_prefs.getString(_kFilter) ?? 'all');
    final st = _prefs.getStringList(_kStats);
    if (st != null && st.length == 2) {
      totalDeleted = int.parse(st[0]);
      totalFreedBytes = int.parse(st[1]);
    }
  }

  Future<void> _save() async {
    await _prefs.setString(_kDecisions, jsonEncode(decisions.map((k, v) => MapEntry(k, v.name))));
    await _prefs.setStringList(_kHistory, history);
    await _prefs.setString(_kSizes, jsonEncode(sizes));
    await _prefs.setString(_kTaken, jsonEncode(_taken));
  }

  // ---------------- القوائم والأرقام ----------------

  bool isDuplicate(AssetEntity a) => duplicateOf.containsKey(a.id);
  bool isVideo(AssetEntity a) => a.type == AssetType.video;

  bool _matches(AssetEntity a, MediaFilter f) => switch (f) {
    MediaFilter.all => true,
    MediaFilter.duplicates => isDuplicate(a),
    MediaFilter.photos => !isVideo(a),
    MediaFilter.videos => isVideo(a),
  };

  int countFor(MediaFilter f) => assets.where((a) => _matches(a, f)).length;

  AssetEntity? get current {
    for (final a in assets) {
      if (!decisions.containsKey(a.id) && _matches(a, filter)) return a;
    }
    return null;
  }

  AssetEntity? byId(String id) {
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  int get total => assets.length;
  int get sortedCount => decisions.length;
  int get remaining => total - sortedCount;
  int get keepCount => decisions.values.where((d) => d == Decision.keep).length;
  List<AssetEntity> get toDelete => assets.where((a) => decisions[a.id] == Decision.delete).toList();
  int get deleteCount => toDelete.length;
  int get deleteBytes => toDelete.fold(0, (s, a) => s + (sizes[a.id] ?? 0));
  bool get hasProgress => decisions.isNotEmpty;
  int get remainingDuplicates => assets.where((a) => isDuplicate(a) && !decisions.containsKey(a.id)).length;

  // ---------------- الأفعال ----------------

  void setFilter(MediaFilter f) {
    filter = f;
    _prefs.setString(_kFilter, f.name);
    notifyListeners();
  }

  void decide(AssetEntity a, Decision d) {
    decisions[a.id] = d;
    history.add(a.id);
    if (settings.gameMode) {
      lastGain = game.onDecide(delete: d == Decision.delete, duplicate: isDuplicate(a), allDone: remaining == 0);
      gainTick++;
    }
    notifyListeners();
    _save();
  }

  void undo() {
    if (history.isEmpty) return;
    final id = history.removeLast();
    final d = decisions.remove(id);
    if (settings.gameMode && d != null) game.onUndo(delete: d == Decision.delete, duplicate: duplicateOf.containsKey(id));
    notifyListeners();
    _save();
  }

  void restore(AssetEntity a) {
    decisions[a.id] = Decision.keep;
    notifyListeners();
    _save();
  }

  Future<void> resetAll() async {
    decisions.clear();
    history.clear();
    notifyListeners();
    await _save();
  }

  /// تاريخ التصوير الأصلي إن عُرف.
  DateTime? takenDate(AssetEntity a) {
    final v = _taken[a.id];
    return (v == null || v == 0) ? null : DateTime.fromMillisecondsSinceEpoch(v * 1000);
  }

  /// هل انتهى البحث عن تاريخ التصوير لهذا الملف؟
  bool dateChecked(AssetEntity a) => _taken.containsKey(a.id);

  /// أفضل تاريخ متاح للملف: تاريخ التصوير، وإلا تاريخ إضافته للجهاز.
  DateTime dateOf(AssetEntity a) => takenDate(a) ?? a.createDateTime;

  /// هل تاريخ الإضافة للجهاز يختلف عن تاريخ التصوير بيوم أو أكثر؟
  bool addedLater(AssetEntity a) {
    final t = takenDate(a);
    return t != null && a.createDateTime.difference(t).inHours >= 24;
  }

  /// يحسب حجم الملف المعروض وتاريخ تصويره الأصلي (مرة وحدة ويحفظهما).
  Future<void> ensureSize(AssetEntity a) async {
    if (sizes.containsKey(a.id) && _taken.containsKey(a.id)) return;
    try {
      final f = await a.originFile;
      if (f != null) {
        sizes[a.id] = await f.length();
        if (!_taken.containsKey(a.id)) {
          final d = await originalDate(f, a.title, isVideo: isVideo(a), created: a.createDateTime, modified: a.modifiedDateTime);
          _taken[a.id] = d == null ? 0 : d.millisecondsSinceEpoch ~/ 1000;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  /// ينقل الملفات المحددة لسلة المحذوفات. يرجع عدد اللي انحذف فعلاً.
  Future<int> deleteMarked() async {
    final list = toDelete;
    if (list.isEmpty) return 0;
    final bytes = deleteBytes;
    List<String> done;
    if (Platform.isAndroid && await _androidSdk() >= 30) {
      done = await PhotoManager.editor.android.moveToTrash(list);
    } else {
      // iOS: تروح لـ "المحذوفة مؤخرًا" تلقائيًا
      done = await PhotoManager.editor.deleteWithIds(list.map((a) => a.id).toList());
    }
    final gone = done.toSet();
    assets.removeWhere((a) => gone.contains(a.id));
    decisions.removeWhere((id, _) => gone.contains(id));
    history.removeWhere(gone.contains);
    duplicateOf.removeWhere((id, orig) => gone.contains(id));
    totalDeleted = gone.length;
    totalFreedBytes = gone.length == list.length ? bytes : list.where((a) => gone.contains(a.id)).fold(0, (s, a) => s + (sizes[a.id] ?? 0));
    await _prefs.setStringList(_kStats, ['$totalDeleted', '$totalFreedBytes']);
    game.onDeleted(totalFreedBytes);
    await _save();
    notifyListeners();
    return gone.length;
  }

  Future<int> _androidSdk() async {
    final m = RegExp(r'SDK (\d+)').firstMatch(Platform.operatingSystemVersion);
    return m != null ? int.parse(m.group(1)!) : 30;
  }

  // ---------------- كشف المكرر ----------------

  Future<void> _scanDuplicates() async {
    scanning = true;
    notifyListeners();
    var done = 0;
    for (final a in assets) {
      if (!_hashes.containsKey(a.id)) {
        try {
          final bytes = await a.thumbnailDataWithSize(const ThumbnailSize(64, 64), quality: 80);
          if (bytes != null) {
            final h = dHash(bytes);
            if (h != null) _hashes[a.id] = h;
          }
        } catch (_) {}
      }
      done++;
      if (done % 100 == 0) {
        scanProgress = done / assets.length;
        notifyListeners();
        await _prefs.setString(_kHashes, jsonEncode(_hashes.map((k, v) => MapEntry(k, '$v'))));
      }
    }
    await _prefs.setString(_kHashes, jsonEncode(_hashes.map((k, v) => MapEntry(k, '$v'))));

    // نرتب من الأقدم للأحدث عشان الأقدم يكون "الأصل"
    final items = assets.where((a) => _hashes.containsKey(a.id)).toList()..sort((x, y) => x.createDateTime.compareTo(y.createDateTime));
    final input = items.map((a) => [a.id, _hashes[a.id]!, a.type == AssetType.video ? 1 : 0, a.duration, a.width, a.height]).toList();
    duplicateOf = await compute(findDuplicates, input);
    scanning = false;
    scanProgress = 1;
    notifyListeners();
  }
}

/// بصمة بصرية من 64 بت: نصغر الصورة 9×8 رمادي ونقارن كل بكسل بجاره.
int? dHash(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final small = img.grayscale(img.copyResize(decoded, width: 9, height: 8, interpolation: img.Interpolation.average));
  var hash = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final l = small.getPixel(x, y).r;
      final r = small.getPixel(x + 1, y).r;
      hash = (hash << 1) | (l > r ? 1 : 0);
    }
  }
  return hash;
}

int _bits(int v) {
  var c = 0;
  while (v != 0) {
    v &= v - 1;
    c++;
  }
  return c;
}

/// يشتغل في isolate منفصل. كل عنصر: [id, hash, isVideo, duration, width, height].
/// يرجع خريطة: الملف المكرر ← أول ملف يشبهه.
Map<String, String> findDuplicates(List<List<Object>> items, {int threshold = 4}) {
  final result = <String, String>{};
  for (var i = 0; i < items.length; i++) {
    final a = items[i];
    if (result.containsKey(a[0])) continue;
    for (var j = i + 1; j < items.length; j++) {
      final b = items[j];
      if (result.containsKey(b[0])) continue;
      if (a[2] != b[2]) continue; // صورة مع فيديو لا
      if (a[2] == 1 && ((a[3] as int) - (b[3] as int)).abs() > 1) continue; // فيديو بمدة مختلفة
      final ra = (a[4] as int) / ((a[5] as int) == 0 ? 1 : a[5] as int);
      final rb = (b[4] as int) / ((b[5] as int) == 0 ? 1 : b[5] as int);
      if ((ra - rb).abs() > 0.05) continue; // أبعاد مختلفة
      if (_bits((a[1] as int) ^ (b[1] as int)) <= threshold) result[b[0] as String] = a[0] as String;
    }
  }
  return result;
}

/// يستخرج تاريخ التصوير الأصلي: من بيانات EXIF أولًا، ثم من اسم الملف،
/// ثم من تاريخ آخر تعديل إذا كان أقدم من تاريخ الإضافة للجهاز.
Future<DateTime?> originalDate(File f, String? name, {required bool isVideo, required DateTime created, required DateTime modified}) async {
  if (!isVideo) {
    try {
      final raf = await f.open();
      final head = await raf.read(256 * 1024);
      await raf.close();
      final d = exifDate(head);
      if (d != null) return d;
    } catch (_) {}
  }
  final fromName = dateFromName(name ?? f.path.split('/').last);
  if (fromName != null) return fromName;
  if (created.difference(modified).inHours >= 24) return modified;
  return null;
}

/// يقرأ DateTimeOriginal من رأس ملف JPEG.
DateTime? exifDate(Uint8List head) {
  try {
    final exif = img.decodeJpgExif(head);
    if (exif == null) return null;
    final raw = (exif.exifIfd[0x9003] ?? exif.exifIfd[0x9004] ?? exif.imageIfd[0x0132])?.toString();
    return parseExifDate(raw);
  } catch (_) {
    return null;
  }
}

/// "2019:05:12 18:30:05" ← DateTime
DateTime? parseExifDate(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'(\d{4})[:\-](\d{2})[:\-](\d{2})[ T](\d{2}):(\d{2}):(\d{2})').firstMatch(raw);
  if (m == null) return null;
  return _valid(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4]!), int.parse(m[5]!), int.parse(m[6]!));
}

/// أسماء شائعة مثل IMG_20190512_183005.jpg و IMG-20190512-WA0001.jpg و Screenshot_2019-05-12-18-30-05.png
DateTime? dateFromName(String name) {
  final m = RegExp(r'(?<!\d)(20\d{2}|19\d{2})[-_]?(\d{2})[-_]?(\d{2})(?:[-_ ]?(\d{2})[-_.:]?(\d{2})[-_.:]?(\d{2}))?').firstMatch(name);
  if (m == null) return null;
  return _valid(
    int.parse(m[1]!),
    int.parse(m[2]!),
    int.parse(m[3]!),
    int.tryParse(m[4] ?? '') ?? 12,
    int.tryParse(m[5] ?? '') ?? 0,
    int.tryParse(m[6] ?? '') ?? 0,
  );
}

DateTime? _valid(int y, int mo, int d, int h, int mi, int s) {
  if (y < 1990 || y > DateTime.now().year || mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || s > 59) return null;
  final dt = DateTime(y, mo, d, h, mi, s);
  return dt.month == mo ? dt : null;
}
