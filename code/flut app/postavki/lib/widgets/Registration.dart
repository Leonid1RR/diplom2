import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart'; // или правильный путь

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  bool isSupplier = false;
  final String baseUrl = GlobalConfig.baseUrl; // Замените на ваш URL сервера

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
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
                          log("Is Select $isSupplier");
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

              // Поля для ввода данных
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

              const SizedBox(height: 16),

              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Адрес',
                  border: OutlineInputBorder(),
                  hintText: 'Введите адрес',
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  border: OutlineInputBorder(),
                  hintText: 'Введите описание',
                ),
              ),

              const SizedBox(height: 30),

              // Кнопка регистрации
              ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Зарегистрироваться',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
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
    // Очищаем контроллеры при удалении виджета
    nameController.dispose();
    passwordController.dispose();
    addressController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
