import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../main.dart';

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

    // Применяем сортировку
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
        // Панель фильтров и сортировки
        Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    items: ['Все', 'оформлен', 'отправлен', 'доставлен']
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
      if (orderItems is Map && orderItems.containsKey('batchId')) {
        final batchId = orderItems['batchId'];
        final batchCount = orderItems['batchCount'] ?? 1;
        final batch = batches.firstWhere(
          (b) => b['id'] == batchId,
          orElse: () => null,
        );
        if (batch != null) {
          final productCount = batch['productCount'] ?? 0;
          return 'Партия "${batch['name']}": $batchCount партий × $productCount товаров = ${batchCount * productCount} товаров';
        }
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
      case 'доставлен':
        return 'Доставлен';
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
      case 'доставлен':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _sendSupply(int supplyId) async {
    if (!mounted) return;

    try {
      // Находим заказ
      final supply = supplies.firstWhere((s) => s['id'] == supplyId);
      final canSend = await _checkInventory(supply['content']);

      if (canSend) {
        // Обновляем статус поставки
        final response = await http.put(
          Uri.parse('$baseUrl/supplies/$supplyId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fromSupplierId': supply['fromSupplierId'],
            'toStoreId': supply['toStoreId'],
            'content': supply['content'],
            'status': 'отправлен',
          }),
        );

        if (response.statusCode == 200) {
          // Уменьшаем количество партий
          await _updateBatchesInventory(supply['content']);
          _loadSupplies();
          _loadBatches();
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Заказ отправлен')));
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка сервера: ${response.statusCode}')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Недостаточно партий на складе')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<bool> _checkInventory(String content) async {
    try {
      final orderItems = jsonDecode(content);

      if (orderItems is Map && orderItems.containsKey('batchId')) {
        final batchId = orderItems['batchId'];
        final batchCount = orderItems['quantity'] ?? 1; // Z партий

        // Находим партию
        final batch = batches.firstWhere(
          (b) => b['id'] == batchId,
          orElse: () => null,
        );

        // Проверяем, что у поставщика достаточно партий
        if (batch == null || (batch['productCount'] ?? 0) < batchCount) {
          return false;
        }
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking inventory: $e');
      return false;
    }
  }

  Future<void> _updateBatchesInventory(String content) async {
    try {
      final orderItems = jsonDecode(content);

      if (orderItems is Map && orderItems.containsKey('batchId')) {
        final batchId = orderItems['batchId'];
        final batchCount = orderItems['quantity'] ?? 1; // Z партий

        final batch = batches.firstWhere((b) => b['id'] == batchId);
        final newCount = (batch['productCount'] ?? 0) - batchCount;

        // Обновляем количество партий у поставщика
        await http.put(
          Uri.parse('$baseUrl/batches/${batch['id']}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': batch['name'],
            'description': batch['description'],
            'expiration': batch['expiration'],
            'price': batch['price'],
            'photo': batch['photo'],
            'productCount': newCount, // Уменьшаем количество партий
            'supplierId': batch['supplierId'],
          }),
        );
      }
    } catch (e) {
      debugPrint('Error updating batches inventory: $e');
    }
  }

  // Вкладка моих партий с группировкой
  Widget _buildBatchesTab() {
    // Группируем партии по одинаковым характеристикам (кроме id и productCount)
    final Map<String, List<dynamic>> groupedBatches = {};

    for (final batch in batches) {
      final key =
          '${batch['name']}_${batch['description']}_${batch['expiration']}_${batch['price']}_${batch['photo'] ?? ''}';

      if (!groupedBatches.containsKey(key)) {
        groupedBatches[key] = [];
      }
      groupedBatches[key]!.add(batch);
    }

    // Создаем список сгруппированных партий
    final List<Map<String, dynamic>> groupedBatchesList = [];

    groupedBatches.forEach((key, batchList) {
      final totalBatches = batchList.fold<int>(
        0,
        (int sum, batch) => sum + (batch['productCount'] as int),
      );
      final sampleBatch = batchList.first;

      groupedBatchesList.add({
        'key': key,
        'batches': batchList,
        'totalBatches': totalBatches,
        'sampleBatch': sampleBatch,
      });
    });

    return Column(
      children: [
        ElevatedButton(
          onPressed: _addBatch,
          child: const Text('Добавить партию'),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBatches,
            child: groupedBatchesList.isEmpty
                ? const Center(child: Text('Нет партий'))
                : ListView.builder(
                    itemCount: groupedBatchesList.length,
                    itemBuilder: (context, index) {
                      final group = groupedBatchesList[index];
                      final batch =
                          group['sampleBatch'] as Map<String, dynamic>;
                      final batchIds = (group['batches'] as List<dynamic>)
                          .map<int>((b) => b['id'] as int)
                          .toList();

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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Цена за партию: ${batch['price']} руб'),
                              Text(
                                'Количество партий: ${group['totalBatches']}',
                              ),
                              Text(
                                'Срок годности: ${batch['expiration']} дней',
                              ),
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
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Удалено ${batchIds.length} партий'),
                    ),
                  );
                }
                if (!mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
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

  // Остальные методы без изменений...
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
                if (!mounted) return;
                Navigator.pop(context);
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сообщение отправлено в поддержку')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e')));
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
            child: CircleAvatar(
              radius: 50,
              backgroundImage:
                  supplierData['photo'] != null &&
                      supplierData['photo'].isNotEmpty &&
                      supplierData['photo'].startsWith('data:image/')
                  ? MemoryImage(
                      base64Decode(supplierData['photo'].split(',').last),
                    )
                  : null,
              child:
                  supplierData['photo'] == null || supplierData['photo'].isEmpty
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите для изменения фото',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),

          const SizedBox(height: 20),

          // Информация аккаунта
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildEditableField(
                    'Имя',
                    'name',
                    supplierData['name'] ?? '',
                  ),
                  _buildEditableField(
                    'Адрес',
                    'address',
                    supplierData['address'] ?? '',
                  ),
                  _buildEditableField(
                    'Описание',
                    'description',
                    supplierData['description'] ?? '',
                  ),
                  _buildPasswordField(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Отзывы
          Card(
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

          const SizedBox(height: 16),

          // Сообщение в поддержку
          Card(
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
              onTap: _showSupportDialog,
            ),
          ),

          const SizedBox(height: 16),

          // Удаление аккаунта
          Card(
            color: Colors.red[50],
            child: ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Удалить аккаунт',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Все ваши данные будут безвозвратно удалены',
              ),
              onTap: _deleteAccount,
            ),
          ),
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
              if (!mounted) return;
              Navigator.pop(context);
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
              if (!mounted) return;
              Navigator.pop(context);
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
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Данные обновлены')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка обновления: $e')));
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
        // Читаем файл как байты
        final bytes = await File(pickedFile.path).readAsBytes();
        // Конвертируем в base64
        final base64Image = base64Encode(bytes);
        // Определяем тип изображения
        final imageType = pickedFile.path.split('.').last.toLowerCase();
        final mimeType = _getMimeType(imageType);
        // Сохраняем как data URL
        final photoData = 'data:$mimeType;base64,$base64Image';

        await _updateSupplierField('photo', photoData);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка загрузки фото: $e')));
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
                  if (!mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
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
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Поставщик: ${supplierData['name'] ?? widget.supplier['name']}',
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildOrdersTab(), _buildBatchesTab(), _buildAccountTab()],
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
  final TextEditingController batchCountController =
      TextEditingController(); // Количество партий
  final TextEditingController itemsPerBatchController =
      TextEditingController(); // Товаров в одной партии
  final String baseUrl = "http://localhost:3000";

  File? _selectedImage;
  String? _currentPhoto;

  @override
  void initState() {
    super.initState();
    if (widget.batch != null) {
      nameController.text = widget.batch!['name'];
      descriptionController.text = widget.batch!['description'];
      expirationController.text = widget.batch!['expiration'].toString();
      priceController.text = widget.batch!['price'].toString();
      batchCountController.text = '1'; // По умолчанию 1 партия
      itemsPerBatchController.text = widget.batch!['productCount']
          .toString(); // Товаров в партии
      _currentPhoto = widget.batch!['photo'];
    } else {
      batchCountController.text = '1'; // По умолчанию 1 партия
      itemsPerBatchController.text = '1'; // По умолчанию 1 товар в партии
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите название партии')));
      return;
    }

    try {
      final photoData = await _convertImageToBase64();
      final batchCount = int.tryParse(batchCountController.text) ?? 1;
      final itemsPerBatch = int.tryParse(itemsPerBatchController.text) ?? 1;
      final totalItems = batchCount * itemsPerBatch; // Общее количество товаров

      final data = {
        'name': nameController.text,
        'description': descriptionController.text,
        'expiration': int.tryParse(expirationController.text) ?? 0,
        'price': double.tryParse(priceController.text) ?? 0.0,
        'photo': photoData,
        'productCount': batchCount, // Количество партий
        'itemsPerBatch': itemsPerBatch, // Товаров в одной партии
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
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Партия сохранена')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchCount = int.tryParse(batchCountController.text) ?? 1;
    final itemsPerBatch = int.tryParse(itemsPerBatchController.text) ?? 1;
    final totalItems = batchCount * itemsPerBatch;

    return AlertDialog(
      title: Text(
        widget.batch == null ? 'Добавить партию' : 'Редактировать партию',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Поле для фото
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
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Нажмите для добавления фото',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Название*',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 12),

            TextField(
              controller: expirationController,
              decoration: const InputDecoration(
                labelText: 'Срок годности (дни)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 12),

            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Цена за партию',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: batchCountController,
              decoration: const InputDecoration(
                labelText: 'Количество партий',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {});
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: itemsPerBatchController,
              decoration: const InputDecoration(
                labelText: 'Товаров в одной партии',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {});
              },
            ),

            const SizedBox(height: 12),

            // Информация об итоговом количестве
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Итого: $batchCount партий × $itemsPerBatch товаров = $totalItems товаров',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(onPressed: _saveBatch, child: const Text('Сохранить')),
      ],
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    expirationController.dispose();
    priceController.dispose();
    batchCountController.dispose();
    itemsPerBatchController.dispose();
    super.dispose();
  }
}
