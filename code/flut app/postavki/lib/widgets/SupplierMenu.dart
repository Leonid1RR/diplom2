import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import 'settings.dart'; // ДОБАВЬТЕ ЭТОТ ИМПОРТ

class SupplierMenu extends StatefulWidget {
  final Map<String, dynamic> supplier;

  const SupplierMenu({super.key, required this.supplier});

  @override
  State<SupplierMenu> createState() => _SupplierMenuState();
}

class _SupplierMenuState extends State<SupplierMenu> {
  final String baseUrl = GlobalConfig.baseUrl;
  int _currentIndex = 0;

  // Данные
  List<dynamic> supplies = [];
  List<dynamic> batches = [];
  List<dynamic> reviews = [];
  Map<String, dynamic> supplierData = {};

  // Фильтры и сортировка для заказов
  String _statusFilter = 'Все';
  String _sortBy = 'id';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadSupplierData();
    await _loadSupplies();
    await _loadBatches();
    await _loadReviews();
  }

  Future<void> _loadSupplierData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/suppliers'));
      if (response.statusCode == 200) {
        final List<dynamic> suppliers = jsonDecode(response.body);
        final currentSupplier = suppliers.firstWhere(
          (s) => s['id'] == widget.supplier['id'],
          orElse: () => widget.supplier,
        );
        setState(() {
          supplierData = currentSupplier;
        });
      }
    } catch (e) {
      debugPrint('Error loading supplier data: $e');
    }
  }

  Future<void> _loadSupplies() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/supplies'));
      if (response.statusCode == 200) {
        final List<dynamic> allSupplies = jsonDecode(response.body);
        setState(() {
          supplies = allSupplies
              .where(
                (supply) => supply['fromSupplierId'] == widget.supplier['id'],
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading supplies: $e');
    }
  }

  Future<void> _loadBatches() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/batches'));
      if (response.statusCode == 200) {
        final List<dynamic> allBatches = jsonDecode(response.body);
        setState(() {
          batches = allBatches
              .where((batch) => batch['supplierId'] == widget.supplier['id'])
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading batches: $e');
    }
  }

  Future<void> _loadReviews() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reviews/supplier/${widget.supplier['id']}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          reviews = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    }
  }

  // Фильтрация и сортировка заказов
  List<dynamic> get _filteredAndSortedSupplies {
    List<dynamic> filtered = supplies;

    // Применяем фильтр по статусу
    if (_statusFilter != 'Все') {
      filtered = filtered
          .where((supply) => supply['status'] == _statusFilter)
          .toList();
    }

    // Применяем сортировка
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'id':
          return b['id'].compareTo(a['id']); // Новые сверху
        case 'store':
          return (a['toStore']?['name'] ?? '').compareTo(
            b['toStore']?['name'] ?? '',
          );
        case 'status':
          return a['status'].compareTo(b['status']);
        default:
          return 0;
      }
    });

    return filtered;
  }

  // Вкладка заказов с фильтрацией и сортировкой
  Widget _buildOrdersTab() {
    return Column(
      children: [
        // Подложка для фильтров и сортировки
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    items: ['Все', 'оформлен', 'отправлен', 'получено']
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(_getStatusText(status)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _statusFilter = value!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Статус',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sortBy,
                    items: [
                      DropdownMenuItem(value: 'id', child: Text('По номеру')),
                      DropdownMenuItem(
                        value: 'store',
                        child: Text('По магазину'),
                      ),
                      DropdownMenuItem(
                        value: 'status',
                        child: Text('По статусу'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _sortBy = value!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadSupplies,
            child: _filteredAndSortedSupplies.isEmpty
                ? const Center(child: Text('Нет заказов'))
                : ListView.builder(
                    itemCount: _filteredAndSortedSupplies.length,
                    itemBuilder: (context, index) {
                      final supply = _filteredAndSortedSupplies[index];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: Text('Заказ #${supply['id']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Магазин: ${supply['toStore']?['name'] ?? 'Неизвестно'}',
                              ),
                              Text(
                                'Содержимое: ${_parseSupplyContent(supply['content'])}',
                              ),
                              Text(
                                'Статус: ${_getStatusText(supply['status'])}',
                              ),
                              // УБРАНА ДАТА СОЗДАНИЯ
                              if (supply['deliveryTime'] != null)
                                Text(
                                  'Время доставки: ${_formatDate(supply['deliveryTime'])}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          trailing: supply['status'] == 'оформлен'
                              ? ElevatedButton(
                                  onPressed: () => _sendSupply(supply['id']),
                                  child: const Text('Отправить'),
                                )
                              : Chip(
                                  label: Text(
                                    _getStatusText(supply['status']),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: _getStatusColor(
                                    supply['status'],
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _parseSupplyContent(String content) {
    try {
      final orderItems = jsonDecode(content);
      if (orderItems is Map && orderItems.containsKey('batchName')) {
        final quantity = orderItems['quantity'] ?? 1;
        final itemsPerBatch = orderItems['itemsPerBatch'] ?? 1;
        final totalItems = quantity * itemsPerBatch;
        return '${orderItems['batchName']} ($quantity партий по $itemsPerBatch шт) = $totalItems товаров';
      }
      return content;
    } catch (e) {
      return content;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'оформлен':
        return 'Оформлен';
      case 'отправлен':
        return 'Отправлен';
      case 'получено':
        return 'Получен';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'оформлен':
        return Colors.orange;
      case 'отправлен':
        return Colors.blue;
      case 'получено':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _sendSupply(int supplyId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'supplyId': supplyId}),
      );

      if (response.statusCode == 200) {
        _loadSupplies();
        _loadBatches();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Заказ отправлен')));
        }
      } else {
        final error = jsonDecode(response.body)['error'];
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка отправки: $error')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  // Вкладка моих партий
  Widget _buildBatchesTab() {
    // Группируем партии по одинаковым характеристикам
    final Map<String, List<dynamic>> groupedBatches = {};

    for (final batch in batches) {
      final key =
          '${batch['name']}_${batch['description']}_${batch['expiration']}_${batch['price']}_${batch['photo'] ?? ''}_${batch['itemsPerBatch']}';

      if (!groupedBatches.containsKey(key)) {
        groupedBatches[key] = [];
      }
      groupedBatches[key]!.add(batch);
    }

    // Создаем список сгруппированных партий
    final List<Map<String, dynamic>> groupedBatchesList = [];

    groupedBatches.forEach((key, batchList) {
      int totalQuantity = 0;
      for (final batch in batchList) {
        totalQuantity += (batch['quantity'] as num).toInt();
      }

      final sampleBatch = batchList.first;

      groupedBatchesList.add({
        'key': key,
        'batches': batchList,
        'totalQuantity': totalQuantity, // Общее количество партий
        'sampleBatch': sampleBatch,
      });
    });

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadBatches,
          child: groupedBatchesList.isEmpty
              ? const Center(child: Text('Нет партий'))
              : ListView.builder(
                  itemCount: groupedBatchesList.length,
                  itemBuilder: (context, index) {
                    final group = groupedBatchesList[index];
                    final batch = group['sampleBatch'] as Map<String, dynamic>;
                    final batchIds = (group['batches'] as List<dynamic>)
                        .map<int>((b) => b['id'] as int)
                        .toList();
                    final totalQuantity = group['totalQuantity'];
                    final itemsPerBatch = batch['itemsPerBatch'];

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.inventory,
                            color: Colors.grey,
                          ),
                        ),
                        title: Text(batch['name']),
// Внутри Column crossAxisAlignment в _buildBatchesTab():
subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Цена за партию: ${batch['price']} руб'),
    Text('Количество партий: $totalQuantity шт'),
    Text('Товаров в партии: $itemsPerBatch шт'),
    // Изменение здесь: показываем срок только если > 0
    if ((batch['expiration'] ?? 0) > 0)
      Text('Срок годности: ${batch['expiration']} дней'),
  ],
),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Редактировать'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Удалить',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editBatch(batch);
                            } else if (value == 'delete') {
                              _deleteMultipleBatches(batchIds);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Кнопка добавления партии в правом нижнем углу
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _addBatch,
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteMultipleBatches(List<int> batchIds) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить партии?'),
        content: Text(
          'Будет удалено ${batchIds.length} партий. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              try {
                bool allDeleted = true;
                for (final batchId in batchIds) {
                  final response = await http.delete(
                    Uri.parse('$baseUrl/batches/$batchId'),
                  );
                  if (response.statusCode != 200) {
                    allDeleted = false;
                  }
                }

                if (allDeleted) {
                  _loadBatches();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Удалено ${batchIds.length} партий'),
                      ),
                    );
                  }
                }
                if (mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка удаления: $e')),
                  );
                }
              }
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addBatch() {
    showDialog(
      context: context,
      builder: (context) => BatchDialog(
        supplierId: widget.supplier['id'],
        onBatchAdded: _loadBatches,
      ),
    );
  }

  void _editBatch(Map<String, dynamic> batch) {
    showDialog(
      context: context,
      builder: (context) => BatchDialog(
        supplierId: widget.supplier['id'],
        batch: batch,
        onBatchAdded: _loadBatches,
      ),
    );
  }

  void _showSupportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сообщение в поддержку'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Опишите вашу проблему или вопрос:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Введите ваше сообщение...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _sendSupportMessage(controller.text.trim());
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSupportMessage(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/support-messages/supplier'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromSupplierId': widget.supplier['id'],
          'text': text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сообщение отправлено в поддержку')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e')));
      }
    }
  }

  // Вкладка аккаунта

  Widget _buildAccountTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Фото профиля
          GestureDetector(
            onTap: _changePhoto,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child:
                      supplierData['photo'] != null &&
                          supplierData['photo'].isNotEmpty &&
                          supplierData['photo'].startsWith('data:image/')
                      ? Image.memory(
                          base64Decode(supplierData['photo'].split(',').last),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 100,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Имя аккаунта
          Text(
            supplierData['name'] ?? 'Без названия',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          // Отзывы
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Отзывы',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  reviews.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Отзывов пока нет',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : Column(
                          children: reviews
                              .map(
                                (review) => Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      review['fromStore']?['name'] ?? 'Магазин',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(review['text']),
                                    trailing: Text(
                                      _formatDate(review['createdAt']),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Кнопка настроек
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.settings, color: Colors.blue),
              title: const Text(
                'Настройки',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Настройки аккаунта, дизайна и удаление'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      userData: supplierData,
                      userType: 'supplier',
                      onThemeChanged: () {
                        setState(() {}); // Обновляем тему
                      },
                      onLogout: _logout,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Сообщение в поддержку - ДОБАВЛЕНО
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.blue),
              title: const Text(
                'Сообщение в поддержку',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Напишите нам, если у вас возникли проблемы',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showSupportDialog, // Используем существующий метод
            ),
          ),

          const SizedBox(height: 16),

          // Кнопка выхода из аккаунта
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.blue),
              title: const Text(
                'Выйти из аккаунта',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Вернуться на экран входа'),
              onTap: _logout,
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, String field, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value.isEmpty ? 'Не указано' : value),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => _editField(field, value),
      ),
    );
  }

  Widget _buildPasswordField() {
    return ListTile(
      title: const Text(
        'Пароль',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('••••••••'),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: _changePassword,
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await GlobalConfig.logout();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }

  void _editField(String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Изменить ${_getFieldName(field)}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Введите ${_getFieldName(field).toLowerCase()}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _updateSupplierField(field, controller.text.trim());
              }
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  String _getFieldName(String field) {
    switch (field) {
      case 'name':
        return 'Имя';
      case 'address':
        return 'Адрес';
      case 'description':
        return 'Описание';
      default:
        return field;
    }
  }

  void _changePassword() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить пароль'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Введите новый пароль'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _updateSupplierField('password', controller.text.trim());
              }
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSupplierField(String field, String value) async {
    try {
      final data = {field: value};
      final response = await http.put(
        Uri.parse('$baseUrl/suppliers/${widget.supplier['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        _loadSupplierData();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Данные обновлены')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка обновления: $e')));
      }
    }
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      try {
        final bytes = await File(pickedFile.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        final imageType = pickedFile.path.split('.').last.toLowerCase();
        final mimeType = _getMimeType(imageType);
        final photoData = 'data:$mimeType;base64,$base64Image';

        await _updateSupplierField('photo', photoData);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка загрузки фото: $e')));
        }
      }
    }
  }

  String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _deleteAccount() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Все ваши партии, поставки и отзывы будут удалены. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final response = await http.delete(
                  Uri.parse('$baseUrl/suppliers/${widget.supplier['id']}'),
                );
                if (response.statusCode == 200) {
                  await GlobalConfig.logout();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (route) => false,
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка удаления: $e')),
                  );
                }
              }
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _buildOrdersTab(),
              _buildBatchesTab(),
              _buildAccountTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Заказы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Мои партии',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Аккаунт'),
        ],
      ),
    );
  }
}

// Диалог для добавления/редактирования партии
class BatchDialog extends StatefulWidget {
  final int supplierId;
  final Map<String, dynamic>? batch;
  final VoidCallback onBatchAdded;

  const BatchDialog({
    super.key,
    required this.supplierId,
    this.batch,
    required this.onBatchAdded,
  });

  @override
  State<BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends State<BatchDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController expirationController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController itemsPerBatchController = TextEditingController();
  final String baseUrl = GlobalConfig.baseUrl;

  File? _selectedImage;
  String? _currentPhoto;

@override
void initState() {
  super.initState();
  if (widget.batch != null) {
    nameController.text = widget.batch!['name'];
    descriptionController.text = widget.batch!['description'];
    // Изменение здесь: устанавливаем только если срок > 0
    final exp = widget.batch!['expiration'];
    expirationController.text = (exp != null && exp > 0) ? exp.toString() : '';
    priceController.text = widget.batch!['price'].toString();
    itemsPerBatchController.text = widget.batch!['itemsPerBatch'].toString();
    quantityController.text = widget.batch!['quantity'].toString();
    _currentPhoto = widget.batch!['photo'];
  } else {
    // По умолчанию оставляем пустым вместо 30
    expirationController.text = '';
    priceController.text = '0';
    quantityController.text = '1';
    itemsPerBatchController.text = '10';
  }
}

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _currentPhoto = null;
      });
    }
  }

  Future<String?> _convertImageToBase64() async {
    if (_selectedImage == null) {
      return _currentPhoto;
    }

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final imageType = _selectedImage!.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(imageType);
      return 'data:$mimeType;base64,$base64Image';
    } catch (e) {
      debugPrint('Error converting image: $e');
      return null;
    }
  }

  String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _saveBatch() async {
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите название партии')));
      return;
    }

    try {
      final photoData = await _convertImageToBase64();
      final quantity = int.tryParse(quantityController.text) ?? 1;
      final itemsPerBatch = int.tryParse(itemsPerBatchController.text) ?? 10;

      if (quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Количество партий должно быть больше 0'),
          ),
        );
        return;
      }

      if (quantity > 100) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Не больше 100 партий')));
        return;
      }

      if (itemsPerBatch <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Количество товаров в партии должно быть больше 0'),
          ),
        );
        return;
      }

      if (itemsPerBatch > 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не больше 1000 товаров в партии')),
        );
        return;
      }

final data = {
  'name': nameController.text,
  'description': descriptionController.text,
  // Изменение здесь: преобразуем в число, если введено
  'expiration': expirationController.text.isNotEmpty 
      ? int.tryParse(expirationController.text) ?? 0 
      : 0,
  'price': double.tryParse(priceController.text) ?? 0.0,
  'photo': photoData,
  'itemsPerBatch': itemsPerBatch,
  'quantity': quantity,
  'supplierId': widget.supplierId,
};

      final response = widget.batch == null
          ? await http.post(
              Uri.parse('$baseUrl/batches'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            )
          : await http.put(
              Uri.parse('$baseUrl/batches/${widget.batch!['id']}'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            );

      if (response.statusCode == 200) {
        widget.onBatchAdded();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.batch == null
                    ? 'Создано $quantity партий'
                    : 'Партия обновлена',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quantity = int.tryParse(quantityController.text) ?? 1;
    final itemsPerBatch = int.tryParse(itemsPerBatchController.text) ?? 10;

    final bool isQuantityValid = quantity > 0 && quantity <= 100;
    final bool isItemsPerBatchValid =
        itemsPerBatch > 0 && itemsPerBatch <= 1000;
    final bool allValid = isQuantityValid && isItemsPerBatchValid;

    Color getColor() {
      if (!allValid) return Colors.red[50]!;
      return Colors.blue[50]!;
    }

    Color getBorderColor() {
      if (!allValid) return Colors.red[100]!;
      return Colors.blue[100]!;
    }

    Color getTextColor() {
      if (!allValid) return Colors.red;
      return Colors.blue;
    }

    IconData getIcon() {
      if (!allValid) return Icons.warning;
      return Icons.info;
    }

    // ВЫЧИСЛЯЕМ ШИРИНУ ДИАЛОГА - 90% ОТ ШИРИНЫ ЭКРАНА
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.9;

    return Dialog(
      // ИСПОЛЬЗУЕМ ConstrainedBox для установки ширины
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          minWidth: dialogWidth * 0.8,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.batch == null
                      ? 'Добавить партии'
                      : 'Редактировать партию',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[100],
                    ),
                    child: _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.cover)
                        : _currentPhoto != null &&
                              _currentPhoto!.startsWith('data:image/')
                        ? Image.memory(
                            base64Decode(_currentPhoto!.split(',').last),
                            fit: BoxFit.cover,
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: Colors.grey,
                              ),
                              Text(
                                'Фото',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Нажмите для добавления фото',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название партии*',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание партии',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: expirationController,
                  decoration: const InputDecoration(
                    labelText: 'Срок годности товаров (дни)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Цена за одну партию',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: itemsPerBatchController,
                  decoration: const InputDecoration(
                    labelText: 'Товаров в одной партии (1-1000)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Количество таких партий (1-100)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),

                const SizedBox(height: 12),

                /*Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: getColor(),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: getBorderColor()),
                  ),
                  /*child: Row(
                    children: [
                      Icon(getIcon(), color: getTextColor(), size: 20),
                      const SizedBox(width: 8),
                      /*Expanded(
                        child: Text(
                          'Создается $quantity партий',
                          style: TextStyle(
                            color: getTextColor(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),*/
                    ],
                  ),*/
                ),*/
                if (!allValid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isQuantityValid)
                          const Text(
                            '• Количество партий должно быть от 1 до 100',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        if (!isItemsPerBatchValid)
                          const Text(
                            '• Товаров в партии должно быть от 1 до 1000',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Кнопки
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saveBatch,
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    expirationController.dispose();
    priceController.dispose();
    quantityController.dispose();
    itemsPerBatchController.dispose();
    super.dispose();
  }
}
