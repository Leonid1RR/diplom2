import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../main.dart';

class AdminBatchesList extends StatefulWidget {
  const AdminBatchesList({super.key});

  @override
  State<AdminBatchesList> createState() => _AdminBatchesListState();
}

class _AdminBatchesListState extends State<AdminBatchesList> {
  List<dynamic> _batches = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${GlobalConfig.baseUrl}/batches'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _batches = data;
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

  Future<void> _deleteBatch(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление партии'),
        content: Text('Вы уверены, что хотите удалить партию "$name"?'),
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
          Uri.parse('${GlobalConfig.baseUrl}/batches/$id'),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Партия "$name" удалена')));
          _loadBatches();
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

  void _editBatch(Map<String, dynamic> batch) {
    showDialog(
      context: context,
      builder: (context) =>
          BatchEditDialog(batch: batch, onBatchUpdated: _loadBatches),
    );
  }

  void _addNewBatch() {
    showDialog(
      context: context,
      builder: (context) =>
          BatchEditDialog(batch: null, onBatchUpdated: _loadBatches),
    );
  }

  void _viewBatchDetails(Map<String, dynamic> batch) {
    showDialog(
      context: context,
      builder: (context) => BatchDetailsDialog(batch: batch),
    );
  }

  List<dynamic> _getFilteredBatches() {
    if (_searchQuery.isEmpty) return _batches;

    return _batches.where((batch) {
      return batch['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          batch['description'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (batch['supplier']?['name']?.toString().toLowerCase() ?? '').contains(
            _searchQuery.toLowerCase(),
          );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBatches = _getFilteredBatches();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Партии товаров'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBatches),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewBatch,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                labelText: 'Поиск партий',
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
                  'Всего: ${_batches.length}',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (_searchQuery.isNotEmpty)
                  Text(
                    'Найдено: ${filteredBatches.length}',
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
                          onPressed: _loadBatches,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : filteredBatches.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет партий товаров'),
                        SizedBox(height: 8),
                        Text(
                          'Нажмите + чтобы добавить новую партию',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredBatches.length,
                    itemBuilder: (context, index) {
                      final batch = filteredBatches[index];
                      return BatchCard(
                        batch: batch,
                        onEdit: () => _editBatch(batch),
                        onDelete: () =>
                            _deleteBatch(batch['id'], batch['name']),
                        onViewDetails: () => _viewBatchDetails(batch),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Карточка партии
class BatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;

  const BatchCard({
    super.key,
    required this.batch,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDetails,
  });

  Widget _buildPhotoWidget() {
    final photo = batch['photo'];

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
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.inventory, color: Colors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildPhotoWidget(),
        title: Text(
          batch['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Поставщик: ${batch['supplier']?['name'] ?? 'Неизвестно'}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('${batch['price']} руб'),
                  backgroundColor: Colors.green[50],
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('${batch['productCount']} шт'),
                  backgroundColor: Colors.blue[50],
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('${batch['expiration']} дн.'),
                  backgroundColor: Colors.purple[50],
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info, color: Colors.blue),
              onPressed: onViewDetails,
              tooltip: 'Подробности',
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: onEdit,
              tooltip: 'Редактировать',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Удалить',
            ),
          ],
        ),
        onTap: onViewDetails,
      ),
    );
  }
}

// Диалог редактирования/создания партии
class BatchEditDialog extends StatefulWidget {
  final Map<String, dynamic>? batch;
  final VoidCallback onBatchUpdated;

  const BatchEditDialog({super.key, this.batch, required this.onBatchUpdated});

  @override
  State<BatchEditDialog> createState() => _BatchEditDialogState();
}

class _BatchEditDialogState extends State<BatchEditDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _expirationController = TextEditingController(
    text: '30',
  );
  final TextEditingController _productCountController = TextEditingController(
    text: '1',
  );
  final TextEditingController _supplierIdController = TextEditingController();
  File? _selectedImage;
  String? _photoData;
  bool _isLoading = false;
  List<dynamic> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();

    if (widget.batch != null) {
      _nameController.text = widget.batch!['name'];
      _descriptionController.text = widget.batch!['description'] ?? '';
      _priceController.text = widget.batch!['price'].toString();
      _expirationController.text = widget.batch!['expiration'].toString();
      _productCountController.text = widget.batch!['productCount'].toString();
      _supplierIdController.text = widget.batch!['supplierId'].toString();
      _photoData = widget.batch!['photo'];
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final response = await http.get(
        Uri.parse('${GlobalConfig.baseUrl}/suppliers'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _suppliers = data;
        });
      }
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
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

  Future<void> _saveBatch() async {
    if (_nameController.text.isEmpty ||
        _supplierIdController.text.isEmpty ||
        _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Заполните обязательные поля (Название, ID поставщика, Цена)',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.tryParse(_priceController.text) ?? 0,
        'expiration': int.tryParse(_expirationController.text) ?? 30,
        'productCount': int.tryParse(_productCountController.text) ?? 1,
        'supplierId': int.parse(_supplierIdController.text),
        'photo': _photoData,
      };

      final response = widget.batch == null
          ? await http.post(
              Uri.parse('${GlobalConfig.baseUrl}/batches'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            )
          : await http.put(
              Uri.parse(
                '${GlobalConfig.baseUrl}/batches/${widget.batch!['id']}',
              ),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            );

      if (response.statusCode == 200) {
        widget.onBatchUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.batch == null ? 'Партия создана' : 'Партия обновлена',
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
        widget.batch == null ? 'Новая партия товаров' : 'Редактировать партию',
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

            // Цена
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Цена*',
                border: OutlineInputBorder(),
                suffixText: 'руб',
              ),
            ),
            const SizedBox(height: 12),

            // Срок годности
            TextField(
              controller: _expirationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Срок годности',
                border: OutlineInputBorder(),
                suffixText: 'дней',
              ),
            ),
            const SizedBox(height: 12),

            // Количество товаров
            TextField(
              controller: _productCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Количество в партии',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Поставщик
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _supplierIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ID поставщика*',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton(
                  itemBuilder: (context) => _suppliers.map((supplier) {
                    return PopupMenuItem(
                      value: supplier['id'].toString(),
                      child: Text(
                        '${supplier['name']} (ID: ${supplier['id']})',
                      ),
                    );
                  }).toList(),
                  onSelected: (value) {
                    setState(() {
                      _supplierIdController.text = value;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.list),
                  ),
                ),
              ],
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
          onPressed: _isLoading ? null : _saveBatch,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.batch == null ? 'Создать' : 'Сохранить'),
        ),
      ],
    );
  }
}

// Диалог подробной информации о партии
class BatchDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> batch;

  const BatchDetailsDialog({super.key, required this.batch});

  Widget _buildPhotoWidget() {
    final photo = batch['photo'];

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
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.inventory, size: 60, color: Colors.orange),
    );
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
              // Фото и основная информация
              Center(child: _buildPhotoWidget()),
              const SizedBox(height: 20),

              Center(
                child: Text(
                  batch['name'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Основная информация
              _buildInfoRow('ID:', batch['id'].toString()),
              _buildInfoRow('Описание:', batch['description'] ?? 'Нет'),
              _buildInfoRow('Цена:', '${batch['price']} руб'),
              _buildInfoRow(
                'Количество в партии:',
                '${batch['productCount']} шт',
              ),
              _buildInfoRow('Срок годности:', '${batch['expiration']} дней'),
              _buildInfoRow('Поставщик ID:', batch['supplierId'].toString()),
              if (batch['supplier'] != null)
                _buildInfoRow('Поставщик:', batch['supplier']['name']),
              const SizedBox(height: 8),

              // Расчеты
              const Divider(),
              const Text(
                'Расчеты:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                'Стоимость партии:',
                '${batch['price']} × ${batch['productCount']} = ${batch['price'] * batch['productCount']} руб',
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
}
