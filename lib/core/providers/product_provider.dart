import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/product_model.dart';
import '../models/shop_model.dart';
import '../services/storage_service.dart';
import '../services/cache_service.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';
import '../../config/app_config.dart';

class ProductProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final CacheService _cacheService = CacheService();
  final SyncService _syncService = SyncService();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = false;
  String? _error;
  ShopModel? _shop;
  String _searchQuery = '';
  bool _isOffline = false;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;
  bool _isSyncingPendingProducts = false;
  int _pendingProductsCount = 0;
  StreamSubscription<bool>? _connectivitySubscription;
  
  static const String _pendingProductsKey = 'pending_products';
  static const String _productIdMappingKey = 'product_id_mapping'; // временный ID -> реальный ID
  
  List<ProductModel> get products => _filteredProducts.isEmpty && _searchQuery.isEmpty ? _products : _filteredProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ShopModel? get shop => _shop;
  bool get isOffline => _isOffline;
  bool get isSyncing => _isSyncing;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isSyncingPendingProducts => _isSyncingPendingProducts;
  int get pendingProductsCount => _pendingProductsCount;
  
  bool get isClothingShop => _shop?.type == 'clothing';
  bool get isGroceryShop => _shop?.type == 'grocery';
  
  ProductProvider() {
    _initializeConnectivityListener();
    _loadPendingSyncCount();
    _refreshPendingProductsCount();
  }

  Future<void> _refreshPendingProductsCount() async {
    _pendingProductsCount = await getPendingProductsCount();
    notifyListeners();
  }
  
  void _initializeConnectivityListener() {
    _connectivitySubscription = _connectivityService.onConnectionChanged.listen(
      (hasConnection) async {
        _isOffline = !hasConnection;
        notifyListeners();
        
        if (hasConnection) {
          // Интернет восстановлен - синхронизируем очередь
          await _syncPendingChanges();
          // Синхронизируем офлайн товары
          await syncPendingProducts();
        }
      },
    );
    
    // Проверяем текущий статус
    _connectivityService.hasConnection().then((hasConnection) {
      _isOffline = !hasConnection;
      notifyListeners();
    });
  }
  
  Future<void> _loadPendingSyncCount() async {
    final queue = await _syncService.getSyncQueue();
    _pendingSyncCount = queue.length;
    notifyListeners();
  }
  
  Future<void> _syncPendingChanges() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      final success = await _syncService.syncQueue();
      await _loadPendingSyncCount();
      
      if (success) {
        // После успешной синхронизации обновляем товары с сервера
        await loadProducts();
      }
    } catch (e) {
      print('❌ Ошибка синхронизации: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
  
  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final shopId = await _storageService.getShopId();
      print('🔍 Загрузка товаров для shopId: $shopId');
      
      if (shopId == null) {
        _error = 'Магазин не назначен';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // Проверяем наличие интернета
      final hasInternet = await _connectivityService.hasInternetConnection();
      _isOffline = !hasInternet;
      print('🌐 Интернет доступен: $hasInternet');
      
      if (hasInternet) {
        // Загружаем с сервера
        // Для мобильных приложений загружаем все товары сразу (они кешируются локально)
        try {
          // Загружаем все товары с максимальным лимитом (500) для офлайн работы
          // Если товаров больше, загрузим все страницы
          final response = await _apiService.get(
            AppConfig.productsEndpoint,
            queryParameters: {'limit': 500, 'page': 1},
          );
          
          if (response.statusCode == 200) {
            final data = response.data;
            print('📦 Получены данные с сервера: ${data.runtimeType}');
            
            // Поддержка нового формата с пагинацией и старого формата (список)
            if (data is Map && data.containsKey('data')) {
              // Новый формат с пагинацией
              final productsList = data['data'] as List;
              final total = data['total'] ?? productsList.length;
              final page = data['page'] ?? 1;
              final limit = data['limit'] ?? 50;
              final totalPages = data['totalPages'] ?? 1;
              
              print('📦 Формат с пагинацией: ${productsList.length} товаров из $total (страница $page из $totalPages, лимит $limit)');
              
              // Если есть еще страницы, загружаем их тоже
              if (totalPages > 1 && productsList.length < total) {
                print('⚠️ Обнаружено несколько страниц! Загружаем все товары...');
                final allProducts = <ProductModel>[];
                allProducts.addAll(productsList.map((json) => ProductModel.fromJson(json)).toList());
                
                // Загружаем остальные страницы
                for (int p = 2; p <= totalPages; p++) {
                  try {
                    final nextResponse = await _apiService.get(
                      AppConfig.productsEndpoint,
                      queryParameters: {'limit': limit, 'page': p},
                    );
                    
                    if (nextResponse.statusCode == 200) {
                      final nextData = nextResponse.data;
                      if (nextData is Map && nextData.containsKey('data')) {
                        final nextProductsList = nextData['data'] as List;
                        allProducts.addAll(nextProductsList.map((json) => ProductModel.fromJson(json)).toList());
                        print('📦 Загружена страница $p: ${nextProductsList.length} товаров');
                      }
                    }
                  } catch (e) {
                    print('⚠️ Ошибка загрузки страницы $p: $e');
                    break;
                  }
                }
                
                _products = allProducts;
                print('✅ Всего загружено товаров со всех страниц: ${_products.length}');
              } else {
                _products = productsList
                    .map((json) => ProductModel.fromJson(json))
                    .toList();
              }
            } else if (data is List) {
              // Старый формат (для обратной совместимости)
              print('📦 Старый формат (список): ${data.length} товаров');
              _products = data
                  .map((json) => ProductModel.fromJson(json))
                  .toList();
            } else {
              print('❌ Неожиданный формат данных: ${data.runtimeType}');
              print('❌ Данные: $data');
              _products = [];
              _filteredProducts = [];
            }
            
            print('✅ Загружено товаров: ${_products.length}');
            if (_products.isNotEmpty) {
              print('📦 Первый товар: id=${_products[0].id}, name=${_products[0].name}, shopId=${_products[0].shopId}');
              if (_products.length > 1) {
                print('📦 Последний товар: id=${_products[_products.length - 1].id}, name=${_products[_products.length - 1].name}, shopId=${_products[_products.length - 1].shopId}');
              }
              // Выводим все ID товаров для отладки
              final ids = _products.map((p) => p.id).toList();
              print('📦 Все ID товаров: $ids');
            } else {
              print('⚠️ Список товаров пуст!');
            }
            
            _filterProducts();
            
            // Сохраняем в кеш (перезаписываем старые данные)
            await _cacheService.cacheProducts(_products);
            await _cacheService.setLastSyncTime(DateTime.now());
            
            _error = null;
          } else {
            throw Exception('Ошибка загрузки товаров (код: ${response.statusCode})');
          }
        } catch (e) {
          // Если ошибка сети - загружаем из кеша
          print('⚠️ Ошибка загрузки с сервера, загружаем из кеша: $e');
          await _loadFromCache();
        }
      } else {
        // Нет интернета - загружаем из кеша
        await _loadFromCache();
      }
    } catch (e) {
      print('❌ Ошибка загрузки товаров: $e');
      // Пытаемся загрузить из кеша при любой ошибке
      await _loadFromCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> _loadFromCache() async {
    try {
      final cachedProducts = await _cacheService.getCachedProducts();
      if (cachedProducts.isNotEmpty) {
        _products = cachedProducts;
        _filterProducts();
        _error = null;
        print('📦 Загружено из кеша: ${_products.length} товаров');
      } else {
        _error = 'Нет подключения к интернету и нет данных в кеше';
        _products = [];
        _filteredProducts = [];
      }
    } catch (e) {
      _error = 'Ошибка загрузки из кеша: $e';
      _products = [];
      _filteredProducts = [];
    }
  }
  
  Future<bool> addProduct(ProductModel product) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final hasInternet = await _connectivityService.hasInternetConnection();
      
      if (hasInternet) {
        // Есть интернет - добавляем через API
        try {
          final response = await _apiService.post(
            AppConfig.productsEndpoint,
            data: product.toJson(),
          );
          
          if (response.statusCode == 201 || response.statusCode == 200) {
            final addedProduct = ProductModel.fromJson(response.data);
            print('✅ Товар добавлен: id=${addedProduct.id}, name=${addedProduct.name}');
            
            // Проверяем, нет ли уже такого товара в списке
            final existingIndex = _products.indexWhere((p) => p.id == addedProduct.id);
            if (existingIndex >= 0) {
              // Обновляем существующий товар
              _products[existingIndex] = addedProduct;
              print('🔄 Товар обновлен в списке (индекс $existingIndex)');
            } else {
              // Добавляем новый товар
              _products.add(addedProduct);
              print('➕ Товар добавлен в список. Всего товаров: ${_products.length}');
            }
            
            _filterProducts();
            
            // Обновляем кеш
            await _cacheService.cacheProducts(_products);
            
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            _error = response.data['message'] ?? 'Ошибка добавления товара';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } catch (e) {
          // Ошибка сети - сохраняем локально и добавляем в очередь
          return await _addProductOffline(product);
        }
      } else {
        // Нет интернета - сохраняем локально
        return await _addProductOffline(product);
      }
    } catch (e) {
      _error = 'Ошибка добавления товара: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> _addProductOffline(ProductModel product) async {
    try {
      // Генерируем временный ID для офлайн товара
      final tempId = DateTime.now().millisecondsSinceEpoch;
      final offlineProduct = ProductModel(
        id: tempId,
        name: product.name,
        barcode: product.barcode,
        category: product.category,
        purchasePrice: product.purchasePrice,
        quantity: product.quantity,
        weight: product.weight,
        size: product.size,
        shopId: product.shopId,
      );
      
      _products.add(offlineProduct);
      _filterProducts();
      
      // Сохраняем в кеш
      await _cacheService.cacheProducts(_products);
      
      // Сохраняем в очередь офлайн товаров
      // ВАЖНО: в payload на сервер НЕ добавляем id (ValidationPipe forbidNonWhitelisted),
      // но локально сохраняем tempId, чтобы потом сделать маппинг tempId -> realId.
      final productData = product.toJson(); // без id
      final prefs = await SharedPreferences.getInstance();
      final pendingProductsJson = prefs.getString(_pendingProductsKey);
      List<dynamic> pendingProducts = [];
      
      if (pendingProductsJson != null) {
        pendingProducts = jsonDecode(pendingProductsJson) as List;
      }
      
      pendingProducts.add({
        'tempId': tempId,
        'data': productData,
      });
      await prefs.setString(_pendingProductsKey, jsonEncode(pendingProducts));
      _pendingProductsCount = pendingProducts.length;
      
      _error = 'Товар добавлен локально (нет интернета)';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка сохранения товара локально: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Синхронизировать офлайн товары
  Future<void> syncPendingProducts() async {
    // Если уже синхронизируем — не запускаем параллельно
    if (_isSyncingPendingProducts) return;

    try {
      _isSyncingPendingProducts = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final pendingProductsJson = prefs.getString(_pendingProductsKey);
      
      if (pendingProductsJson == null) {
        _pendingProductsCount = 0;
        return;
      }
      
      final pendingProducts = jsonDecode(pendingProductsJson) as List;
      final List<dynamic> failedProducts = [];
      
      for (final entry in pendingProducts) {
        try {
          // Поддержка двух форматов:
          // - новый: { tempId: 123, data: {...payload...} }
          // - старый: { ...payload... } (без tempId)
          int? tempId;
          Map<String, dynamic> payload;

          if (entry is Map && entry.containsKey('data')) {
            tempId = (entry['tempId'] is num)
                ? (entry['tempId'] as num).toInt()
                : int.tryParse(entry['tempId']?.toString() ?? '');
            payload = Map<String, dynamic>.from(entry['data'] as Map);
          } else {
            payload = Map<String, dynamic>.from(entry as Map);
            tempId = (payload['id'] is num)
                ? (payload['id'] as num).toInt()
                : int.tryParse(payload['id']?.toString() ?? '');
            // На всякий случай удаляем id, чтобы не словить 400 от ValidationPipe
            payload.remove('id');
          }

          final response = await _apiService.post(
            AppConfig.productsEndpoint,
            data: payload,
          );
          
          if (response.statusCode == 201 || response.statusCode == 200) {
            final createdProduct = ProductModel.fromJson(response.data);
            // Обновляем товар в локальном списке (заменяем временный ID на реальный)
            if (tempId != null && createdProduct.id != null) {
              // Сохраняем маппинг временный ID -> реальный ID
              final mappingPrefs = await SharedPreferences.getInstance();
              final mappingJson = mappingPrefs.getString(_productIdMappingKey);
              Map<int, int> idMapping = {};
              if (mappingJson != null) {
                final mappingData = jsonDecode(mappingJson) as Map;
                idMapping = Map<int, int>.from(
                  mappingData.map((k, v) => MapEntry(int.parse(k.toString()), int.parse(v.toString())))
                );
              }
              idMapping[tempId] = createdProduct.id!;
              await mappingPrefs.setString(
                _productIdMappingKey,
                jsonEncode(idMapping.map((k, v) => MapEntry(k.toString(), v.toString())))
              );
              
              // Обновляем товар в локальном списке
              final index = _products.indexWhere((p) => p.id == tempId);
              if (index >= 0) {
                _products[index] = createdProduct;
                _filterProducts();
                await _cacheService.updateCachedProduct(createdProduct);
              }
            }
          } else {
            failedProducts.add(entry);
          }
        } catch (e) {
          failedProducts.add(entry);
        }
      }
      
      // Сохраняем только неудавшиеся товары
      if (failedProducts.isEmpty) {
        await prefs.remove(_pendingProductsKey);
        _pendingProductsCount = 0;
      } else {
        await prefs.setString(_pendingProductsKey, jsonEncode(failedProducts));
        _pendingProductsCount = failedProducts.length;
      }
    } catch (e) {
      print('❌ Ошибка синхронизации товаров: $e');
    } finally {
      _isSyncingPendingProducts = false;
      notifyListeners();
    }
  }

  /// Получить количество офлайн товаров
  Future<int> getPendingProductsCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingProductsJson = prefs.getString(_pendingProductsKey);
      
      if (pendingProductsJson == null) return 0;
      
      final pendingProducts = jsonDecode(pendingProductsJson) as List;
      return pendingProducts.length;
    } catch (e) {
      return 0;
    }
  }
  
  Future<ProductModel?> findProductByBarcode(String barcode) async {
    try {
      // Сначала ищем в кеше
      final cachedProduct = await _cacheService.getCachedProductByBarcode(barcode);
      if (cachedProduct != null) {
        print('📦 Товар найден в кеше: ${cachedProduct.name}');
      }
      
      final hasInternet = await _connectivityService.hasInternetConnection();
      
      if (hasInternet) {
        try {
          // shopId берется из токена на бэкенде
          final response = await _apiService.get(
            '${AppConfig.productsEndpoint}/barcode/$barcode',
          );
          
          if (response.statusCode == 200) {
            final product = ProductModel.fromJson(response.data);
            // Обновляем в кеше
            await _cacheService.updateCachedProduct(product);
            return product;
          }
        } catch (e) {
          print('⚠️ Ошибка поиска на сервере, используем кеш: $e');
        }
      }
      
      // Возвращаем из кеша или null
      return cachedProduct;
    } catch (e) {
      return null;
    }
  }

  Future<List<ProductModel>> findAllProductsByBarcode(String barcode) async {
    try {
      final hasInternet = await _connectivityService.hasInternetConnection();
      
      if (hasInternet) {
        try {
          // shopId берется из токена на бэкенде
          final response = await _apiService.get(
            '${AppConfig.productsEndpoint}/barcode/$barcode/all',
          );
          
          if (response.statusCode == 200) {
            final data = response.data;
            if (data is List) {
              final products = data.map((json) => ProductModel.fromJson(json)).toList();
              // Обновляем в кеше
              for (final product in products) {
                await _cacheService.updateCachedProduct(product);
              }
              return products;
            }
          }
        } catch (e) {
          print('⚠️ Ошибка поиска на сервере, используем кеш: $e');
        }
      }
      
      // Ищем в кеше
      final cachedProducts = await _cacheService.getCachedProducts();
      return cachedProducts.where((p) => p.barcode == barcode).toList();
    } catch (e) {
      return [];
    }
  }
  
  void searchProducts(String query) {
    _searchQuery = query.toLowerCase().trim();
    _filterProducts();
    notifyListeners();
  }

  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = _products;
    } else {
      _filteredProducts = _products.where((product) {
        final nameMatch = product.name.toLowerCase().contains(_searchQuery);
        final barcodeMatch = product.barcode?.toLowerCase().contains(_searchQuery) ?? false;
        return nameMatch || barcodeMatch;
      }).toList();
    }
  }

  Future<bool> updateProduct(int productId, {double? purchasePrice, int? quantity}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final updateData = <String, dynamic>{};
      if (purchasePrice != null) {
        updateData['purchasePrice'] = purchasePrice;
      }
      if (quantity != null) {
        updateData['quantity'] = quantity;
      }
      
      if (updateData.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Находим товар в списке
      final index = _products.indexWhere((p) => p.id == productId);
      if (index == -1) {
        _error = 'Товар не найден';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final originalProduct = _products[index];
      
      // Обновляем локально сразу
      _products[index] = ProductModel(
        id: originalProduct.id,
        name: originalProduct.name,
        barcode: originalProduct.barcode,
        category: originalProduct.category,
        purchasePrice: purchasePrice ?? originalProduct.purchasePrice,
        quantity: quantity ?? originalProduct.quantity,
        weight: originalProduct.weight,
        size: originalProduct.size,
        shopId: originalProduct.shopId,
      );
      _filterProducts();
      
      // Обновляем в кеше
      await _cacheService.updateCachedProduct(_products[index]);
      
      final hasInternet = await _connectivityService.hasInternetConnection();
      
      if (hasInternet) {
        // Есть интернет - отправляем на сервер
        try {
          final response = await _apiService.patch(
            '${AppConfig.productsEndpoint}/$productId',
            data: updateData,
          );
          
          if (response.statusCode == 200) {
            // Обновляем товар данными с сервера
            final updatedProduct = ProductModel.fromJson(response.data);
            _products[index] = updatedProduct;
            _filterProducts();
            await _cacheService.updateCachedProduct(updatedProduct);
            
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            _error = response.data['message'] ?? 'Ошибка обновления товара';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } catch (e) {
          // Ошибка сети - добавляем в очередь синхронизации
          await _addToSyncQueue(productId, updateData);
          _error = 'Изменения сохранены локально (нет интернета)';
          _isLoading = false;
          notifyListeners();
          return true;
        }
      } else {
        // Нет интернета - добавляем в очередь синхронизации
        await _addToSyncQueue(productId, updateData);
        _error = 'Изменения сохранены локально (нет интернета)';
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = 'Ошибка обновления товара: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> _addToSyncQueue(int productId, Map<String, dynamic> updateData) async {
    try {
      await _syncService.queueProductUpdate(
        productId,
        purchasePrice: updateData['purchasePrice'] as double?,
        quantity: updateData['quantity'] as int?,
      );
      
      await _loadPendingSyncCount();
    } catch (e) {
      print('❌ Ошибка добавления в очередь синхронизации: $e');
    }
  }
  
  /// Ручная синхронизация
  Future<void> syncNow() async {
    await _syncPendingChanges();
  }
  
  Future<void> loadShopInfo() async {
    try {
      final shopId = await _storageService.getShopId();
      if (shopId == null) return;
      
      final response = await _apiService.get('/shops/$shopId');
      if (response.statusCode == 200) {
        _shop = ShopModel.fromJson(response.data);
        notifyListeners();
      }
    } catch (e) {
      // Игнорируем ошибку
    }
  }

  /// Получить реальный ID товара по временному ID (для офлайн продаж)
  static Future<int?> getRealProductId(int tempId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mappingJson = prefs.getString(_productIdMappingKey);
      if (mappingJson == null) return null;
      
      final mappingData = jsonDecode(mappingJson) as Map;
      final realId = mappingData[tempId.toString()];
      if (realId == null) return null;
      
      return int.tryParse(realId.toString());
    } catch (e) {
      return null;
    }
  }

  /// Проверить, является ли ID временным (большое число, похожее на timestamp)
  static bool isTemporaryId(int? id) {
    if (id == null) return false;
    // Временные ID генерируются как timestamp в миллисекундах (обычно > 1000000000000)
    return id > 1000000000;
  }
}
