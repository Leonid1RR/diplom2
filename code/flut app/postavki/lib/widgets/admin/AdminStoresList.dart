import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../main.dart';

class AdminStoresList extends StatefulWidget {
  const AdminStoresList({super.key});

  @override
  State<AdminStoresList> createState() => _AdminStoresListState();
}

class _AdminStoresListState extends State<AdminStoresList> {
  List<dynamic> _stores = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${GlobalConfig.baseUrl}/stores'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _stores = data;
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

  Future<void> _deleteStore(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление магазина'),
        content: Text(
          'Вы уверены, что хотите удалить магазин "$name"? Все связанные данные (склад, товары, заказы) также будут удалены.',
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

    if (confirmed == true) {
      try {
        final response = await http.delete(
          Uri.parse('${GlobalConfig.baseUrl}/stores/$id'),
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Магазин "$name" удален')));
          }
          _loadStores();
        } else {
          final errorData = json.decode(response.body);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Ошибка удаления: ${errorData['error'] ?? response.statusCode}',
                ),
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

  void _editStore(Map<String, dynamic> store) {
    showDialog(
      context: context,
      builder: (context) =>
          StoreEditDialog(store: store, onStoreUpdated: _loadStores),
    );
  }

  void _addNewStore() {
    showDialog(
      context: context,
      builder: (context) =>
          StoreEditDialog(store: null, onStoreUpdated: _loadStores),
    );
  }

  void _viewStoreDetails(Map<String, dynamic> store) {
    showDialog(
      context: context,
      builder: (context) => StoreDetailsDialog(store: store),
    );
  }

  List<dynamic> _getFilteredStores() {
    if (_searchQuery.isEmpty) return _stores;

    return _stores.where((store) {
      return store['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          store['address'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (store['description']?.toString().toLowerCase() ?? '').contains(
            _searchQuery.toLowerCase(),
          );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStores = _getFilteredStores();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Магазины'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStores),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewStore,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Поиск
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  labelText: 'Поиск магазинов',
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
            ),

            // Информация
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Всего: ${_stores.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Text(
                      'Найдено: ${filteredStores.length}',
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
                            onPressed: _loadStores,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    )
                  : filteredStores.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Нет магазинов'),
                          SizedBox(height: 8),
                          Text(
                            'Нажмите + чтобы добавить новый магазин',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredStores.length,
                      itemBuilder: (context, index) {
                        final store = filteredStores[index];
                        return StoreCard(
                          store: store,
                          onEdit: () => _editStore(store),
                          onDelete: () =>
                              _deleteStore(store['id'], store['name']),
                          onViewDetails: () => _viewStoreDetails(store),
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

// Карточка магазина
class StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;

  const StoreCard({
    super.key,
    required this.store,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDetails,
  });

  Widget _buildPhotoWidget() {
    final photo = store['photo'];

    if (photo != null && photo is String && photo.isNotEmpty) {
      if (photo.startsWith('data:image/')) {
        try {
          final base64Data = photo.split(',').last;
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: MemoryImage(base64Decode(base64Data)),
                fit: BoxFit.cover,
              ),
            ),
          );
        } catch (e) {
          return _buildDefaultPhoto();
        }
      } else if (photo.startsWith('http')) {
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(photo),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    return _buildDefaultPhoto();
  }

  Widget _buildDefaultPhoto() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.store, color: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warehouse = store['warehouse'] ?? {};
    final supplies = store['supplies'] as List;
    final reviews = store['reviews'] as List;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фото
            _buildPhotoWidget(),
            const SizedBox(width: 12),

            // Текстовая информация и кнопки
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название
                  Text(
                    store['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Адрес
                  Text(
                    store['address'],
                    style: TextStyle(color: Colors.grey[700]),
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

                  // Плашки с данными
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(
                          'Товаров: ${warehouse['productCount'] ?? 0}',
                        ),
                        backgroundColor: Colors.blue.shade50,
                      ),
                      Chip(
                        label: Text('Заказов: ${supplies.length}'),
                        backgroundColor: Colors.orange.shade50,
                      ),
                      Chip(
                        label: Text('Отзывов: ${reviews.length}'),
                        backgroundColor: Colors.purple.shade50,
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
}

// Диалог редактирования/создания магазина
class StoreEditDialog extends StatefulWidget {
  final Map<String, dynamic>? store;
  final VoidCallback onStoreUpdated;

  const StoreEditDialog({super.key, this.store, required this.onStoreUpdated});

  @override
  State<StoreEditDialog> createState() => _StoreEditDialogState();
}

class _StoreEditDialogState extends State<StoreEditDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _photoData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.store != null) {
      _nameController.text = widget.store!['name'];
      _addressController.text = widget.store!['address'];
      _descriptionController.text = widget.store!['description'] ?? '';
      _passwordController.text = widget.store!['password'];
      _photoData = widget.store!['photo'];
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
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final imageType = pickedFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(imageType);

      setState(() {
        _photoData = 'data:$mimeType;base64,$base64Image';
      });
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

  Future<void> _saveStore() async {
    if (_nameController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заполните все обязательные поля'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text,
        'address': _addressController.text,
        'description': _descriptionController.text,
        'password': _passwordController.text,
        'photo': _photoData,
      };

      final response = widget.store == null
          ? await http.post(
              Uri.parse('${GlobalConfig.baseUrl}/stores'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            )
          : await http.put(
              Uri.parse(
                '${GlobalConfig.baseUrl}/stores/${widget.store!['id']}',
              ),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            );

      if (response.statusCode == 200) {
        widget.onStoreUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.store == null ? 'Магазин создан' : 'Магазин обновлен',
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
        widget.store == null ? 'Новый магазин' : 'Редактировать магазин',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Фото
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                  color: Colors.grey.shade100,
                ),
                child: _photoData != null && _photoData!.isNotEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: MemoryImage(
                              base64Decode(_photoData!.split(',').last),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Добавить фото',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Название
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название*',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Адрес
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Адрес*',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Описание
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Пароль
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Пароль*',
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
          onPressed: _isLoading ? null : _saveStore,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.store == null ? 'Создать' : 'Сохранить'),
        ),
      ],
    );
  }
}

// Диалог подробной информации о магазине
class StoreDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> store;

  const StoreDetailsDialog({super.key, required this.store});

  Widget _buildPhotoWidget() {
    final photo = store['photo'];

    if (photo != null && photo is String && photo.isNotEmpty) {
      if (photo.startsWith('data:image/')) {
        try {
          final base64Data = photo.split(',').last;
          return Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: MemoryImage(base64Decode(base64Data)),
                fit: BoxFit.cover,
              ),
            ),
          );
        } catch (e) {
          return _buildDefaultPhoto();
        }
      } else if (photo.startsWith('http')) {
        return Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(photo),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    return _buildDefaultPhoto();
  }

  Widget _buildDefaultPhoto() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.store, size: 60, color: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warehouse = store['warehouse'] ?? {};
    final supplies = store['supplies'] as List;
    final reviews = store['reviews'] as List;
    final warehouseProducts = warehouse['products'] as List? ?? [];

    return Dialog(
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Фото и основная информация
              Center(child: _buildPhotoWidget()),
              const SizedBox(height: 20),

              Center(
                child: Text(
                  store['name'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Основная информация
              _buildInfoRow('ID:', store['id'].toString()),
              _buildInfoRow('Адрес:', store['address']),
              _buildInfoRow('Описание:', store['description'] ?? 'Нет'),
              _buildInfoRow('Пароль:', store['password']),
              const SizedBox(height: 8),

              // Склад
              const Divider(),
              const Text(
                'Склад:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                'ID склада:',
                warehouse['id']?.toString() ?? 'Не создан',
              ),
              _buildInfoRow(
                'Товаров на складе:',
                '${warehouse['productCount'] ?? 0}',
              ),

              if (warehouseProducts.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Товары на складе:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...warehouseProducts.take(3).map((product) {
                  final productData = product['product'] ?? {};
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• ${productData['name']} - ${productData['price']} руб',
                    ),
                  );
                }),
                if (warehouseProducts.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '... и ещё ${warehouseProducts.length - 3} товаров',
                    ),
                  ),
              ],
              const SizedBox(height: 8),

              // Статистика
              const Divider(),
              const Text(
                'Статистика:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Всего заказов:', '${supplies.length}'),
              _buildInfoRow('Всего отзывов:', '${reviews.length}'),
              const SizedBox(height: 8),

              // Примеры данных
              if (supplies.isNotEmpty) ...[
                const Divider(),
                const Text(
                  'Последние заказы:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...supplies
                    .take(2)
                    .map(
                      (supply) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• Заказ #${supply['id']}'),
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                'Статус: ${supply['status']} | Поставщик: ${supply['fromSupplier']?['name'] ?? 'Неизвестно'}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (supplies.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('... и ещё ${supplies.length - 2} заказов'),
                  ),
              ],
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
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
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
}
