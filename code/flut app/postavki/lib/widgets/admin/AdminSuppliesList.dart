import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../main.dart';

class AdminSuppliesList extends StatefulWidget {
  const AdminSuppliesList({super.key});

  @override
  State<AdminSuppliesList> createState() => _AdminSuppliesListState();
}

class _AdminSuppliesListState extends State<AdminSuppliesList> {
  List<dynamic> _supplies = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all';
  String _sortBy = 'id_desc';

  @override
  void initState() {
    super.initState();
    _loadSupplies();
  }

  Future<void> _loadSupplies() async {
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
          _supplies = data;
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

  Future<void> _deleteSupply(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление поставки'),
        content: const Text('Вы уверены, что хотите удалить эту поставку?'),
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
            ).showSnackBar(const SnackBar(content: Text('Поставка удалена')));
          }
          _loadSupplies();
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

  void _editSupply(Map<String, dynamic> supply) {
    showDialog(
      context: context,
      builder: (context) =>
          SupplyEditDialog(supply: supply, onSupplyUpdated: _loadSupplies),
    );
  }

  void _addNewSupply() {
    showDialog(
      context: context,
      builder: (context) =>
          SupplyEditDialog(supply: null, onSupplyUpdated: _loadSupplies),
    );
  }

  void _viewSupplyDetails(Map<String, dynamic> supply) {
    showDialog(
      context: context,
      builder: (context) => SupplyDetailsDialog(supply: supply),
    );
  }

  List<dynamic> _getFilteredSupplies() {
    List<dynamic> filtered = _supplies;

    // Фильтрация по поиску
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((supply) {
        final supplierName =
            supply['fromSupplier']?['name']?.toString().toLowerCase() ?? '';
        final storeName =
            supply['toStore']?['name']?.toString().toLowerCase() ?? '';

        return supply['id'].toString().contains(_searchQuery) ||
            supplierName.contains(_searchQuery.toLowerCase()) ||
            storeName.contains(_searchQuery.toLowerCase()) ||
            supply['content'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    }

    // Фильтрация по статусу
    if (_filterStatus != 'all') {
      filtered = filtered
          .where((supply) => supply['status'] == _filterStatus)
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
        default:
          return b['id'].compareTo(a['id']);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredSupplies = _getFilteredSupplies();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заказы/Поставки'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSupplies),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewSupply,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
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
                      labelText: 'Поиск поставок',
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
                          ],
                          onChanged: (value) =>
                              setState(() => _sortBy = value!),
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

            // Информация
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Всего: ${_supplies.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (_searchQuery.isNotEmpty || _filterStatus != 'all')
                    Text(
                      'Найдено: ${filteredSupplies.length}',
                      style: const TextStyle(color: Colors.blue),
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
                            onPressed: _loadSupplies,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    )
                  : filteredSupplies.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text('Нет поставок'),
                          SizedBox(height: 8),
                          Text(
                            'Нажмите + чтобы добавить новую поставку',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredSupplies.length,
                      itemBuilder: (context, index) {
                        final supply = filteredSupplies[index];
                        return SupplyCard(
                          supply: supply,
                          onEdit: () => _editSupply(supply),
                          onDelete: () => _deleteSupply(supply['id']),
                          onViewDetails: () => _viewSupplyDetails(supply),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Карточка поставки
class SupplyCard extends StatelessWidget {
  final Map<String, dynamic> supply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;

  const SupplyCard({
    super.key,
    required this.supply,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDetails,
  });

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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'оформлен':
        return Icons.shopping_cart;
      case 'отправлен':
        return Icons.local_shipping;
      case 'получено':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Иконка статуса
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(
                  _getStatusColor(supply['status']).value,
                ).withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getStatusIcon(supply['status']),
                color: _getStatusColor(supply['status']),
              ),
            ),
            const SizedBox(width: 12),

            // Текстовая информация и кнопки
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  Text(
                    'Поставка #${supply['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Поставщик
                  Text(
                    'От: ${supply['fromSupplier']?['name'] ?? 'Неизвестно'}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),

                  // Магазин
                  Text(
                    'Кому: ${supply['toStore']?['name'] ?? 'Неизвестно'}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  const SizedBox(height: 8),

                  // Кнопки
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.info, color: Colors.blue),
                        onPressed: onViewDetails,
                        tooltip: 'Подробности',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: onEdit,
                        tooltip: 'Редактировать',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: onDelete,
                        tooltip: 'Удалить',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Статус
                  Chip(
                    label: Text(
                      supply['status'].toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(supply['status']),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: Color(
                      _getStatusColor(supply['status']).value,
                    ).withAlpha(25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Диалог редактирования/создания поставки
class SupplyEditDialog extends StatefulWidget {
  final Map<String, dynamic>? supply;
  final VoidCallback onSupplyUpdated;

  const SupplyEditDialog({
    super.key,
    this.supply,
    required this.onSupplyUpdated,
  });

  @override
  State<SupplyEditDialog> createState() => _SupplyEditDialogState();
}

class _SupplyEditDialogState extends State<SupplyEditDialog> {
  final TextEditingController _fromSupplierIdController =
      TextEditingController();
  final TextEditingController _toStoreIdController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();
  List<dynamic> _suppliers = [];
  List<dynamic> _stores = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSuppliersAndStores();

    if (widget.supply != null) {
      _fromSupplierIdController.text = widget.supply!['fromSupplierId']
          .toString();
      _toStoreIdController.text = widget.supply!['toStoreId'].toString();
      _contentController.text = widget.supply!['content'];
      _statusController.text = widget.supply!['status'];
    } else {
      _statusController.text = 'оформлен';
    }
  }

  Future<void> _loadSuppliersAndStores() async {
    try {
      final [suppliersResponse, storesResponse] = await Future.wait([
        http.get(Uri.parse('${GlobalConfig.baseUrl}/suppliers')),
        http.get(Uri.parse('${GlobalConfig.baseUrl}/stores')),
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
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _saveSupply() async {
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

      final response = widget.supply == null
          ? await http.post(
              Uri.parse('${GlobalConfig.baseUrl}/supplies'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            )
          : await http.put(
              Uri.parse(
                '${GlobalConfig.baseUrl}/supplies/${widget.supply!['id']}',
              ),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            );

      if (response.statusCode == 200) {
        widget.onSupplyUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.supply == null
                    ? 'Поставка создана'
                    : 'Поставка обновлена',
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
      title: Text(
        widget.supply == null ? 'Новая поставка' : 'Редактировать поставку',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Содержимое (JSON)',
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
          onPressed: _isLoading ? null : _saveSupply,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.supply == null ? 'Создать' : 'Сохранить'),
        ),
      ],
    );
  }
}

// Диалог подробной информации о поставке
class SupplyDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> supply;

  const SupplyDetailsDialog({super.key, required this.supply});

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

  Widget _parseContent() {
    try {
      final content = json.decode(supply['content']);
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

    return _buildInfoRow('Содержимое:', supply['content']);
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
                  'Поставка #${supply['id']}',
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
                    supply['status'].toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(supply['status']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Color(
                    _getStatusColor(supply['status']).value,
                  ).withAlpha(25),
                ),
              ),
              const SizedBox(height: 16),

              // Информация о поставщике
              const Text(
                'Поставщик:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('ID:', supply['fromSupplierId'].toString()),
              if (supply['fromSupplier'] != null) ...[
                _buildInfoRow('Название:', supply['fromSupplier']['name']),
                _buildInfoRow('Адрес:', supply['fromSupplier']['address']),
                if (supply['fromSupplier']['description'] != null)
                  _buildInfoRow(
                    'Описание:',
                    supply['fromSupplier']['description'],
                  ),
              ],
              const SizedBox(height: 16),

              // Информация о магазине
              const Text(
                'Магазин:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('ID:', supply['toStoreId'].toString()),
              if (supply['toStore'] != null) ...[
                _buildInfoRow('Название:', supply['toStore']['name']),
                _buildInfoRow('Адрес:', supply['toStore']['address']),
                if (supply['toStore']['description'] != null)
                  _buildInfoRow('Описание:', supply['toStore']['description']),
              ],
              const SizedBox(height: 16),

              // Информация о содержимом
              const Text(
                'Содержимое:',
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
              if (supply['createdAt'] != null)
                _buildInfoRow(
                  'Дата создания:',
                  _formatDate(supply['createdAt']),
                ),
              if (supply['updatedAt'] != null)
                _buildInfoRow(
                  'Дата обновления:',
                  _formatDate(supply['updatedAt']),
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
            width: 120,
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
