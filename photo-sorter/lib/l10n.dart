import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات التطبيق العامة: اللغة ووضع اللعبة.
class AppSettings extends ChangeNotifier {
  static const _kLang = 'lang_v1';
  static const _kGame = 'game_mode_v1';

  SharedPreferences? _prefs;
  String lang = 'ar';
  bool gameMode = false;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    lang = _prefs!.getString(_kLang) ?? 'ar';
    gameMode = _prefs!.getBool(_kGame) ?? false;
  }

  void setLang(String l) {
    lang = l;
    _prefs?.setString(_kLang, l);
    notifyListeners();
  }

  void toggleLang() => setLang(lang == 'ar' ? 'en' : 'ar');

  void setGameMode(bool v) {
    gameMode = v;
    _prefs?.setBool(_kGame, v);
    notifyListeners();
  }
}

final settings = AppSettings();

bool get isAr => settings.lang == 'ar';

/// يرجع النص العربي أو الإنجليزي حسب لغة التطبيق.
String tr(String ar, String en) => isAr ? ar : en;

/// "ملفًا" بالعربي، و file/files بالإنجليزي.
String filesWord(int n) => isAr ? 'ملفًا' : (n == 1 ? 'file' : 'files');

/// عدد الألبومات بصيغة عربية صحيحة: ألبوم واحد، ألبومين، 3 ألبومات، 11 ألبومًا.
String albumsCount(int n) {
  if (!isAr) return '$n album${n == 1 ? '' : 's'}';
  if (n == 1) return 'ألبوم واحد';
  if (n == 2) return 'ألبومين';
  if (n <= 10) return '$n ألبومات';
  return '$n ألبومًا';
}
