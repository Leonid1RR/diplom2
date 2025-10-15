import 'package:flutter/material.dart';

import 'Login.dart';
import 'Registration.dart';

class LogOrReg extends StatelessWidget {
  const LogOrReg({super.key});

  @override
  Widget build(BuildContext context) {
    // Берем цвета из темы
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, secondaryColor],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Заголовок
                Column(
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Добро пожаловать',
                      style: Theme.of(context).textTheme.headlineMedium!
                          .copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Выберите действие',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white70),
                    ),
                  ],
                ),

                SizedBox(height: 60),

                // Кнопка входа
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  child: const Text("Войти"),
                ),

                SizedBox(height: 20),

                // Кнопка регистрации
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegistrationPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white, width: 2),
                  ),
                  child: const Text("Зарегистрироваться"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
