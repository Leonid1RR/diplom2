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
                    batch['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Поставщик
                  Text(
                    'Поставщик: ${batch['supplier']?['name'] ?? 'Неизвестно'}',
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

                  // Плашки с данными
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text('${batch['price']} руб'),
                        backgroundColor: Colors.green[50],
                      ),
                      Chip(
                        label: Text('${batch['itemsPerBatch']} шт/партия'),
                        backgroundColor: Colors.blue[50],
                      ),
                      Chip(
                        label: Text('${batch['expiration']} дн.'),
                        backgroundColor: Colors.purple[50],
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
  final TextEditingController _itemsPerBatchController = TextEditingController(
    text: '10',
  );
  final TextEditingController _quantityController = TextEditingController(
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
      _itemsPerBatchController.text = widget.batch!['itemsPerBatch'].toString();
      _quantityController.text = widget.batch!['quantity'].toString();
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
    // Проверяем обязательные поля
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Название обязательно'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_supplierIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID поставщика обязательно'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Цена обязательна'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_itemsPerBatchController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Количество товаров в партии обязательно'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Количество партий обязательно'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Преобразуем данные в правильные типы
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final expiration = int.tryParse(_expirationController.text) ?? 30;
      final itemsPerBatch = int.tryParse(_itemsPerBatchController.text) ?? 10;
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final supplierId = int.tryParse(_supplierIdController.text) ?? 0;

      final data = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'expiration': expiration,
        'price': price,
        'photo': _photoData,
        'itemsPerBatch': itemsPerBatch,
        'quantity': quantity,
        'supplierId': supplierId,
      };

      print('Отправляемые данные: $data');

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

      print('Код ответа: ${response.statusCode}');
      print('Тело ответа: ${response.body}');

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
        throw Exception(
          'Ошибка сервера: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
      print('Ошибка при сохранении: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsPerBatch = int.tryParse(_itemsPerBatchController.text) ?? 10;
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final totalItems = itemsPerBatch * quantity;

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
                labelText: 'Цена за партию*',
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
                labelText: 'Срок годности товаров',
                border: OutlineInputBorder(),
                suffixText: 'дней',
              ),
            ),
            const SizedBox(height: 12),

            // Товаров в партии
            TextField(
              controller: _itemsPerBatchController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Товаров в одной партии*',
                border: OutlineInputBorder(),
                hintText: '10',
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Количество таких партий
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Количество таких партий*',
                border: OutlineInputBorder(),
                hintText: '1',
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Информация о расчетах
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.calculate, color: Colors.blue[700], size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'ИТОГО:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$itemsPerBatch товаров × $quantity партий = $totalItems товаров',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
    final itemsPerBatch = batch['itemsPerBatch'] ?? 0;
    final quantity = batch['quantity'] ?? 0;
    final totalItems = itemsPerBatch * quantity;
    final totalPrice = (batch['price'] ?? 0) * quantity;

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
                  batch['name'] ?? 'Без названия',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Основная информация
              _buildInfoRow('ID:', batch['id']?.toString() ?? 'Неизвестно'),
              _buildInfoRow('Описание:', batch['description'] ?? 'Нет'),
              _buildInfoRow('Цена за партию:', '${batch['price'] ?? 0} руб'),
              _buildInfoRow('Товаров в партии:', '$itemsPerBatch шт'),
              _buildInfoRow('Количество партий:', '$quantity шт'),
              _buildInfoRow(
                'Срок годности:',
                '${batch['expiration'] ?? 0} дней',
              ),
              _buildInfoRow(
                'Поставщик ID:',
                batch['supplierId']?.toString() ?? 'Неизвестно',
              ),
              if (batch['supplier'] != null)
                _buildInfoRow(
                  'Поставщик:',
                  batch['supplier']['name'] ?? 'Неизвестно',
                ),
              const SizedBox(height: 8),

              // Расчеты
              const Divider(),
              const Text(
                'Расчеты:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                'Всего товаров:',
                '$itemsPerBatch × $quantity = $totalItems шт',
              ),
              _buildInfoRow(
                'Общая стоимость:',
                '${batch['price'] ?? 0} × $quantity = $totalPrice руб',
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
}
