import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:postavki/main.dart';

import 'AdminMenu.dart'; // Добавлен импорт AdminMenu
import 'ShopMenu.dart';
import 'SupplierMenu.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final String baseUrl = GlobalConfig.baseUrl;
  String appVersion = "1.2.0";

  bool isLoading = false;
  bool isSupplier = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                GlobalConfig.gradientColor1,
                GlobalConfig.gradientColor2,
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Заголовок
                    const Column(
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Вход в систему',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Войдите в свой аккаунт',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Переключатель Магазин/Поставщик
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Тип аккаунта',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ToggleButtons(
                                isSelected: [!isSupplier, isSupplier],
                                onPressed: (int index) {
                                  setState(() {
                                    isSupplier = index == 1;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                selectedColor: Colors.white,
                                fillColor: GlobalConfig.gradientColor1,
                                color: Colors.grey[600],
                                constraints: const BoxConstraints(
                                  minHeight: 50,
                                  minWidth: 120,
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    child: Text('Магазин'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    child: Text('Поставщик'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Поля ввода
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'Название',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                hintText: 'Введите название',
                                prefixIcon: const Icon(Icons.business),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),

                            const SizedBox(height: 16),

                            TextField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Пароль',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                hintText: 'Введите пароль',
                                prefixIcon: const Icon(Icons.lock),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Кнопка входа
                    isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF667eea),
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Войти'),
                            ),
                          ),

                    const SizedBox(height: 20),

                    // Дополнительная информация
                    Column(
                      children: [
                        const Text(
                          'Убедитесь, что выбран правильный тип аккаунта',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    debugPrint('🔗 TRYING TO CONNECT TO: $baseUrl');

    if (nameController.text.isEmpty || passwordController.text.isEmpty) {
      _showError('Пожалуйста, заполните все поля');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // ПЕРВОЕ: Проверяем, не пытается ли пользователь войти как администратор
      final String? savedAdminName = await GlobalConfig.getSetting(
        GlobalConfig.adminUsernameKey,
      );
      final String? savedAdminPassword = await GlobalConfig.getSetting(
        GlobalConfig.adminPasswordKey,
      );

      // Устанавливаем значения по умолчанию если настройки не сохранены
      final String adminName = savedAdminName ?? 'admin';
      final String adminPassword = savedAdminPassword ?? 'admin';

      // Проверяем введенные данные с данными администратора
      if (nameController.text.trim() == adminName &&
          passwordController.text.trim() == adminPassword) {
        // АДМИНИСТРАТОР - перенаправляем в админ-меню
        if (!mounted) return;
        _showSuccess('Вход выполнен как администратор!');

        // Добавляем небольшую задержку для лучшего UX
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminMenu()),
        );
        return;
      }

      // ВТОРОЕ: Если не администратор, проверяем как магазин/поставщик
      final String endpoint = isSupplier ? '/suppliers/login' : '/stores/login';

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'X-App-Version': appVersion,
        },
        body: jsonEncode({
          'name': nameController.text,
          'password': passwordController.text,
        }),
      );

      // Проверяем статус 426 - требуется обновление
      if (response.statusCode == 426) {
        _showUpdateRequired();
        return;
      }

      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);

        // Сохраняем данные для автоматического входа
        await GlobalConfig.saveUserData(
          isSupplier ? 'supplier' : 'store',
          user,
        );

        if (!mounted) return;
        _showSuccess('Вход выполнен успешно!');

        if (isSupplier) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SupplierMenu(supplier: user),
            ),
          );
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ShopMenu(store: user)),
          );
        }
      } else if (response.statusCode == 401) {
        _showError('Неверное имя пользователя или пароль');
      } else if (response.statusCode == 400) {
        _showError('Название и пароль обязательны');
      } else {
        _showError('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка подключения: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showUpdateRequired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Требуется обновление'),
        content: const Text(
          'Ваша версия приложения устарела. Пожалуйста, обновите приложение для продолжения работы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
