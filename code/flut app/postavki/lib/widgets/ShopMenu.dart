import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart'; // или правильный путь

class ShopMenu extends StatefulWidget {
  final Map<String, dynamic> store;

  const ShopMenu({super.key, required this.store});

  @override
  State<ShopMenu> createState() => _ShopMenuState();
}

class _ShopMenuState extends State<ShopMenu> {
  final String baseUrl = GlobalConfig.baseUrl;
  int _currentIndex = 0;

  // Данные
  List<dynamic> warehouseProducts = [];
  List<dynamic> allBatches = [];
  List<dynamic> supplies = [];
  List<dynamic> reviews = [];
  Map<String, dynamic> storeData = {};

  // Поиск и фильтры
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name';
  String _filterCategory = 'all';

  // Сортировка заказов
  String _orderSortBy = 'id';
  String _orderFilterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadStoreData();
    await _loadWarehouseProducts();
    await _loadAllBatches();
    await _loadSupplies();
  }

  Future<void> _loadStoreData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/stores'));
      if (response.statusCode == 200) {
        final List<dynamic> stores = jsonDecode(response.body);
        final currentStore = stores.firstWhere(
          (s) => s['id'] == widget.store['id'],
          orElse: () => widget.store,
        );
        setState(() {
          storeData = currentStore;
        });
      }
    } catch (e) {
      debugPrint('Error loading store data: $e');
    }
  }

  Future<void> _loadWarehouseProducts() async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/warehouses/store/${widget.store['id']}/products-grouped',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          warehouseProducts = data['groupedProducts'] ?? [];
        });
        debugPrint('✅ Loaded ${warehouseProducts.length} grouped products');
      } else {
        debugPrint('❌ Server returned ${response.statusCode}');
        // Fallback to regular endpoint
        await _loadWarehouseProductsFallback();
      }
    } catch (e) {
      debugPrint('Error loading warehouse products: $e');
      // Fallback to regular endpoint if grouped endpoint fails
      await _loadWarehouseProductsFallback();
    }
  }

  Future<void> _loadWarehouseProductsFallback() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/warehouses/store/${widget.store['id']}'),
      );
      if (response.statusCode == 200) {
        final warehouse = jsonDecode(response.body);
        final productsOnWarehouse = warehouse['products'] ?? [];

        // Группируем товары по одинаковым характеристикам
        final Map<String, dynamic> groupedProducts = {};

        for (var productOnWarehouse in productsOnWarehouse) {
          final product = productOnWarehouse['product'];
          final key =
              '${product['name']}_${product['description']}_${product['expiration']}_${product['price']}_${product['photo'] ?? ''}';

          if (groupedProducts.containsKey(key)) {
            groupedProducts[key]['count'] += 1;
            groupedProducts[key]['warehouseIds'].add(productOnWarehouse['id']);
          } else {
            groupedProducts[key] = {
              'product': product,
              'count': 1,
              'warehouseIds': [productOnWarehouse['id']],
              'firstWarehouseId': productOnWarehouse['id'],
            };
          }
        }

        setState(() {
          warehouseProducts = groupedProducts.values.toList();
        });
        debugPrint(
          '✅ Loaded ${warehouseProducts.length} products via fallback',
        );
      }
    } catch (e) {
      debugPrint('Error loading warehouse products fallback: $e');
    }
  }

  Future<void> _loadAllBatches() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/batches'));
      if (response.statusCode == 200) {
        setState(() {
          allBatches = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error loading batches: $e');
    }
  }

  Future<void> _loadSupplies() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/supplies'));
      if (response.statusCode == 200) {
        final List<dynamic> allSupplies = jsonDecode(response.body);
        setState(() {
          supplies = allSupplies
              .where((supply) => supply['toStoreId'] == widget.store['id'])
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading supplies: $e');
    }
  }

  // Функция для генерации накладной - ИСПРАВЛЕННАЯ
  // Функция для генерации накладной - ДЛЯ PDF
  Future<void> _generateInvoice(int supplyId) async {
    try {
      debugPrint('📝 Generating PDF invoice for supply: $supplyId');

      final response = await http.get(
        Uri.parse('$baseUrl/api/supplies/$supplyId/invoice'),
      );

      if (response.statusCode == 200) {
        // Получаем директорию для сохранения файла
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/invoice-$supplyId.pdf';

        // Сохраняем файл
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        debugPrint('✅ PDF invoice saved to: $filePath');

        // Открываем файл
        final result = await OpenFile.open(filePath);

        if (result.type != ResultType.done) {
          debugPrint('❌ Error opening PDF: ${result.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'PDF накладная сохранена, но не открыта автоматически',
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PDF накладная успешно сгенерирована и открыта'),
              ),
            );
          }
        }
      } else {
        debugPrint('❌ Server returned ${response.statusCode}');
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error generating PDF invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка генерации PDF накладной: $e')),
        );
      }
    }
  }

  // Вкладка склада
  Widget _buildWarehouseTab() {
    List<dynamic> filteredProducts = _filterAndSortProducts(warehouseProducts);

    return Column(
      children: [
        // Поиск и фильтры
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Поиск товара',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(
                          value: 'name',
                          child: Text('По названию'),
                        ),
                        DropdownMenuItem(
                          value: 'price',
                          child: Text('По цене'),
                        ),
                        DropdownMenuItem(
                          value: 'expiration',
                          child: Text('По сроку годности'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortBy = value!;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Сортировка',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterCategory,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Все товары'),
                        ),
                        DropdownMenuItem(
                          value: 'expiring',
                          child: Text('С истекающим сроком'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterCategory = value!;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Фильтр'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadWarehouseProducts,
            child: filteredProducts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warehouse, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет товаров на складе'),
                        SizedBox(height: 8),
                        Text(
                          'Закажите товары во вкладке "Поставки"',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final groupedProduct = filteredProducts[index];
                      final product = groupedProduct['product'];
                      final count = groupedProduct['count'];
                      final warehouseIds = List<int>.from(
                        groupedProduct['warehouseIds'],
                      );

                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          leading:
                              product['photo'] != null &&
                                  product['photo'].isNotEmpty &&
                                  product['photo'].startsWith('data:image/')
                              ? Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: MemoryImage(
                                        base64Decode(
                                          product['photo'].split(',').last,
                                        ),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_basket,
                                    color: Colors.grey,
                                  ),
                                ),
                          title: Text(product['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Цена: ${product['price']} руб'),
                              Text('Количество: $count шт'),
                              Text(
                                'Срок годности: ${product['expiration']} дней',
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Редактировать'),
                              ),
                              if (count > 1)
                                const PopupMenuItem(
                                  value: 'sell_part',
                                  child: Text('Продать часть'),
                                ),
                              const PopupMenuItem(
                                value: 'sell_one',
                                child: Text('Продать 1 шт'),
                              ),
                              const PopupMenuItem(
                                value: 'delete_all',
                                child: Text('Удалить все'),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editProduct(product, warehouseIds);
                              } else if (value == 'sell_part') {
                                _sellPartOfProduct(groupedProduct);
                              } else if (value == 'sell_one') {
                                _sellOneProduct(warehouseIds);
                              } else if (value == 'delete_all') {
                                _deleteAllProducts(warehouseIds);
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

  List<dynamic> _filterAndSortProducts(List<dynamic> products) {
    List<dynamic> filtered = products.where((groupedProduct) {
      final product = groupedProduct['product'];
      final matchesSearch = product['name'].toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );

      bool matchesFilter = true;
      if (_filterCategory == 'expiring') {
        matchesFilter = product['expiration'] <= 7;
      }

      return matchesSearch && matchesFilter;
    }).toList();

    // Сортировка
    filtered.sort((a, b) {
      final productA = a['product'];
      final productB = b['product'];
      switch (_sortBy) {
        case 'price':
          return productA['price'].compareTo(productB['price']);
        case 'expiration':
          return productA['expiration'].compareTo(productB['expiration']);
        case 'name':
        default:
          return productA['name'].compareTo(productB['name']);
      }
    });

    return filtered;
  }

  void _editProduct(Map<String, dynamic> product, List<int> warehouseIds) {
    showDialog(
      context: context,
      builder: (context) => ProductEditDialog(
        product: product,
        warehouseIds: warehouseIds,
        onProductUpdated: _loadWarehouseProducts,
      ),
    );
  }

  void _sellPartOfProduct(Map<String, dynamic> groupedProduct) {
    final product = groupedProduct['product'];
    final currentCount = groupedProduct['count'];
    final warehouseIds = List<int>.from(groupedProduct['warehouseIds']);

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Продать часть ${product['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Доступно: $currentCount шт'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Количество для продажи',
                border: OutlineInputBorder(),
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
              final quantity = int.tryParse(controller.text) ?? 0;
              if (quantity > 0 && quantity <= currentCount) {
                await _sellMultipleProducts(warehouseIds.sublist(0, quantity));
                if (mounted) {
                  Navigator.pop(context);
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Введите число от 1 до $currentCount'),
                    ),
                  );
                }
              }
            },
            child: const Text('Продать'),
          ),
        ],
      ),
    );
  }

  Future<void> _sellOneProduct(List<int> warehouseIds) async {
    if (warehouseIds.isNotEmpty) {
      await _sellMultipleProducts([warehouseIds.first]);
    }
  }

  Future<void> _sellMultipleProducts(List<int> warehouseIds) async {
    try {
      if (warehouseIds.length == 1) {
        // Одиночное удаление
        final response = await http.delete(
          Uri.parse('$baseUrl/warehouse-products/${warehouseIds.first}'),
        );

        if (response.statusCode == 200) {
          _loadWarehouseProducts();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Товар продан')));
          }
        } else {
          throw Exception('Server returned ${response.statusCode}');
        }
      } else {
        // Массовое удаление
        final response = await http.post(
          Uri.parse('$baseUrl/warehouse-products/bulk-delete'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'warehouseIds': warehouseIds}),
        );

        if (response.statusCode == 200) {
          _loadWarehouseProducts();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Продано ${warehouseIds.length} единиц товара'),
              ),
            );
          }
        } else {
          throw Exception('Server returned ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка продажи: $e')));
      }
    }
  }

  Future<void> _deleteAllProducts(List<int> warehouseIds) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить все товары?'),
        content: Text(
          'Вы уверены, что хотите удалить все ${warehouseIds.length} шт этого товара?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _sellMultipleProducts(warehouseIds);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Вкладка поставок
  Widget _buildBatchesTab() {
    List<dynamic> filteredBatches = _filterAndSortBatches(allBatches);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Поиск партий',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAllBatches,
            child: filteredBatches.isEmpty
                ? const Center(child: Text('Нет доступных партий'))
                : ListView.builder(
                    itemCount: filteredBatches.length,
                    itemBuilder: (context, index) {
                      final batch = filteredBatches[index];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          leading:
                              batch['photo'] != null &&
                                  batch['photo'].isNotEmpty &&
                                  batch['photo'].startsWith('data:image/')
                              ? Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: MemoryImage(
                                        base64Decode(
                                          batch['photo'].split(',').last,
                                        ),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : Container(
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
                              Text(
                                'Поставщик: ${batch['supplier']?['name'] ?? 'Неизвестно'}',
                              ),
                              Text('Цена за партию: ${batch['price']} руб'),
                              Text(
                                'Количество в партии: ${batch['productCount']} шт',
                              ),
                              Text(
                                'Срок годности: ${batch['expiration']} дней',
                              ),
                              Text('Описание: ${batch['description']}'),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => _showBatchOrderDialog(batch),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  List<dynamic> _filterAndSortBatches(List<dynamic> batches) {
    return batches.where((batch) {
      return batch['name'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _showBatchOrderDialog(Map<String, dynamic> batch) {
    showDialog(
      context: context,
      builder: (context) => BatchOrderDialog(
        batch: batch,
        storeId: widget.store['id'],
        onOrderCreated: _loadSupplies,
      ),
    );
  }

  // Вкладка заказов
  Widget _buildOrdersTab() {
    List<dynamic> filteredOrders = _filterAndSortOrders(supplies);

    return Column(
      children: [
        // Фильтры и сортировка заказов
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _orderSortBy,
                      items: const [
                        DropdownMenuItem(
                          value: 'id',
                          child: Text('По номеру заказа'),
                        ),
                        DropdownMenuItem(
                          value: 'status',
                          child: Text('По статусу'),
                        ),
                        DropdownMenuItem(
                          value: 'supplier',
                          child: Text('По поставщику'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _orderSortBy = value!;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Сортировка',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _orderFilterStatus,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Все заказы'),
                        ),
                        DropdownMenuItem(
                          value: 'оформлен',
                          child: Text('Оформленные'),
                        ),
                        DropdownMenuItem(
                          value: 'отправлен',
                          child: Text('Отправленные'),
                        ),
                        DropdownMenuItem(
                          value: 'получено',
                          child: Text('Полученные'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _orderFilterStatus = value!;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Статус'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadSupplies,
            child: filteredOrders.isEmpty
                ? const Center(child: Text('Нет заказов'))
                : ListView.builder(
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final supply = filteredOrders[index];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            ListTile(
                              title: Text('Заказ #${supply['id']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Поставщик: ${supply['fromSupplier']?['name'] ?? 'Неизвестно'}',
                                  ),
                                  Text(
                                    'Содержимое: ${_parseSupplyContent(supply['content'])}',
                                  ),
                                  Text('Статус: ${supply['status']}'),
                                  Text(
                                    'Дата создания: ${_formatDate(supply['createdAt'] ?? '')}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: _buildOrderActions(supply),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  List<dynamic> _filterAndSortOrders(List<dynamic> orders) {
    // Фильтрация по статусу
    List<dynamic> filtered = orders.where((order) {
      if (_orderFilterStatus == 'all') return true;
      return order['status'] == _orderFilterStatus;
    }).toList();

    // Сортировка
    filtered.sort((a, b) {
      switch (_orderSortBy) {
        case 'status':
          return a['status'].compareTo(b['status']);
        case 'supplier':
          final supplierA = a['fromSupplier']?['name'] ?? '';
          final supplierB = b['fromSupplier']?['name'] ?? '';
          return supplierA.compareTo(supplierB);
        case 'id':
        default:
          return a['id'].compareTo(b['id']);
      }
    });

    return filtered;
  }

  String _parseSupplyContent(String content) {
    try {
      final data = jsonDecode(content);
      if (data is Map) {
        if (data.containsKey('batchName')) {
          return '${data['batchName']} (${data['quantity']} партий по ${data['itemsPerBatch']} шт) - ${data['totalPrice']} руб';
        }
      }
      return content;
    } catch (e) {
      return content;
    }
  }

  String _formatDate(String dateString) {
    try {
      if (dateString.isEmpty) return 'Неизвестно';
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildOrderActions(Map<String, dynamic> supply) {
    if (supply['status'] == 'оформлен') {
      return ElevatedButton(
        onPressed: () => _cancelOrder(supply['id']),
        child: const Text('Отменить'),
      );
    } else if (supply['status'] == 'отправлен') {
      return ElevatedButton(
        onPressed: () => _receiveOrder(supply),
        child: const Text('Получить'),
      );
    } else if (supply['status'] == 'получено') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            supply['status'],
            style: TextStyle(
              color: _getStatusColor(supply['status']),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.description, color: Colors.blue),
            onPressed: () => _generateInvoice(supply['id']),
            tooltip: 'Скачать накладную',
          ),
        ],
      );
    }
    return Text(
      supply['status'],
      style: TextStyle(
        color: _getStatusColor(supply['status']),
        fontWeight: FontWeight.bold,
      ),
    );
  }

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

  Future<void> _cancelOrder(int supplyId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/supplies/$supplyId'),
      );
      if (response.statusCode == 200) {
        _loadSupplies();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Заказ отменен')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка отмены: $e')));
      }
    }
  }

  Future<void> _receiveOrder(Map<String, dynamic> supply) async {
    showDialog(
      context: context,
      builder: (context) => ReceiveOrderDialog(
        supply: supply,
        onOrderReceived: () {
          _loadSupplies();
          _loadWarehouseProducts();
        },
      ),
    );
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
                  storeData['photo'] != null &&
                      storeData['photo'].isNotEmpty &&
                      storeData['photo'].startsWith('data:image/')
                  ? MemoryImage(
                      base64Decode(storeData['photo'].split(',').last),
                    )
                  : null,
              child: storeData['photo'] == null || storeData['photo'].isEmpty
                  ? const Icon(Icons.store, size: 50, color: Colors.white)
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
                    'Название',
                    'name',
                    storeData['name'] ?? '',
                  ),
                  _buildEditableField(
                    'Адрес',
                    'address',
                    storeData['address'] ?? '',
                  ),
                  _buildEditableField(
                    'Описание',
                    'description',
                    storeData['description'] ?? '',
                  ),
                  _buildPasswordField(),
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
                await _updateStoreField(field, controller.text.trim());
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
        return 'Название';
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
                await _updateStoreField('password', controller.text.trim());
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

  Future<void> _updateStoreField(String field, String value) async {
    try {
      final data = {field: value};
      final response = await http.put(
        Uri.parse('$baseUrl/stores/${widget.store['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        _loadStoreData();
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

        await _updateStoreField('photo', photoData);
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
        Uri.parse('$baseUrl/support-messages/store'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fromStoreId': widget.store['id'], 'text': text}),
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

  Future<void> _deleteAccount() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Все ваши данные будут безвозвратно удалены. Это действие нельзя отменить.',
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
                  Uri.parse('$baseUrl/stores/${widget.store['id']}'),
                );
                if (response.statusCode == 200) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Магазин: ${storeData['name'] ?? widget.store['name']}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildWarehouseTab(),
          _buildBatchesTab(),
          _buildOrdersTab(),
          _buildAccountTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.warehouse), label: 'Склад'),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Поставки',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Заказы',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Аккаунт'),
        ],
      ),
    );
  }
}

class BatchOrderDialog extends StatefulWidget {
  final Map<String, dynamic> batch;
  final int storeId;
  final VoidCallback onOrderCreated;

  const BatchOrderDialog({
    super.key,
    required this.batch,
    required this.storeId,
    required this.onOrderCreated,
  });

  @override
  State<BatchOrderDialog> createState() => _BatchOrderDialogState();
}

class _BatchOrderDialogState extends State<BatchOrderDialog> {
  int _quantity = 1;
  final TextEditingController _reviewController = TextEditingController();
  final String baseUrl = GlobalConfig.baseUrl;
  List<dynamic> supplierReviews = [];

  @override
  void initState() {
    super.initState();
    _loadSupplierReviews();
  }

  Future<void> _loadSupplierReviews() async {
    try {
      final supplierId = widget.batch['supplierId'];
      final response = await http.get(
        Uri.parse('$baseUrl/reviews/supplier/$supplierId'),
      );
      if (response.statusCode == 200) {
        setState(() {
          supplierReviews = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error loading supplier reviews: $e');
    }
  }

  Future<void> _createOrder() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/supplies'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromSupplierId': widget.batch['supplierId'],
          'toStoreId': widget.storeId,
          'content': jsonEncode({
            'batchId': widget.batch['id'],
            'batchName': widget.batch['name'],
            'description': widget.batch['description'],
            'expiration': widget.batch['expiration'],
            'quantity': _quantity,
            'itemsPerBatch': widget.batch['productCount'],
            'totalItems': _quantity * widget.batch['productCount'],
            'totalPrice': widget.batch['price'] * _quantity,
            'supplierPhoto': widget.batch['photo'],
          }),
          'status': 'оформлен',
        }),
      );

      if (response.statusCode == 200) {
        widget.onOrderCreated();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Заказ создан')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка создания заказа: $e')));
    }
  }

  Future<void> _createReview() async {
    if (_reviewController.text.trim().isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reviews'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromStoreId': widget.storeId,
          'toSupplierId': widget.batch['supplierId'],
          'text': _reviewController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        _loadSupplierReviews(); // Перезагружаем отзывы
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Отзыв добавлен')));
        _reviewController.clear();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка добавления отзыва: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = widget.batch['price'] * _quantity;
    final supplier = widget.batch['supplier'] ?? {};

    return Dialog(
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Фото товара
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                    image:
                        widget.batch['photo'] != null &&
                            widget.batch['photo'].isNotEmpty &&
                            widget.batch['photo'].startsWith('data:image/')
                        ? DecorationImage(
                            image: MemoryImage(
                              base64Decode(
                                widget.batch['photo'].split(',').last,
                              ),
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child:
                      widget.batch['photo'] == null ||
                          widget.batch['photo'].isEmpty
                      ? const Icon(
                          Icons.inventory,
                          size: 50,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 16),

              // Информация о товаре
              Text(
                widget.batch['name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.batch['description'] ?? 'Описание отсутствует',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text('Количество в партии: ${widget.batch['productCount']} шт'),
              const SizedBox(height: 4),
              Text('Цена партии: ${widget.batch['price']} руб'),

              const SizedBox(height: 16),

              // Информация о поставщике
              Text(
                'Поставщик:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                supplier['name'] ?? 'Неизвестно',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                supplier['description'] ?? 'Описание отсутствует',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 16),

              // Сумма и управление количеством
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'К оплате: $totalPrice руб',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => setState(() => _quantity++),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _createOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Заказать'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Отзывы на поставщика
              Text(
                'Отзывы на поставщика:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),

              if (supplierReviews.isEmpty)
                const Text(
                  'Пока нет отзывов',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Column(
                  children: supplierReviews.map<Widget>((review) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review['fromStore']?['name'] ??
                                'Неизвестный магазин',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            review['text'] ?? '',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatReviewDate(review['createdAt'] ?? ''),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // Поле для нового отзыва
              const Text(
                'Оставить отзыв:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reviewController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ваш отзыв...',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createReview,
                  child: const Text('Добавить отзыв'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatReviewDate(String dateString) {
    try {
      if (dateString.isEmpty) return 'Неизвестно';
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

// Диалог получения заказа (исправленная версия)
class ReceiveOrderDialog extends StatefulWidget {
  final Map<String, dynamic> supply;
  final VoidCallback onOrderReceived;

  const ReceiveOrderDialog({
    super.key,
    required this.supply,
    required this.onOrderReceived,
  });

  @override
  State<ReceiveOrderDialog> createState() => _ReceiveOrderDialogState();
}

class _ReceiveOrderDialogState extends State<ReceiveOrderDialog> {
  final TextEditingController _priceController = TextEditingController();
  File? _selectedImage;
  final String baseUrl = GlobalConfig.baseUrl;

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
      });
    }
  }

  Future<void> _receiveOrder() async {
    try {
      final price = double.tryParse(_priceController.text) ?? 0.0;
      if (price <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите корректную цену')),
        );
        return;
      }

      // Конвертируем фото в base64 если есть новое фото
      String? photoData;
      if (_selectedImage != null) {
        try {
          final bytes = await _selectedImage!.readAsBytes();
          final base64Image = base64Encode(bytes);
          final imageType = _selectedImage!.path.split('.').last.toLowerCase();
          final mimeType = _getMimeType(imageType);
          photoData = 'data:$mimeType;base64,$base64Image';
        } catch (e) {
          debugPrint('Error converting image: $e');
        }
      }

      print('🎯 Starting to receive order...');

      // Создаем товары из данных заказа с прогресс-индикатором
      final success = await _createProductsFromOrder(
        widget.supply['content'],
        price,
        photoData,
      );

      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при создании товаров')),
        );
        return;
      }

      // Обновляем статус поставки
      final response = await http.put(
        Uri.parse('$baseUrl/supplies/${widget.supply['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromSupplierId': widget.supply['fromSupplierId'],
          'toStoreId': widget.supply['toStoreId'],
          'content': widget.supply['content'],
          'status': 'получено',
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Order marked as received');
        widget.onOrderReceived();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказ получен, товары добавлены на склад'),
          ),
        );
      } else {
        print('❌ Failed to update supply status: ${response.statusCode}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления статуса: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      print('❌ Error receiving order: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка получения заказа: $e')));
    }
  }

  Future<bool> _createProductsFromOrder(
    String content,
    double price,
    String? photo,
  ) async {
    try {
      print('🔧 Processing order content: $content');
      final orderData = jsonDecode(content);

      final productName = orderData['batchName'] ?? 'Товар из поставки';
      final productDescription =
          orderData['description'] ?? 'Товар получен из заказа';
      final expiration = orderData['expiration'] ?? 30;

      // ИЗМЕНЕНИЕ: Получаем количество партий и товаров в партии
      final batchCount = orderData['quantity'] ?? 1; // Z партий
      final itemsPerBatch =
          orderData['itemsPerBatch'] ?? 1; // X товаров в партии
      final totalItems = batchCount * itemsPerBatch; // Z * X товаров

      String? finalPhoto = photo;
      if (finalPhoto == null && orderData['supplierPhoto'] != null) {
        finalPhoto = orderData['supplierPhoto'];
      }

      print(
        '📦 Creating $totalItems products from $batchCount batches: $productName',
      );

      // Создаем Z * X товаров на складе магазина
      bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ProductCreationDialog(
          totalItems: totalItems,
          createProduct: (int index) async {
            final response = await http.post(
              Uri.parse(
                '$baseUrl/warehouses/${widget.supply['toStoreId']}/products',
              ),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'name': productName,
                'description': productDescription,
                'expiration': expiration,
                'price': price,
                'photo': finalPhoto,
              }),
            );
            return response.statusCode == 200;
          },
        ),
      );

      return result ?? false;
    } catch (e) {
      print('❌ Error creating products from order: $e');
      return false;
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Получение заказа'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Установите цену для товара:'),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Цена за штуку',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Фото товара (опционально, будет использовано фото из партии если не выбрано):',
            ),
            const SizedBox(height: 8),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(onPressed: _receiveOrder, child: const Text('Получить')),
      ],
    );
  }
}

// Диалог прогресса создания товаров
class ProductCreationDialog extends StatefulWidget {
  final int totalItems;
  final Future<bool> Function(int) createProduct;

  const ProductCreationDialog({
    super.key,
    required this.totalItems,
    required this.createProduct,
  });

  @override
  State<ProductCreationDialog> createState() => _ProductCreationDialogState();
}

class _ProductCreationDialogState extends State<ProductCreationDialog> {
  int _currentItem = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _createProducts();
  }

  Future<void> _createProducts() async {
    for (int i = 0; i < widget.totalItems; i++) {
      final success = await widget.createProduct(i);
      if (!success) {
        if (!mounted) return;
        Navigator.pop(context, false);
        return;
      }

      if (mounted) {
        setState(() {
          _currentItem = i + 1;
        });
      }

      // Небольшая задержка для анимации
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (mounted) {
      setState(() {
        _isComplete = true;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавление товаров на склад'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isComplete
                ? 'Готово! Добавлено ${widget.totalItems} товаров'
                : 'Добавляем товары: $_currentItem из ${widget.totalItems}',
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: widget.totalItems > 0 ? _currentItem / widget.totalItems : 0,
          ),
        ],
      ),
    );
  }
}

// Диалог редактирования товара (без изменений)
class ProductEditDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<int> warehouseIds;
  final VoidCallback onProductUpdated;

  const ProductEditDialog({
    super.key,
    required this.product,
    required this.warehouseIds,
    required this.onProductUpdated,
  });

  @override
  State<ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<ProductEditDialog> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final String baseUrl = GlobalConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.product['price'].toString();
    _nameController.text = widget.product['name'];
    _descriptionController.text = widget.product['description'];
  }

  Future<void> _updateProduct() async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/products/${widget.product['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text,
          'description': _descriptionController.text,
          'price': double.tryParse(_priceController.text) ?? 0.0,
        }),
      );

      if (response.statusCode == 200) {
        widget.onProductUpdated();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Товар обновлен')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка обновления: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать товар'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Цена',
                border: OutlineInputBorder(),
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
        ElevatedButton(
          onPressed: _updateProduct,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
