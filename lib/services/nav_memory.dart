import 'package:shared_preferences/shared_preferences.dart';

/// يحفظ آخر صفحة (تبويب) كان فيها المستخدم لإرجاعه إليها عند إعادة فتح التطبيق.
/// الرحلة النشطة تُستعاد من قاعدة البيانات (users/activeRide أو driverActive).
class NavMemory {
  static SharedPreferences? _p;
  static const _tabKey = 'last_tab';

  static Future<void> init() async {
    try {
      _p = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  static int tab(int max) {
    final v = _p?.getInt(_tabKey) ?? 0;
    return v < 0 || v >= max ? 0 : v;
  }

  static void saveTab(int i) {
    _p?.setInt(_tabKey, i);
  }

  static bool flag(String k) => _p?.getBool(k) ?? false;
  static void setFlag(String k, bool v) {
    _p?.setBool(k, v);
  }
}
