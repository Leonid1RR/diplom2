import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:postavki/main.dart';

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
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
                              fillColor: const Color(0xFF667eea),
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
                  const Text(
                    'Убедитесь, что выбран правильный тип аккаунта',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    print('🔗 TRYING TO CONNECT TO: $baseUrl');
    debugPrint('🔗 TRYING TO CONNECT TO: $baseUrl');

    if (nameController.text.isEmpty || passwordController.text.isEmpty) {
      _showError('Пожалуйста, заполните все поля');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final String endpoint = isSupplier ? '/suppliers' : '/stores';
      final response = await http.get(Uri.parse('$baseUrl$endpoint'));

      if (response.statusCode == 200) {
        final List<dynamic> users = jsonDecode(response.body);

        dynamic foundUser;
        for (var user in users) {
          if (user['name'] == nameController.text) {
            foundUser = user;
            break;
          }
        }

        if (foundUser != null) {
          if (foundUser['password'] == passwordController.text) {
            if (!mounted) return;
            _showSuccess('Вход выполнен успешно!');

            if (isSupplier) {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => SupplierMenu(supplier: foundUser),
                ),
              );
            } else {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopMenu(store: foundUser),
                ),
              );
            }
          } else {
            _showError('Неверный пароль');
          }
        } else {
          _showError('Аккаунт с таким названием не найден');
        }
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
