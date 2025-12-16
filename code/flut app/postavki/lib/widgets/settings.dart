import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String userType; // 'store' или 'supplier'
  final VoidCallback? onThemeChanged;
  final VoidCallback? onLogout;

  const SettingsPage({
    super.key,
    required this.userData,
    required this.userType,
    this.onThemeChanged,
    this.onLogout,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Color _selectedColor1 = GlobalConfig.gradientColor1;
  Color _selectedColor2 = GlobalConfig.gradientColor2;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    _nameController.text = widget.userData['name'] ?? '';
    _passwordController.text = '••••••••'; // Заглушка для пароля
    _addressController.text = widget.userData['address'] ?? '';
    _descriptionController.text = widget.userData['description'] ?? '';
  }

  Future<void> _updateAccount() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Название обязательно для заполнения');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final endpoint = widget.userType == 'supplier'
          ? '/suppliers/${widget.userData['id']}'
          : '/stores/${widget.userData['id']}';

      final Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      // Если пароль изменен (не заглушка)
      if (_passwordController.text != '••••••••' &&
          _passwordController.text.isNotEmpty) {
        data['password'] = _passwordController.text.trim();
      }

      final response = await http.put(
        Uri.parse('${GlobalConfig.baseUrl}$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        // Обновляем сохраненные данные
        final updatedUserData = Map<String, dynamic>.from(widget.userData);
        updatedUserData['name'] = _nameController.text.trim();
        updatedUserData['address'] = _addressController.text.trim();
        updatedUserData['description'] = _descriptionController.text.trim();

        await GlobalConfig.saveUserData(widget.userType, updatedUserData);

        _showSuccess('Данные аккаунта обновлены');
      } else {
        _showError('Ошибка обновления: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showColorPicker(bool isFirstColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Выберите ${isFirstColor ? 'первый' : 'второй'} цвет'),
        content: SingleChildScrollView(
          child: ColorPicker(
            onColorChanged: (color) {
              setState(() {
                if (isFirstColor) {
                  _selectedColor1 = color;
                } else {
                  _selectedColor2 = color;
                }
              });
            },
            initialColor: isFirstColor ? _selectedColor1 : _selectedColor2,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: Text(
          'Все ваши данные будут безвозвратно удалены. Это действие нельзя отменить.\n\n'
          'Удалить аккаунт ${widget.userData['name']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() => _isLoading = true);

      try {
        final endpoint = widget.userType == 'supplier'
            ? '/suppliers/${widget.userData['id']}'
            : '/stores/${widget.userData['id']}';

        final response = await http.delete(
          Uri.parse('${GlobalConfig.baseUrl}$endpoint'),
        );

        if (response.statusCode == 200) {
          await GlobalConfig.logout();
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          }
        } else {
          _showError('Ошибка удаления: ${response.statusCode}');
        }
      } catch (e) {
        _showError('Ошибка удаления: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyThemeChanges() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменение темы'),
        content: const Text(
          'Для применения изменений цвета приложение нужно перезагрузить.\n\nВы хотите перезагрузить сейчас?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),

          TextButton(
            onPressed: () async {
              await GlobalConfig.saveColor(
                GlobalConfig.gradientColor1Key,
                _selectedColor1,
              );
              await GlobalConfig.saveColor(
                GlobalConfig.gradientColor2Key,
                _selectedColor2,
              );

              GlobalConfig.gradientColor1 = _selectedColor1;
              GlobalConfig.gradientColor2 = _selectedColor2;

              Navigator.pop(context);
              if (widget.onThemeChanged != null) {
                widget.onThemeChanged!();
              }
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: const Text('Перезагрузить'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Аккаунт',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildEditableField('Название', _nameController),
            _buildEditableField(
              'Пароль',
              _passwordController,
              isPassword: true,
            ),
            _buildEditableField('Адрес', _addressController),
            _buildEditableField(
              'Описание',
              _descriptionController,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateAccount,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Обновить данные'),
              ),
            ),

            // Кнопка удаления аккаунта - ДОБАВЛЕНО
            const SizedBox(height: 20),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _deleteAccount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text('Удалить аккаунт'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesignSection() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Дизайн',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Предпросмотр текущих цветов
            Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [_selectedColor1, _selectedColor2],
                ),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: const Center(
                child: Text(
                  'Предпросмотр градиента',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Выбор цвета 1
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectedColor1,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
              ),
              title: const Text('Цвет 1'),
              trailing: const Icon(Icons.colorize),
              onTap: () => _showColorPicker(true),
            ),

            // Выбор цвета 2
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectedColor2,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
              ),
              title: const Text('Цвет 2'),
              trailing: const Icon(Icons.colorize),
              onTap: () => _showColorPicker(false),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyThemeChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Применить тему'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: isPassword && controller.text == '••••••••',
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: isPassword && controller.text == '••••••••'
              ? IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    controller.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
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
          child: SingleChildScrollView(
            child: Column(
              children: [_buildAccountSection(), _buildDesignSection()],
            ),
          ),
        ),
      ),
    );
  }
}

// Простой виджет выбора цвета
class ColorPicker extends StatefulWidget {
  final ValueChanged<Color> onColorChanged;
  final Color initialColor;

  const ColorPicker({
    super.key,
    required this.onColorChanged,
    required this.initialColor,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late Color _selectedColor;

  final List<Color> _colors = [
    const Color(0xFF667eea), // Фиолетовый
    const Color(0xFF764ba2), // Темно-фиолетовый
    Colors.blue,
    Colors.blueAccent,
    Colors.green,
    Colors.greenAccent,
    Colors.red,
    Colors.redAccent,
    Colors.orange,
    Colors.orangeAccent,
    Colors.purple,
    Colors.purpleAccent,
    Colors.teal,
    Colors.tealAccent,
    Colors.indigo,
    Colors.indigoAccent,
    Colors.pink,
    Colors.pinkAccent,
    Colors.amber,
    Colors.amberAccent,
    Colors.cyan,
    Colors.cyanAccent,
    Colors.lime,
    Colors.limeAccent,
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _colors.map((color) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = color;
            });
            widget.onColorChanged(color);
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: _selectedColor.value == color.value
                    ? Colors.white
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
