import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const introductionShownKey = 'INTRODUCTION_SHOWN';
const locationPreferenceKnownKey = 'LOCATION_PREFERENCE_KNOWN';
const locationAccessWantedKey = 'LOCATION_PREFERENCE_WANTED';

class UserPreferences extends ChangeNotifier {
  bool initialized = false;
  SharedPreferences? _prefs;

  UserPreferences() {
    _initializeAsync();
  }

  void _initializeAsync() async {
    _prefs = await SharedPreferences.getInstance();
    initialized = true;
    notifyListeners();
  }

  bool? shouldShowIntroduction() {
    if (_prefs == null) return null;
    if (!_prefs!.containsKey(introductionShownKey)) return true;
    return _prefs?.getBool(introductionShownKey);
  }

  bool? get locationPreferenceKnown {
    return _prefs?.getBool(locationPreferenceKnownKey) ?? false;
  }

  bool? get locationAccessWanted {
    return _prefs?.getBool(locationAccessWantedKey);
  }

  Future<bool> setLocationPreference(bool locationAccessWanted) async {
    _prefs ??= await SharedPreferences.getInstance();
    var success = await _prefs!.setBool(locationPreferenceKnownKey, true);
    if (!success) return false;
    var result = await _prefs!.setBool(locationAccessWantedKey, locationAccessWanted);
    notifyListeners();
    return result;
  }

  /// 清除所有偏好数据
  Future<void> clearAll() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.clear();
    initialized = false;
    notifyListeners();
  }
}