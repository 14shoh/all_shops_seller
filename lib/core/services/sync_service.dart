import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../models/product_model.dart';
import '../../config/app_config.dart';

/// Тип операции синхронизации
enum SyncOperationType {
  updateProduct, // Обновление товара
  createProduct, // Создание товара
}

/// Запись в очереди синхронизации
class SyncQueueItem {
  final SyncOperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  SyncQueueItem({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
        type: SyncOperationType.values.firstWhere(
          (e) => e.name == json['type'],
        ),
        data: json['data'] as Map<String, dynamic>,
        timestamp: DateTime.parse(json['timestamp']),
      );
}

/// Сервис для синхронизации изменений с сервером
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ApiService _apiService = ApiService();
  final CacheService _cacheService = CacheService();

  static const String _syncQueueKey = 'sync_queue';
  bool _isSyncing = false;

  /// Добавить операцию обновления товара в очередь
  Future<void> queueProductUpdate(int productId, {
    double? purchasePrice,
    int? quantity,
  }) async {
    try {
      final queue = await getSyncQueue();
      final updateData = <String, dynamic>{'productId': productId};
      if (purchasePrice != null) updateData['purchasePrice'] = purchasePrice;
      if (quantity != null) updateData['quantity'] = quantity;

      queue.add(SyncQueueItem(
        type: SyncOperationType.updateProduct,
        data: updateData,
        timestamp: DateTime.now(),
      ));

      await _saveSyncQueue(queue);
      print('📝 Операция обновления товара добавлена в очередь синхронизации');
    } catch (e) {
      print('❌ Ошибка добавления операции в очередь: $e');
    }
  }

  /// Добавить операцию создания товара в очередь
  Future<void> queueProductCreate(Map<String, dynamic> productData) async {
    try {
      final queue = await getSyncQueue();
      queue.add(SyncQueueItem(
        type: SyncOperationType.createProduct,
        data: productData,
        timestamp: DateTime.now(),
      ));

      await _saveSyncQueue(queue);
      print('📝 Операция создания товара добавлена в очередь синхронизации');
    } catch (e) {
      print('❌ Ошибка добавления операции создания товара в очередь: $e');
    }
  }

  /// Получить очередь синхронизации
  Future<List<SyncQueueItem>> getSyncQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJsonString = prefs.getString(_syncQueueKey);
      
      if (queueJsonString == null) {
        return [];
      }

      final queueJson = jsonDecode(queueJsonString) as List;
      return queueJson
          .map((json) => SyncQueueItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Ошибка загрузки очереди синхронизации: $e');
      return [];
    }
  }

  /// Сохранить очередь синхронизации
  Future<void> _saveSyncQueue(List<SyncQueueItem> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = queue.map((item) => item.toJson()).toList();
      await prefs.setString(_syncQueueKey, jsonEncode(queueJson));
    } catch (e) {
      print('❌ Ошибка сохранения очереди синхронизации: $e');
    }
  }

  /// Синхронизировать очередь с сервером
  Future<bool> syncQueue() async {
    if (_isSyncing) {
      print('⏳ Синхронизация уже выполняется...');
      return false;
    }

    _isSyncing = true;
    print('🔄 Начало синхронизации очереди...');

    try {
      final queue = await getSyncQueue();
      if (queue.isEmpty) {
        _isSyncing = false;
        return true;
      }

      final List<SyncQueueItem> failedItems = [];
      int successCount = 0;

      for (final item in queue) {
        try {
          bool success = false;

          switch (item.type) {
            case SyncOperationType.updateProduct:
              success = await _syncProductUpdate(item.data);
              break;
            case SyncOperationType.createProduct:
              success = await _syncProductCreate(item.data);
              break;
          }

          if (success) {
            successCount++;
            print('✅ Синхронизировано: ${item.type.name}');
          } else {
            failedItems.add(item);
            print('❌ Ошибка синхронизации: ${item.type.name}');
          }
        } catch (e) {
          print('❌ Ошибка при синхронизации операции: $e');
          failedItems.add(item);
        }
      }

      // Сохраняем только неудавшиеся операции
      await _saveSyncQueue(failedItems);

      if (successCount > 0) {
        await _cacheService.setLastSyncTime(DateTime.now());
        print('✅ Синхронизация завершена: $successCount из ${queue.length} операций');
      }

      _isSyncing = false;
      return failedItems.isEmpty;
    } catch (e) {
      print('❌ Критическая ошибка синхронизации: $e');
      _isSyncing = false;
      return false;
    }
  }

  /// Синхронизировать обновление товара
  Future<bool> _syncProductUpdate(Map<String, dynamic> data) async {
    try {
      final productId = data['productId'] as int;
      final updateData = <String, dynamic>{};
      
      if (data.containsKey('purchasePrice')) {
        updateData['purchasePrice'] = data['purchasePrice'];
      }
      if (data.containsKey('quantity')) {
        updateData['quantity'] = data['quantity'];
      }

      final response = await _apiService.patch(
        '${AppConfig.productsEndpoint}/$productId',
        data: updateData,
      );

      if (response.statusCode == 200) {
        // Обновляем товар в кеше
        final updatedProduct = ProductModel.fromJson(response.data);
        await _cacheService.updateCachedProduct(updatedProduct);
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Ошибка синхронизации обновления товара: $e');
      return false;
    }
  }

  /// Синхронизировать создание товара
  Future<bool> _syncProductCreate(Map<String, dynamic> productData) async {
    try {
      final response = await _apiService.post(
        AppConfig.productsEndpoint,
        data: productData,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Добавляем товар в кеш
        final createdProduct = ProductModel.fromJson(response.data);
        await _cacheService.updateCachedProduct(createdProduct);
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Ошибка синхронизации создания товара: $e');
      return false;
    }
  }

  /// Очистить очередь синхронизации
  Future<void> clearSyncQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_syncQueueKey);
      print('🗑️ Очередь синхронизации очищена');
    } catch (e) {
      print('❌ Ошибка очистки очереди: $e');
    }
  }

  /// Получить количество операций в очереди
  Future<int> getQueueLength() async {
    final queue = await getSyncQueue();
    return queue.length;
  }
}

// Экспорт для использования в других файлах
Future<List<SyncQueueItem>> getSyncQueue() => SyncService().getSyncQueue();
