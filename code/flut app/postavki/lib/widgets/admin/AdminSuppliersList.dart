import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../main.dart';

class AdminSuppliersList extends StatefulWidget {
  const AdminSuppliersList({super.key});

  @override
  State<AdminSuppliersList> createState() => _AdminSuppliersListState();
}

class _AdminSuppliersListState extends State<AdminSuppliersList> {
  List<dynamic> _suppliers = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${GlobalConfig.baseUrl}/suppliers'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _suppliers = data;
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

  Future<void> _deleteSupplier(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление поставщика'),
        content: Text('Вы уверены, что хотите удалить поставщика "$name"?'),
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
          Uri.parse('${GlobalConfig.baseUrl}/suppliers/$id'),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Поставщик "$name" удален')));
          _loadSuppliers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: ${response.statusCode}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  void _editSupplier(Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (context) => SupplierEditDialog(
        supplier: supplier,
        onSupplierUpdated: _loadSuppliers,
      ),
    );
  }

  void _addNewSupplier() {
    showDialog(
      context: context,
      builder: (context) =>
          SupplierEditDialog(supplier: null, onSupplierUpdated: _loadSuppliers),
    );
  }

  void _viewSupplierDetails(Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (context) => SupplierDetailsDialog(supplier: supplier),
    );
  }

  List<dynamic> _getFilteredSuppliers() {
    if (_searchQuery.isEmpty) return _suppliers;

    return _suppliers.where((supplier) {
      return supplier['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          supplier['address'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          supplier['description'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredSuppliers = _getFilteredSuppliers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поставщики'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSuppliers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewSupplier,
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
                  labelText: 'Поиск поставщиков',
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
                    'Всего: ${_suppliers.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Text(
                      'Найдено: ${filteredSuppliers.length}',
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
                            onPressed: _loadSuppliers,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    )
                  : filteredSuppliers.isEmpty
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
                          Text('Нет поставщиков'),
                          SizedBox(height: 8),
                          Text(
                            'Нажмите + чтобы добавить нового поставщика',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredSuppliers.length,
                      itemBuilder: (context, index) {
                        final supplier = filteredSuppliers[index];
                        return SupplierCard(
                          supplier: supplier,
                          onEdit: () => _editSupplier(supplier),
                          onDelete: () =>
                              _deleteSupplier(supplier['id'], supplier['name']),
                          onViewDetails: () => _viewSupplierDetails(supplier),
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

// Карточка поставщика
class SupplierCard extends StatelessWidget {
  final Map<String, dynamic> supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;

  const SupplierCard({
    super.key,
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDetails,
  });

  Widget _buildPhotoWidget() {
    final photo = supplier['photo'];

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
        color: Colors.deepPurple[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.local_shipping, color: Colors.deepPurple),
    );
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
                    supplier['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Адрес
                  Text(
                    supplier['address'],
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
                          'Партий: ${(supplier['batches'] as List).length}',
                        ),
                        backgroundColor: Colors.blue[50],
                      ),
                      Chip(
                        label: Text(
                          'Поставок: ${(supplier['supplies'] as List).length}',
                        ),
                        backgroundColor: Colors.green[50],
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

// Диалог редактирования/создания поставщика
class SupplierEditDialog extends StatefulWidget {
  final Map<String, dynamic>? supplier;
  final VoidCallback onSupplierUpdated;

  const SupplierEditDialog({
    super.key,
    this.supplier,
    required this.onSupplierUpdated,
  });

  @override
  State<SupplierEditDialog> createState() => _SupplierEditDialogState();
}

class _SupplierEditDialogState extends State<SupplierEditDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  File? _selectedImage;
  String? _photoData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      _nameController.text = widget.supplier!['name'];
      _addressController.text = widget.supplier!['address'];
      _descriptionController.text = widget.supplier!['description'] ?? '';
      _passwordController.text = widget.supplier!['password'];
      _photoData = widget.supplier!['photo'];
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
        _selectedImage = File(pickedFile.path);
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

  Future<void> _saveSupplier() async {
    if (_nameController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все обязательные поля'),
          backgroundColor: Colors.red,
        ),
      );
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

      final response = widget.supplier == null
          ? await http.post(
              Uri.parse('${GlobalConfig.baseUrl}/suppliers'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            )
          : await http.put(
              Uri.parse(
                '${GlobalConfig.baseUrl}/suppliers/${widget.supplier!['id']}',
              ),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            );

      if (response.statusCode == 200) {
        widget.onSupplierUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.supplier == null
                    ? 'Поставщик создан'
                    : 'Поставщик обновлен',
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
        widget.supplier == null
            ? 'Новый поставщик'
            : 'Редактировать поставщика',
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
                  color: Colors.grey[100],
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
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Добавить фото',
                            style: TextStyle(
                              color: Colors.grey[600],
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
          onPressed: _isLoading ? null : _saveSupplier,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.supplier == null ? 'Создать' : 'Сохранить'),
        ),
      ],
    );
  }
}

// Диалог подробной информации о поставщике
class SupplierDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> supplier;

  const SupplierDetailsDialog({super.key, required this.supplier});

  Widget _buildPhotoWidget() {
    final photo = supplier['photo'];

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
        color: Colors.deepPurple[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.local_shipping,
        size: 60,
        color: Colors.deepPurple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batches = supplier['batches'] as List;
    final supplies = supplier['supplies'] as List;
    final reviews = supplier['reviews'] as List;

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
                  supplier['name'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Основная информация
              _buildInfoRow('ID:', supplier['id'].toString()),
              _buildInfoRow('Адрес:', supplier['address']),
              _buildInfoRow('Описание:', supplier['description'] ?? 'Нет'),
              _buildInfoRow('Пароль:', supplier['password']),
              _buildInfoRow('Кол-во партий:', '${batches.length}'),
              const SizedBox(height: 8),

              // Статистика
              const Divider(),
              const Text(
                'Статистика:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Всего партий товаров:', '${batches.length}'),
              _buildInfoRow('Всего поставок:', '${supplies.length}'),
              _buildInfoRow('Всего отзывов:', '${reviews.length}'),
              const SizedBox(height: 8),

              // Примеры данных
              if (batches.isNotEmpty) ...[
                const Divider(),
                const Text(
                  'Партии товаров:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...batches
                    .take(3)
                    .map(
                      (batch) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '• ${batch['name']} (${batch['itemsPerBatch']} шт/партия)',
                        ),
                      ),
                    ),
                if (batches.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('... и ещё ${batches.length - 3} партий'),
                  ),
              ],

              if (reviews.isNotEmpty) ...[
                const Divider(),
                const Text(
                  'Последние отзывы:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...reviews
                    .take(2)
                    .map(
                      (review) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ${review['fromStore']?['name'] ?? 'Магазин'}:',
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text('"${review['text']}"'),
                            ),
                          ],
                        ),
                      ),
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
