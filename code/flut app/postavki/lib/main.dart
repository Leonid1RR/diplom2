import 'package:flutter/material.dart';
import 'package:postavki/widgets/LogOrReg.dart';

// Глобальная переменная
class GlobalConfig {
  static const String baseUrl = "http://localhost:3000";
}

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: log_or_reg(),
    );
  }
}
