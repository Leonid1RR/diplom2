import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import './admin/AdminBatchesList.dart';
import './admin/AdminReviewsList.dart';
import './admin/AdminStoresList.dart';
import './admin/AdminSuppliersList.dart';
import './admin/AdminSuppliesList.dart';
import './admin/AdminSupportMessagesList.dart';

class AdminMenu extends StatefulWidget {
  const AdminMenu({super.key});

  @override
  State<AdminMenu> createState() => _AdminMenuState();
}

class _AdminMenuState extends State<AdminMenu> {
  bool _isLoading = false; // Changed to remove unused field warning
  bool _serverConnected = false;
  String _serverStatus = 'Проверка...';

  // Проверка подключения к серверу
  Future<void> _checkServerConnection() async {
    setState(() {
      _serverStatus = 'Проверка подключения...';
      _isLoading = true; // Now using the field
    });

    try {
      final response = await http
          .get(Uri.parse('${GlobalConfig.baseUrl}/stores'))
          .timeout(const Duration(seconds: 5)); // Fixed timeout usage

      setState(() {
        _serverConnected = response.statusCode == 200;
        _serverStatus = _serverConnected
            ? 'Сервер доступен'
            : 'Сервер недоступен';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _serverConnected = false;
        _serverStatus = 'Ошибка подключения: ${e.toString().split(':').first}';
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkServerConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkServerConnection,
            tooltip: 'Проверить подключение',
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Выход',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Статус сервера
            Container(
              color: _serverConnected ? Colors.green[50] : Colors.red[50],
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _serverConnected ? Icons.check_circle : Icons.error,
                    color: _serverConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _serverStatus,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _serverConnected ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          GlobalConfig.baseUrl,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                children: [
                  // Управление базой данных
                  _buildSectionCard(
                    title: 'Управление базой данных',
                    children: [
                      _buildMenuButton(
                        icon: Icons.local_shipping,
                        label: 'Поставщики',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminSuppliersList(),
                          ),
                        ),
                      ),
                      _buildMenuButton(
                        icon: Icons.store,
                        label: 'Магазины',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminStoresList(),
                          ),
                        ),
                      ),
                      _buildMenuButton(
                        icon: Icons.inventory,
                        label: 'Партии товаров',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminBatchesList(),
                          ),
                        ),
                      ),
                      _buildMenuButton(
                        icon: Icons.shopping_cart,
                        label: 'Заказы/Поставки',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminSuppliesList(),
                          ),
                        ),
                      ),
                      _buildMenuButton(
                        icon: Icons.reviews,
                        label: 'Отзывы',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminReviewsList(),
                          ),
                        ),
                      ),
                      _buildMenuButton(
                        icon: Icons.support_agent,
                        label: 'Поддержка',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminSupportMessagesList(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Настройки
                  _buildSectionCard(
                    title: 'Настройки',
                    children: [
                      _buildMenuButton(
                        icon: Icons.person,
                        label: 'Логин администратора',
                        onTap: () => _changeAdminLogin(context),
                      ),
                      _buildMenuButton(
                        icon: Icons.lock,
                        label: 'Пароль администратора',
                        onTap: () => _changeAdminPassword(context),
                      ),
                      _buildMenuButton(
                        icon: Icons.dns,
                        label: 'Адрес сервера',
                        onTap: () => _changeServerAddress(context),
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.deepPurple,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _changeAdminLogin(BuildContext context) async {
    final savedLogin = await GlobalConfig.getSetting(
      GlobalConfig.adminUsernameKey,
    );
    final controller = TextEditingController(text: savedLogin ?? 'admin');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить логин администратора'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Новый логин',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await GlobalConfig.saveSetting(
                  GlobalConfig.adminUsernameKey,
                  controller.text.trim(),
                );

                // Remove the mounted check here as we're already in a dialog callback
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Логин администратора изменен'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _changeAdminPassword(BuildContext context) async {
    final savedPassword = await GlobalConfig.getSetting(
      GlobalConfig.adminPasswordKey,
    );
    final controller = TextEditingController(text: savedPassword ?? 'admin');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить пароль администратора'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Новый пароль',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await GlobalConfig.saveSetting(
                  GlobalConfig.adminPasswordKey,
                  controller.text.trim(),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Пароль администратора изменен'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _changeServerAddress(BuildContext context) async {
    final controller = TextEditingController(text: GlobalConfig.baseUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить адрес сервера'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Адрес сервера',
                hintText: 'http(https)://serverlink.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            /*const Text(
              'Формат: http(https)://serverlink.com',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),*/
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await GlobalConfig.saveSetting(GlobalConfig.baseUrlKey, newUrl);
                GlobalConfig.baseUrl = newUrl;

                Navigator.pop(context);
                setState(() {
                  _serverStatus = 'Проверка нового адреса...';
                  _serverConnected = false;
                });
                _checkServerConnection();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Адрес сервера изменен'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Сохранить и проверить'),
          ),
        ],
      ),
    );
  }
}
