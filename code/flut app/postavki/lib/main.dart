import 'dart:async'; // Добавляем для таймера
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:postavki/widgets/LogOrReg.dart';
import 'package:postavki/widgets/ShopMenu.dart';
import 'package:postavki/widgets/SupplierMenu.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Глобальная переменная с возможностью изменения
class GlobalConfig {
  static String baseUrl = "https://qxv8dr69-3000.euw.devtunnels.ms";
  static const String adminUsernameKey = 'adminUsername';
  static const String adminPasswordKey = 'adminPassword';
  static const String baseUrlKey = 'baseUrl';

  // Ключи для цветов градиента
  static const String gradientColor1Key = 'gradientColor1';
  static const String gradientColor2Key = 'gradientColor2';

  // Цвета по умолчанию
  static Color gradientColor1 = const Color(0xFF667eea);
  static Color gradientColor2 = const Color(0xFF764ba2);

  // Ключи для сохранения состояния входа
  static const String userTypeKey = 'userType';
  static const String userDataKey = 'userData';
  static const String isLoggedInKey = 'isLoggedIn';

  // === СУЩЕСТВУЮЩИЕ МЕТОДЫ ===
  // Сохранить настройки
  static Future<void> saveSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  // Сохранить цвет
  static Future<void> saveColor(String key, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, color.value);
  }

  // Получить настройку
  static Future<String?> getSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  // Получить цвет
  static Future<Color?> getColor(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(key);
    return colorValue != null ? Color(colorValue) : null;
  }

  // Сохранить данные пользователя (НЕ МЕНЯТЬ!)
  static Future<void> saveUserData(
    String userType,
    Map<String, dynamic> userData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userTypeKey, userType);
    await prefs.setString(userDataKey, json.encode(userData));
    await prefs.setBool(isLoggedInKey, true);
  }

  // Выйти из аккаунта
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userTypeKey);
    await prefs.remove(userDataKey);
    await prefs.setBool(isLoggedInKey, false);
  }

  // Проверить, есть ли сохраненный вход
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(isLoggedInKey) ?? false;
  }

  // === НОВЫЙ МЕТОД (ВЫБРАННЫЙ ВАРИАНТ 5) ===
  // Получить сохраненные данные пользователя (универсальный метод)
  static Future<Map<String, dynamic>> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();

    final userType = prefs.getString(userTypeKey);
    final userDataString = prefs.getString(userDataKey);

    // Если нет данных - возвращаем пустой Map
    if (userType == null || userDataString == null) {
      debugPrint('❌ No saved user data found');
      return {};
    }

    try {
      final userData = json.decode(userDataString) as Map<String, dynamic>;
      debugPrint('✅ Found saved user: $userType');
      return {'type': userType, 'data': userData};
    } catch (e) {
      debugPrint('❌ Error getting saved user: $e');
      return {};
    }
  }

  // Загрузить все настройки
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Загружаем URL
    final savedUrl = prefs.getString(baseUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      baseUrl = savedUrl;
    }

    // Загружаем цвета градиента
    final savedColor1 = await getColor(gradientColor1Key);
    if (savedColor1 != null) {
      gradientColor1 = savedColor1;
    }

    final savedColor2 = await getColor(gradientColor2Key);
    if (savedColor2 != null) {
      gradientColor2 = savedColor2;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Настройка системной панели (статус-бара)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Прозрачный статус-бар
      statusBarIconBrightness: Brightness.dark, // Темные иконки
      statusBarBrightness: Brightness.light, // Светлый фон для iOS
      systemNavigationBarColor:
          Colors.white, // Цвет нижней навигационной панели
      systemNavigationBarIconBrightness:
          Brightness.dark, // Темные иконки навигации
    ),
  );

  // Запрещаем поворот экрана (опционально)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await GlobalConfig.loadSettings();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  Widget? _initialScreen;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Используем новый метод getSavedUser
    final savedUser = await GlobalConfig.getSavedUser();

    // Проверяем, есть ли данные
    if (savedUser.isNotEmpty) {
      final userType = savedUser['type'];
      final userData = savedUser['data'];

      debugPrint('🔄 Auto-login for: $userType');

      if (userType == 'supplier') {
        _initialScreen = SupplierMenu(supplier: userData);
      } else if (userType == 'store') {
        _initialScreen = ShopMenu(store: userData);
      } else {
        _initialScreen = const LogOrReg();
      }
    } else {
      debugPrint('🔐 No auto-login, showing login screen');
      _initialScreen = const LogOrReg();
    }

    // Задержка для отображения сплеш-скрина (минимум 2 секунды)
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _isLoading
          ? const SplashScreen() // Используем отдельный виджет для сплеш-скрина
          : _initialScreen!,
    );
  }
}

// Новый виджет для Splash Screen
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [GlobalConfig.gradientColor1, GlobalConfig.gradientColor2],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ваша картинка логотипа
            Image.asset(
              'assets/logo.png', // Укажите путь к вашей картинке
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),

            // Анимированный индикатор загрузки
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),

            const SizedBox(height: 20),

            // Текст (опционально)
            const Text(
              'Поставки',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
