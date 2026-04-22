import 'package:shared_preferences/shared_preferences.dart';

class HeightDisplayRepository {
  static const String _useImperialKey = 'height_display_imperial_v1';

  Future<bool> getUseImperial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useImperialKey) ?? false;
  }

  Future<void> setUseImperial(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useImperialKey, value);
  }
}

HeightDisplayRepository heightDisplayRepository() {
  return HeightDisplayRepository();
}
