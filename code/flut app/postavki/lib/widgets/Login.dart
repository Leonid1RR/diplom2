import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart'; // или правильный путь
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Переключатель Магазин/Поставщик
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Text('Тип аккаунта:'),
                    ToggleButtons(
                      isSelected: [!isSupplier, isSupplier],
                      onPressed: (int index) {
                        setState(() {
                          isSupplier = index == 1;
                        });
                      },
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('Магазин'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('Поставщик'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
                hintText: 'Введите название',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Пароль',
                border: OutlineInputBorder(),
                hintText: 'Введите пароль',
              ),
            ),

            const SizedBox(height: 30),

            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Войти'),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (nameController.text.isEmpty || passwordController.text.isEmpty) {
      _showError('Пожалуйста, заполните все поля');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Получаем список всех магазинов или поставщиков
      final String endpoint = isSupplier ? '/suppliers' : '/stores';
      final response = await http.get(Uri.parse('$baseUrl$endpoint'));

      if (response.statusCode == 200) {
        final List<dynamic> users = jsonDecode(response.body);

        // Ищем пользователя с совпадающим именем
        dynamic foundUser;
        for (var user in users) {
          if (user['name'] == nameController.text) {
            foundUser = user;
            break;
          }
        }

        if (foundUser != null) {
          // Проверяем пароль
          if (foundUser['password'] == passwordController.text) {
            if (!mounted) return;
            _showSuccess('Вход выполнен успешно!');

            // Переходим в соответствующее меню
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
