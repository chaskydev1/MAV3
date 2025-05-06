import 'package:driver/utils/DarkThemePreference.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class DarkThemeProvider with ChangeNotifier {
  DarkThemePreference darkThemePreference = DarkThemePreference();
  int _darkTheme = 0;

  int get darkTheme => _darkTheme;

  set darkTheme(int value) {
    _darkTheme = value;
    darkThemePreference.setDarkTheme(value);
    notifyListeners();
  }

  bool getThem() {
    if (_darkTheme == 0) {
      return true;
    } else if (_darkTheme == 1) {
      return false;
    } else {
      return getSystemThem();
    }
  }

  bool getSystemThem() {
    var brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }
}
