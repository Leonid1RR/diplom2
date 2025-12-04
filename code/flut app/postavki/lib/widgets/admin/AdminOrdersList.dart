import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../main.dart';

class AdminOrdersList extends StatefulWidget {
  const AdminOrdersList({super.key});

  @override
  State<AdminOrdersList> createState() => _AdminOrdersListState();
}

class _AdminOrdersListState extends State<AdminOrdersList> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all';
  String _sortBy = 'id_desc';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${GlobalConfig.baseUrl}/supplies'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _orders = data;
        });
      } else {
        setState(() {
          _errorMessage = 'Ошибка загрузки: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка подключения: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteOrder(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление заказа'),
        content: const Text('Вы уверены, что хотите удалить этот заказ?'),
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

    if (confirmed == true) {
      try {
        final response = await http.delete(
          Uri.parse('${GlobalConfig.baseUrl}/supplies/$id'),
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Заказ удален')));
          }
          _loadOrders();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ошибка удаления: ${response.statusCode}'),
              ),
            );
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
  }

  void _editOrder(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) =>
          OrderEditDialog(order: order, onOrderUpdated: _loadOrders),
    );
  }

  void _addNewOrder() {
    showDialog(
      context: context,
      builder: (context) =>
          OrderEditDialog(order: null, onOrderUpdated: _loadOrders),
    );
  }

  void _viewOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => OrderDetailsDialog(order: order),
    );
  }

  void _changeOrderStatus(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) =>
          ChangeOrderStatusDialog(order: order, onStatusChanged: _loadOrders),
    );
  }

  List<dynamic> _getFilteredOrders() {
    List<dynamic> filtered = _orders;

    // Фильтрация по поиску
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((order) {
        return order['id'].toString().contains(_searchQuery) ||
            (order['fromSupplier']?['name']?.toString().toLowerCase() ?? '')
                .contains(_searchQuery.toLowerCase()) ||
            (order['toStore']?['name']?.toString().toLowerCase() ?? '')
                .contains(_searchQuery.toLowerCase()) ||
            order['content'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    }

    // Фильтрация по статусу
    if (_filterStatus != 'all') {
      filtered = filtered
          .where((order) => order['status'] == _filterStatus)
          .toList();
    }

    // Сортировка
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'id_asc':
          return a['id'].compareTo(b['id']);
        case 'id_desc':
          return b['id'].compareTo(a['id']);
        case 'status_asc':
          return a['status'].compareTo(b['status']);
        case 'status_desc':
          return b['status'].compareTo(a['status']);
        case 'date_asc':
          final dateA = a['createdAt'] ?? '';
          final dateB = b['createdAt'] ?? '';
          return dateA.compareTo(dateB);
        case 'date_desc':
          final dateA = a['createdAt'] ?? '';
          final dateB = b['createdAt'] ?? '';
          return dateB.compareTo(dateA);
        default:
          return b['id'].compareTo(a['id']);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _getFilteredOrders();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заказы'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewOrder,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Фильтры и поиск
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    labelText: 'Поиск заказов',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterStatus,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Все статусы'),
                          ),
                          DropdownMenuItem(
                            value: 'оформлен',
                            child: Text('Оформлен'),
                          ),
                          DropdownMenuItem(
                            value: 'отправлен',
                            child: Text('Отправлен'),
                          ),
                          DropdownMenuItem(
                            value: 'получено',
                            child: Text('Получено'),
                          ),
                          DropdownMenuItem(
                            value: 'отменен',
                            child: Text('Отменен'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _filterStatus = value!),
                        decoration: const InputDecoration(
                          labelText: 'Статус',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        items: const [
                          DropdownMenuItem(
                            value: 'id_desc',
                            child: Text('ID (новые)'),
                          ),
                          DropdownMenuItem(
                            value: 'id_asc',
                            child: Text('ID (старые)'),
                          ),
                          DropdownMenuItem(
                            value: 'status_asc',
                            child: Text('Статус (А-Я)'),
                          ),
                          DropdownMenuItem(
                            value: 'status_desc',
                            child: Text('Статус (Я-А)'),
                          ),
                          DropdownMenuItem(
                            value: 'date_desc',
                            child: Text('Дата (новые)'),
                          ),
                          DropdownMenuItem(
                            value: 'date_asc',
                            child: Text('Дата (старые)'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _sortBy = value!),
                        decoration: const InputDecoration(
                          labelText: 'Сортировка',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Статистика
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Всего', _orders.length.toString(), Colors.blue),
                _buildStatItem(
                  'Оформлен',
                  _orders
                      .where((o) => o['status'] == 'оформлен')
                      .length
                      .toString(),
                  Colors.orange,
                ),
                _buildStatItem(
                  'Отправлен',
                  _orders
                      .where((o) => o['status'] == 'отправлен')
                      .length
                      .toString(),
                  Colors.blue,
                ),
                _buildStatItem(
                  'Получено',
                  _orders
                      .where((o) => o['status'] == 'получено')
                      .length
                      .toString(),
                  Colors.green,
                ),
              ],
            ),
          ),

          // Список
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadOrders,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : filteredOrders.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет заказов'),
                        SizedBox(height: 8),
                        Text(
                          'Нажмите + чтобы добавить новый заказ',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return OrderCard(
                        order: order,
                        onEdit: () => _editOrder(order),
                        onDelete: () => _deleteOrder(order['id']),
                        onViewDetails: () => _viewOrderDetails(order),
                        onChangeStatus: () => _changeOrderStatus(order),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

// Карточка заказа
class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;
  final VoidCallback onChangeStatus;

  const OrderCard({
    super.key,
    required this.order,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDetails,
    required this.onChangeStatus,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'оформлен':
        return Colors.orange;
      case 'отправлен':
        return Colors.blue;
      case 'получено':
        return Colors.green;
      case 'отменен':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _parseOrderContent(String content) {
    try {
      final data = json.decode(content);
      if (data is Map) {
        if (data.containsKey('batchName')) {
          return '${data['batchName']} (${data['quantity']} партий)';
        }
      }
      return content.length > 50 ? '${content.substring(0, 50)}...' : content;
    } catch (e) {
      return content.length > 50 ? '${content.substring(0, 50)}...' : content;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onViewDetails,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Заказ #${order['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Chip(
                    label: Text(
                      order['status'].toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(order['status']),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    backgroundColor: _getStatusColor(
                      order['status'],
                    ).withOpacity(0.1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Поставщик: ${order['fromSupplier']?['name'] ?? 'Неизвестно'}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Магазин: ${order['toStore']?['name'] ?? 'Неизвестно'}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                _parseOrderContent(order['content']),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (order['createdAt'] != null)
                Text(
                  _formatDate(order['createdAt']),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info, size: 18),
                    onPressed: onViewDetails,
                    tooltip: 'Подробности',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: onEdit,
                    tooltip: 'Редактировать',
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_vert, size: 18),
                    onPressed: onChangeStatus,
                    tooltip: 'Изменить статус',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: onDelete,
                    tooltip: 'Удалить',
                  ),
                ],
              ),
            ],
          ),
        ),
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
}

// Диалог редактирования/создания заказа
class OrderEditDialog extends StatefulWidget {
  final Map<String, dynamic>? order;
  final VoidCallback onOrderUpdated;

  const OrderEditDialog({super.key, this.order, required this.onOrderUpdated});

  @override
  State<OrderEditDialog> createState() => _OrderEditDialogState();
}

class _OrderEditDialogState extends State<OrderEditDialog> {
  final TextEditingController _fromSupplierIdController =
      TextEditingController();
  final TextEditingController _toStoreIdController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();
  List<dynamic> _suppliers = [];
  List<dynamic> _stores = [];
  List<dynamic> _batches = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();

    if (widget.order != null) {
      _fromSupplierIdController.text = widget.order!['fromSupplierId']
          .toString();
      _toStoreIdController.text = widget.order!['toStoreId'].toString();
      _contentController.text = widget.order!['content'];
      _statusController.text = widget.order!['status'];
    } else {
      _statusController.text = 'оформлен';
      _contentController.text = json.encode({
        'batchName': 'Пример товара',
        'description': 'Описание товара',
        'quantity': 1,
        'itemsPerBatch': 10,
        'totalPrice': 1000,
        'expiration': 30,
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final [
        suppliersResponse,
        storesResponse,
        batchesResponse,
      ] = await Future.wait([
        http.get(Uri.parse('${GlobalConfig.baseUrl}/suppliers')),
        http.get(Uri.parse('${GlobalConfig.baseUrl}/stores')),
        http.get(Uri.parse('${GlobalConfig.baseUrl}/batches')),
      ]);

      if (suppliersResponse.statusCode == 200) {
        setState(() {
          _suppliers = json.decode(suppliersResponse.body);
        });
      }

      if (storesResponse.statusCode == 200) {
        setState(() {
          _stores = json.decode(storesResponse.body);
        });
      }

      if (batchesResponse.statusCode == 200) {
        setState(() {
          _batches = json.decode(batchesResponse.body);
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  void _selectBatch(Map<String, dynamic> batch) {
    final content = {
      'batchId': batch['id'],
      'batchName': batch['name'],
      'description': batch['description'] ?? '',
      'expiration': batch['expiration'] ?? 30,
      'quantity': 1,
      'itemsPerBatch': batch['productCount'] ?? 1,
      'totalItems': batch['productCount'] ?? 1,
      'totalPrice': batch['price'] ?? 0,
      'supplierPhoto': batch['photo'],
    };

    _contentController.text = json.encode(content);
    _fromSupplierIdController.text = batch['supplierId'].toString();
  }

  Future<void> _saveOrder() async {
    if (_fromSupplierIdController.text.isEmpty ||
        _toStoreIdController.text.isEmpty ||
        _statusController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заполните обязательные поля'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'fromSupplierId': int.parse(_fromSupplierIdController.text),
        'toStoreId': int.parse(_toStoreIdController.text),
        'content': _contentController.text,
        'status': _statusController.text,
      };

      final response = widget.order == null
          ? await http.post(
              Uri.parse('${GlobalConfig.baseUrl}/supplies'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            )
          : await http.put(
              Uri.parse(
                '${GlobalConfig.baseUrl}/supplies/${widget.order!['id']}',
              ),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            );

      if (response.statusCode == 200) {
        widget.onOrderUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.order == null ? 'Заказ создан' : 'Заказ обновлен',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.order == null ? 'Новый заказ' : 'Редактировать заказ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Быстрый выбор партии
            if (_batches.isNotEmpty)
              Column(
                children: [
                  const Text(
                    'Выберите партию:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    items: _batches.map((batch) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: batch,
                        child: Text(
                          '${batch['name']} (${batch['supplier']?['name'] ?? 'Неизвестно'})',
                        ),
                      );
                    }).toList(),
                    onChanged: (batch) {
                      if (batch != null) {
                        _selectBatch(batch);
                      }
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Выберите партию...',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Поставщик
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fromSupplierIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ID поставщика*',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  itemBuilder: (context) => _suppliers.map((supplier) {
                    return PopupMenuItem<String>(
                      value: supplier['id'].toString(),
                      child: Text(
                        '${supplier['name']} (ID: ${supplier['id']})',
                      ),
                    );
                  }).toList(),
                  onSelected: (value) {
                    setState(() {
                      _fromSupplierIdController.text = value;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.person),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Магазин
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _toStoreIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ID магазина*',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  itemBuilder: (context) => _stores.map((store) {
                    return PopupMenuItem<String>(
                      value: store['id'].toString(),
                      child: Text('${store['name']} (ID: ${store['id']})'),
                    );
                  }).toList(),
                  onSelected: (value) {
                    setState(() {
                      _toStoreIdController.text = value;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.store),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Содержимое (JSON)
            TextField(
              controller: _contentController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Содержимое заказа (JSON)',
                border: OutlineInputBorder(),
                hintText: '{"batchName": "...", "quantity": 1, ...}',
              ),
            ),
            const SizedBox(height: 12),

            // Статус
            DropdownButtonFormField<String>(
              value: _statusController.text,
              items: const [
                DropdownMenuItem(value: 'оформлен', child: Text('Оформлен')),
                DropdownMenuItem(value: 'отправлен', child: Text('Отправлен')),
                DropdownMenuItem(value: 'получено', child: Text('Получено')),
                DropdownMenuItem(value: 'отменен', child: Text('Отменен')),
              ],
              onChanged: (value) =>
                  setState(() => _statusController.text = value!),
              decoration: const InputDecoration(
                labelText: 'Статус*',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveOrder,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.order == null ? 'Создать' : 'Сохранить'),
        ),
      ],
    );
  }
}

// Диалог изменения статуса заказа
class ChangeOrderStatusDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback onStatusChanged;

  const ChangeOrderStatusDialog({
    super.key,
    required this.order,
    required this.onStatusChanged,
  });

  @override
  State<ChangeOrderStatusDialog> createState() =>
      _ChangeOrderStatusDialogState();
}

class _ChangeOrderStatusDialogState extends State<ChangeOrderStatusDialog> {
  String _selectedStatus = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order['status'];
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == widget.order['status']) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.put(
        Uri.parse('${GlobalConfig.baseUrl}/supplies/${widget.order['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fromSupplierId': widget.order['fromSupplierId'],
          'toStoreId': widget.order['toStoreId'],
          'content': widget.order['content'],
          'status': _selectedStatus,
        }),
      );

      if (response.statusCode == 200) {
        widget.onStatusChanged();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Статус изменен на "$_selectedStatus"'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Изменить статус заказа'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Заказ #${widget.order['id']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Текущий статус: ${widget.order['status']}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            items: const [
              DropdownMenuItem(value: 'оформлен', child: Text('Оформлен')),
              DropdownMenuItem(value: 'отправлен', child: Text('Отправлен')),
              DropdownMenuItem(value: 'получено', child: Text('Получено')),
              DropdownMenuItem(value: 'отменен', child: Text('Отменен')),
            ],
            onChanged: (value) => setState(() => _selectedStatus = value!),
            decoration: const InputDecoration(
              labelText: 'Новый статус',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateStatus,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}

// Диалог подробной информации о заказе
class OrderDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailsDialog({super.key, required this.order});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'оформлен':
        return Colors.orange;
      case 'отправлен':
        return Colors.blue;
      case 'получено':
        return Colors.green;
      case 'отменен':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _parseContent() {
    try {
      final content = json.decode(order['content']);
      if (content is Map) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content['batchName'] != null)
              _buildInfoRow('Название партии:', content['batchName']),
            if (content['description'] != null)
              _buildInfoRow('Описание:', content['description']),
            if (content['quantity'] != null)
              _buildInfoRow(
                'Количество партий:',
                content['quantity'].toString(),
              ),
            if (content['itemsPerBatch'] != null)
              _buildInfoRow(
                'Единиц в партии:',
                content['itemsPerBatch'].toString(),
              ),
            if (content['totalItems'] != null)
              _buildInfoRow('Всего единиц:', content['totalItems'].toString()),
            if (content['totalPrice'] != null)
              _buildInfoRow('Общая стоимость:', '${content['totalPrice']} руб'),
            if (content['expiration'] != null)
              _buildInfoRow('Срок годности:', '${content['expiration']} дней'),
          ],
        );
      }
    } catch (e) {
      debugPrint('Error parsing content: $e');
    }

    return _buildInfoRow('Содержимое:', order['content']);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Center(
                child: Text(
                  'Заказ #${order['id']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Center(
                child: Chip(
                  label: Text(
                    order['status'].toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(order['status']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: _getStatusColor(
                    order['status'],
                  ).withOpacity(0.1),
                ),
              ),
              const SizedBox(height: 16),

              // Информация о поставщике
              const Text(
                'Поставщик:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('ID:', order['fromSupplierId'].toString()),
              if (order['fromSupplier'] != null) ...[
                _buildInfoRow('Название:', order['fromSupplier']['name']),
                _buildInfoRow('Адрес:', order['fromSupplier']['address']),
                if (order['fromSupplier']['description'] != null)
                  _buildInfoRow(
                    'Описание:',
                    order['fromSupplier']['description'],
                  ),
              ],
              const SizedBox(height: 16),

              // Информация о магазине
              const Text(
                'Магазин:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('ID:', order['toStoreId'].toString()),
              if (order['toStore'] != null) ...[
                _buildInfoRow('Название:', order['toStore']['name']),
                _buildInfoRow('Адрес:', order['toStore']['address']),
                if (order['toStore']['description'] != null)
                  _buildInfoRow('Описание:', order['toStore']['description']),
              ],
              const SizedBox(height: 16),

              // Информация о содержимом
              const Text(
                'Содержимое заказа:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _parseContent(),
              const SizedBox(height: 16),

              // Дополнительная информация
              const Text(
                'Дополнительно:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (order['createdAt'] != null)
                _buildInfoRow(
                  'Дата создания:',
                  _formatDate(order['createdAt']),
                ),
              if (order['updatedAt'] != null)
                _buildInfoRow(
                  'Дата обновления:',
                  _formatDate(order['updatedAt']),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
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
}
