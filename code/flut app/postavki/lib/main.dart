import 'package:flutter/material.dart';
import 'package:postavki/widgets/LogOrReg.dart';

import 'widgets/app_theme.dart';

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: LogOrReg(),
    );
  }
}
