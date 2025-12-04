import 'package:flutter/material.dart';
import 'package:postavki/widgets/LogOrReg.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Глобальная переменная с возможностью изменения
class GlobalConfig {
  static String baseUrl = "https://qxv8dr69-3000.euw.devtunnels.ms";
  static const String adminUsernameKey = 'adminUsername';
  static const String adminPasswordKey = 'adminPassword';
  static const String baseUrlKey = 'baseUrl';

  // Сохранить настройки
  static Future<void> saveSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  // Получить настройку
  static Future<String?> getSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  // Загрузить все настройки
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(baseUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      baseUrl = savedUrl;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GlobalConfig.loadSettings();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: LogOrReg());
  }
}
