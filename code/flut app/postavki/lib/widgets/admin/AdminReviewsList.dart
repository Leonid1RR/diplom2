import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../main.dart';

class AdminReviewsList extends StatefulWidget {
  const AdminReviewsList({super.key});

  @override
  State<AdminReviewsList> createState() => _AdminReviewsListState();
}

class _AdminReviewsListState extends State<AdminReviewsList> {
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${GlobalConfig.baseUrl}/reviews'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _reviews = data;
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

  Future<void> _deleteReview(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление отзыва'),
        content: const Text('Вы уверены, что хотите удалить этот отзыв?'),
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
          Uri.parse('${GlobalConfig.baseUrl}/reviews/$id'),
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Отзыв удален')));
          }
          _loadReviews();
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

  void _editReview(Map<String, dynamic> review) {
    showDialog(
      context: context,
      builder: (context) =>
          ReviewEditDialog(review: review, onReviewUpdated: _loadReviews),
    );
  }

  void _addNewReview() {
    showDialog(
      context: context,
      builder: (context) =>
          ReviewEditDialog(review: null, onReviewUpdated: _loadReviews),
    );
  }

  void _viewReviewDetails(Map<String, dynamic> review) {
    showDialog(
      context: context,
      builder: (context) => ReviewDetailsDialog(review: review),
    );
  }

  List<dynamic> _getFilteredReviews() {
    List<dynamic> filtered = _reviews;

    // Фильтрация по поиску
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((review) {
        final text = review['text']?.toString().toLowerCase() ?? '';
        final storeName =
            review['fromStore']?['name']?.toString().toLowerCase() ?? '';
        final supplierName =
            review['toSupplier']?['name']?.toString().toLowerCase() ?? '';

        return text.contains(_searchQuery.toLowerCase()) ||
            storeName.contains(_searchQuery.toLowerCase()) ||
            supplierName.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Фильтрация по типу (если нужна)
    if (_filterType != 'all') {
      // Можно добавить фильтрацию по оценке или другим параметрам
    }

    // Сортировка по дате (новые первыми)
    filtered.sort((a, b) {
      final dateA = a['createdAt'] ?? '';
      final dateB = b['createdAt'] ?? '';
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredReviews = _getFilteredReviews();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отзывы'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReviews),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewReview,
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
                labelText: 'Поиск отзывов',
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
                  'Всего: ${_reviews.length}',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (_searchQuery.isNotEmpty)
                  Text(
                    'Найдено: ${filteredReviews.length}',
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
                          onPressed: _loadReviews,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : filteredReviews.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.reviews, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет отзывов'),
                        SizedBox(height: 8),
                        Text(
                          'Нажмите + чтобы добавить новый отзыв',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredReviews.length,
                    itemBuilder: (context, index) {
                      final review = filteredReviews[index];
                      return ReviewCard(
                        review: review,
                        onEdit: () => _editReview(review),
                        onDelete: () => _deleteReview(review['id']),
                        onViewDetails: () => _viewReviewDetails(review),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Карточка отзыва
class ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;

  const ReviewCard({
    super.key,
    required this.review,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.reviews, color: Colors.purple),
        ),
        title: Text(
          _getTruncatedText(review['text'] ?? ''),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Магазин: ${review['fromStore']?['name'] ?? 'Неизвестно'}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Поставщик: ${review['toSupplier']?['name'] ?? 'Неизвестно'}',
              style: const TextStyle(fontSize: 12),
            ),
            if (review['createdAt'] != null)
              Text(
                _formatDate(review['createdAt']),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
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

  String _getTruncatedText(String text) {
    if (text.length > 100) {
      return '${text.substring(0, 100)}...';
    }
    return text;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

// Диалог редактирования/создания отзыва
class ReviewEditDialog extends StatefulWidget {
  final Map<String, dynamic>? review;
  final VoidCallback onReviewUpdated;

  const ReviewEditDialog({
    super.key,
    this.review,
    required this.onReviewUpdated,
  });

  @override
  State<ReviewEditDialog> createState() => _ReviewEditDialogState();
}

class _ReviewEditDialogState extends State<ReviewEditDialog> {
  final TextEditingController _fromStoreIdController = TextEditingController();
  final TextEditingController _toSupplierIdController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  List<dynamic> _stores = [];
  List<dynamic> _suppliers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStoresAndSuppliers();

    if (widget.review != null) {
      _fromStoreIdController.text = widget.review!['fromStoreId'].toString();
      _toSupplierIdController.text = widget.review!['toSupplierId'].toString();
      _textController.text = widget.review!['text'];
    }
  }

  Future<void> _loadStoresAndSuppliers() async {
    try {
      final [storesResponse, suppliersResponse] = await Future.wait([
        http.get(Uri.parse('${GlobalConfig.baseUrl}/stores')),
        http.get(Uri.parse('${GlobalConfig.baseUrl}/suppliers')),
      ]);

      if (storesResponse.statusCode == 200) {
        setState(() {
          _stores = json.decode(storesResponse.body);
        });
      }

      if (suppliersResponse.statusCode == 200) {
        setState(() {
          _suppliers = json.decode(suppliersResponse.body);
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _saveReview() async {
    if (_fromStoreIdController.text.isEmpty ||
        _toSupplierIdController.text.isEmpty ||
        _textController.text.isEmpty) {
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
        'fromStoreId': int.parse(_fromStoreIdController.text),
        'toSupplierId': int.parse(_toSupplierIdController.text),
        'text': _textController.text,
      };

      final response = widget.review == null
          ? await http.post(
              Uri.parse('${GlobalConfig.baseUrl}/reviews'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            )
          : await http.put(
              Uri.parse(
                '${GlobalConfig.baseUrl}/reviews/${widget.review!['id']}',
              ),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data),
            );

      if (response.statusCode == 200) {
        widget.onReviewUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.review == null ? 'Отзыв создан' : 'Отзыв обновлен',
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
        widget.review == null ? 'Новый отзыв' : 'Редактировать отзыв',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Магазин
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fromStoreIdController,
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
                      _fromStoreIdController.text = value;
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

            // Поставщик
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _toSupplierIdController,
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
                      _toSupplierIdController.text = value;
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

            // Текст отзыва
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Текст отзыва*',
                border: OutlineInputBorder(),
                hintText: 'Введите текст отзыва...',
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
          onPressed: _isLoading ? null : _saveReview,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.review == null ? 'Создать' : 'Сохранить'),
        ),
      ],
    );
  }
}

// Диалог подробной информации об отзыве
class ReviewDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> review;

  const ReviewDetailsDialog({super.key, required this.review});

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
              const Center(
                child: Text(
                  'Отзыв',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              // Текст отзыва
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  review['text'],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Информация о магазине
              const Text(
                'Магазин:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('ID:', review['fromStoreId'].toString()),
              if (review['fromStore'] != null) ...[
                _buildInfoRow('Название:', review['fromStore']['name']),
                _buildInfoRow('Адрес:', review['fromStore']['address']),
                if (review['fromStore']['description'] != null &&
                    review['fromStore']['description'].isNotEmpty)
                  _buildInfoRow(
                    'Описание:',
                    review['fromStore']['description'],
                  ),
              ],
              const SizedBox(height: 16),

              // Информация о поставщике
              const Text(
                'Поставщик:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('ID:', review['toSupplierId'].toString()),
              if (review['toSupplier'] != null) ...[
                _buildInfoRow('Название:', review['toSupplier']['name']),
                _buildInfoRow('Адрес:', review['toSupplier']['address']),
                if (review['toSupplier']['description'] != null &&
                    review['toSupplier']['description'].isNotEmpty)
                  _buildInfoRow(
                    'Описание:',
                    review['toSupplier']['description'],
                  ),
              ],
              const SizedBox(height: 16),

              // Дополнительная информация
              const Text(
                'Дополнительно:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (review['createdAt'] != null)
                _buildInfoRow(
                  'Дата создания:',
                  _formatDate(review['createdAt']),
                ),
              if (review['updatedAt'] != null)
                _buildInfoRow(
                  'Дата обновления:',
                  _formatDate(review['updatedAt']),
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
