import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../main.dart';

class AdminSupportMessagesList extends StatefulWidget {
  const AdminSupportMessagesList({super.key});

  @override
  State<AdminSupportMessagesList> createState() =>
      _AdminSupportMessagesListState();
}

class _AdminSupportMessagesListState extends State<AdminSupportMessagesList> {
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${GlobalConfig.baseUrl}/support-messages'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages = data;
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

  Future<void> _deleteMessage(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление сообщения'),
        content: const Text('Вы уверены, что хотите удалить это сообщение?'),
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
          Uri.parse('${GlobalConfig.baseUrl}/support-messages/$id'),
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Сообщение удалено')));
          }
          _loadMessages();
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

  void _viewMessageDetails(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => SupportMessageDetailsDialog(message: message),
    );
  }

  void _replyToMessage(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => ReplyToMessageDialog(message: message),
    );
  }

  List<dynamic> _getFilteredMessages() {
    List<dynamic> filtered = _messages;

    // Фильтрация по поиску
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((message) {
        final text = message['text']?.toString().toLowerCase() ?? '';
        final storeName =
            message['fromStore']?['name']?.toString().toLowerCase() ?? '';
        final supplierName =
            message['fromSupplier']?['name']?.toString().toLowerCase() ?? '';

        return text.contains(_searchQuery.toLowerCase()) ||
            storeName.contains(_searchQuery.toLowerCase()) ||
            supplierName.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Фильтрация по типу
    if (_filterType != 'all') {
      if (_filterType == 'store') {
        filtered = filtered
            .where((message) => message['fromStoreId'] != null)
            .toList();
      } else if (_filterType == 'supplier') {
        filtered = filtered
            .where((message) => message['fromSupplierId'] != null)
            .toList();
      }
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
    final filteredMessages = _getFilteredMessages();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поддержка'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMessages),
        ],
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
                    labelText: 'Поиск сообщений',
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
                DropdownButtonFormField<String>(
                  value: _filterType,
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Все сообщения'),
                    ),
                    DropdownMenuItem(
                      value: 'store',
                      child: Text('От магазинов'),
                    ),
                    DropdownMenuItem(
                      value: 'supplier',
                      child: Text('От поставщиков'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _filterType = value!),
                  decoration: const InputDecoration(
                    labelText: 'Тип отправителя',
                    border: OutlineInputBorder(),
                  ),
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
                  'Всего: ${_messages.length}',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (_searchQuery.isNotEmpty || _filterType != 'all')
                  Text(
                    'Найдено: ${filteredMessages.length}',
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
                          onPressed: _loadMessages,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : filteredMessages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.support_agent, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет сообщений поддержки'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredMessages.length,
                    itemBuilder: (context, index) {
                      final message = filteredMessages[index];
                      return SupportMessageCard(
                        message: message,
                        onDelete: () => _deleteMessage(message['id']),
                        onViewDetails: () => _viewMessageDetails(message),
                        onReply: () => _replyToMessage(message),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Карточка сообщения поддержки
class SupportMessageCard extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;
  final VoidCallback onReply;

  const SupportMessageCard({
    super.key,
    required this.message,
    required this.onDelete,
    required this.onViewDetails,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final isFromStore = message['fromStoreId'] != null;
    final senderName = isFromStore
        ? (message['fromStore']?['name'] ?? 'Неизвестный магазин')
        : (message['fromSupplier']?['name'] ?? 'Неизвестный поставщик');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isFromStore ? Colors.green.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isFromStore ? Icons.store : Icons.local_shipping,
            color: isFromStore ? Colors.green : Colors.blue,
          ),
        ),
        title: Text(
          _getTruncatedText(message['text'] ?? ''),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'От: $senderName',
              style: TextStyle(
                color: isFromStore ? Colors.green : Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (message['createdAt'] != null)
              Text(
                _formatDate(message['createdAt']),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.reply, color: Colors.green),
              onPressed: onReply,
              tooltip: 'Ответить',
            ),
            IconButton(
              icon: const Icon(Icons.info, color: Colors.blue),
              onPressed: onViewDetails,
              tooltip: 'Подробности',
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
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}

// Диалог подробной информации о сообщении
class SupportMessageDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> message;

  const SupportMessageDetailsDialog({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isFromStore = message['fromStoreId'] != null;
    final senderName = isFromStore
        ? (message['fromStore']?['name'] ?? 'Неизвестный магазин')
        : (message['fromSupplier']?['name'] ?? 'Неизвестный поставщик');

    final senderData = isFromStore
        ? message['fromStore']
        : message['fromSupplier'];

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
              Row(
                children: [
                  Icon(
                    isFromStore ? Icons.store : Icons.local_shipping,
                    color: isFromStore ? Colors.green : Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Сообщение поддержки',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Текст сообщения
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  message['text'],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Информация об отправителе
              const Text(
                'Отправитель:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  isFromStore ? 'Магазин' : 'Поставщик',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: isFromStore ? Colors.green : Colors.blue,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                'ID:',
                isFromStore
                    ? message['fromStoreId'].toString()
                    : message['fromSupplierId'].toString(),
              ),
              _buildInfoRow('Название:', senderName),

              if (senderData != null) ...[
                if (senderData['address'] != null)
                  _buildInfoRow('Адрес:', senderData['address']),
                if (senderData['description'] != null &&
                    senderData['description'].isNotEmpty)
                  _buildInfoRow('Описание:', senderData['description']),
              ],
              const SizedBox(height: 16),

              // Дополнительная информация
              const Text(
                'Дополнительно:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (message['createdAt'] != null)
                _buildInfoRow(
                  'Дата отправки:',
                  _formatDate(message['createdAt']),
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

// Диалог ответа на сообщение
class ReplyToMessageDialog extends StatefulWidget {
  final Map<String, dynamic> message;

  const ReplyToMessageDialog({super.key, required this.message});

  @override
  State<ReplyToMessageDialog> createState() => _ReplyToMessageDialogState();
}

class _ReplyToMessageDialogState extends State<ReplyToMessageDialog> {
  final TextEditingController _replyController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendReply() async {
    if (_replyController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Введите текст ответа'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    // В реальном приложении здесь был бы вызов API для отправки ответа
    // Поскольку такого API нет, покажем имитацию

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ответ отправлен (в демо-режиме)'),
          backgroundColor: Colors.green,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isFromStore = widget.message['fromStoreId'] != null;
    final senderName = isFromStore
        ? (widget.message['fromStore']?['name'] ?? 'Неизвестный магазин')
        : (widget.message['fromSupplier']?['name'] ?? 'Неизвестный поставщик');

    return AlertDialog(
      title: const Text('Ответить на сообщение'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'От: $senderName',
              style: TextStyle(
                color: isFromStore ? Colors.green : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Сообщение: ${widget.message['text']}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Ваш ответ:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _replyController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Текст ответа',
                border: OutlineInputBorder(),
                hintText: 'Введите ваш ответ...',
              ),
            ),
          ],
        ),
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
          onPressed: _isLoading ? null : _sendReply,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Отправить ответ'),
        ),
      ],
    );
  }
}
