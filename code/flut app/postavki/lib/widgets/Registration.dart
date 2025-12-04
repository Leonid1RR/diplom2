import 'dart:convert';
import 'dart:developer' as developer; // Исправленный импорт для логирования

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart'; // Импорт для GlobalConfig

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  bool isSupplier = false;
  final String baseUrl = GlobalConfig.baseUrl;

  // Контроллеры для полей ввода
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
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
                        Icons.person_add_alt_1_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Создание аккаунта',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Заполните данные для регистрации',
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
                                developer.log(
                                  "Is Select $isSupplier",
                                ); // Исправленный лог
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

                  // Поля для ввода данных
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

                          const SizedBox(height: 16),

                          TextField(
                            controller: addressController,
                            decoration: InputDecoration(
                              labelText: 'Адрес',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hintText: 'Введите адрес',
                              prefixIcon: const Icon(Icons.location_on),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Описание',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hintText: 'Введите описание',
                              prefixIcon: const Icon(Icons.description),
                              filled: true,
                              fillColor: Colors.grey[50],
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Кнопка регистрации
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _register,
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
                      child: const Text('Зарегистрироваться'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Дополнительная информация
                  const Text(
                    'Все поля, кроме описания, обязательны для заполнения',
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

  Future<void> _register() async {
    // Валидация полей
    if (nameController.text.isEmpty ||
        passwordController.text.isEmpty ||
        addressController.text.isEmpty) {
      _showError('Пожалуйста, заполните все обязательные поля');
      return;
    }

    try {
      final Map<String, dynamic> data = {
        'name': nameController.text,
        'password': passwordController.text,
        'address': addressController.text,
        'description': descriptionController.text,
        'photo': '', // Отправляем пустую строку для фото
      };

      final String endpoint = isSupplier ? '/suppliers' : '/stores';
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        _showSuccess('Регистрация прошла успешно!');
        // Очищаем поля после успешной регистрации
        _clearFields();
        // Возвращаемся на предыдущий экран
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
      } else {
        _showError('Ошибка регистрации: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка подключения: $e');
    }
  }

  void _clearFields() {
    nameController.clear();
    passwordController.clear();
    addressController.clear();
    descriptionController.clear();
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
    // Очищаем контроллеры при удалении виджета
    nameController.dispose();
    passwordController.dispose();
    addressController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
