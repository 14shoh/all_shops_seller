import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/sale_model.dart';
import '../models/product_model.dart';
import '../services/storage_service.dart';
import '../services/connectivity_service.dart';
import '../../config/app_config.dart';
import 'product_provider.dart';

class SaleProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final ProductProvider? _productProvider;

  static const String _pendingSalesKey = 'pending_sales';
  static const int _maxRetryAttempts = 15;

  final List<SaleItemModel> _currentSaleItems = [];
  bool _isLoading = false;
  String? _error;
  bool _isOffline = false;
  bool _isSyncingPendingSales = false;
  int _pendingSalesCount = 0;
  StreamSubscription<bool>? _connectivitySubscription;
  String? _lastOperationMessage;
  bool _lastSaleSavedOffline = false;
  Timer? _pendingSalesSyncTimer;
  Timer? _periodicSyncTimer;
  int _pendingSalesSyncDelaySeconds = 10;

  List<SaleItemModel> get currentSaleItems => _currentSaleItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;
  bool get isSyncingPendingSales => _isSyncingPendingSales;
  int get pendingSalesCount => _pendingSalesCount;
  String? get lastOperationMessage => _lastOperationMessage;
  bool get lastSaleSavedOffline => _lastSaleSavedOffline;

  SaleProvider({ProductProvider? productProvider}) : _productProvider = productProvider {
    _initializeConnectivityListener();
    _refreshPendingSalesCount();
    _startPeriodicSync();
  }

  Future<void> _refreshPendingSalesCount() async {
    _pendingSalesCount = await getPendingSalesCount();
    notifyListeners();
  }
  
  void _initializeConnectivityListener() {
    _connectivitySubscription = _connectivityService.onConnectionChanged.listen(
      (hasConnection) async {
        _isOffline = !hasConnection;
        notifyListeners();
        
        if (hasConnection) {
          // Даём сети 2 секунды на стабилизацию после переключения
          await Future.delayed(const Duration(seconds: 2));

          final serverReachable = await _connectivityService.hasInternetConnection();
          if (!serverReachable) {
            print('⚠️ Сеть есть, но сервер пока недоступен. Повтор через 5 сек.');
            _pendingSalesSyncDelaySeconds = 5;
            _schedulePendingSalesSync();
            return;
          }

          try {
            await _productProvider?.syncPendingProducts();
            await syncPendingSales();
          } catch (e) {
            print('⚠️ Ошибка при синхронизации после восстановления сети: $e');
            _pendingSalesSyncDelaySeconds = 5;
            _schedulePendingSalesSync();
          }
        }
      },
    );
    
    _connectivityService.hasConnection().then((hasConnection) {
      _isOffline = !hasConnection;
      notifyListeners();
    });
  }

  /// Периодическая проверка (каждые 30 сек) — страховка на случай, если
  /// connectivity-событие не сработало или было пропущено.
  void _startPeriodicSync() {
    _periodicSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        final count = await getPendingSalesCount();
        _pendingSalesCount = count;
        if (count == 0) return;

        final hasInternet = await _connectivityService.hasInternetConnection();
        if (hasInternet && !_isSyncingPendingSales) {
          print('🔄 Периодическая синхронизация: $count офлайн продаж');
          try {
            await _productProvider?.syncPendingProducts();
            await syncPendingSales();
          } catch (_) {}
        }
      },
    );
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _pendingSalesSyncTimer?.cancel();
    _periodicSyncTimer?.cancel();
    super.dispose();
  }

  void _schedulePendingSalesSync() {
    _pendingSalesSyncTimer?.cancel();
    _pendingSalesSyncTimer = Timer(
      Duration(seconds: _pendingSalesSyncDelaySeconds),
      () async {
        try {
          final hasInternet = await _connectivityService.hasInternetConnection();
          if (hasInternet) {
            await _productProvider?.syncPendingProducts();
            await syncPendingSales();
          }

          final remaining = await getPendingSalesCount();
          _pendingSalesCount = remaining;
          if (remaining > 0) {
            _pendingSalesSyncDelaySeconds =
                (_pendingSalesSyncDelaySeconds * 2).clamp(5, 60);
            _schedulePendingSalesSync();
          } else {
            _pendingSalesSyncDelaySeconds = 10;
          }
        } catch (_) {
          _pendingSalesSyncDelaySeconds =
              (_pendingSalesSyncDelaySeconds * 2).clamp(5, 60);
          _schedulePendingSalesSync();
        } finally {
          notifyListeners();
        }
      },
    );
  }
  
  double get totalAmount {
    return _currentSaleItems.fold(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
  }
  
  void addItemToSale(ProductModel product, int quantity, double salePrice) {
    final unit = product.unitType;
    final totalPrice = _calcTotalPrice(quantity, salePrice, unit);
    
    final existingIndex = _currentSaleItems.indexWhere(
      (item) => item.productId == product.id && (product.size == null || item.size == product.size),
    );
    
    if (existingIndex >= 0) {
      final existingItem = _currentSaleItems[existingIndex];
      final newQty = existingItem.quantity + quantity;
      _currentSaleItems[existingIndex] = SaleItemModel(
        id: existingItem.id,
        productId: product.id!,
        productName: product.name,
        quantity: newQty,
        salePrice: salePrice,
        totalPrice: _calcTotalPrice(newQty, salePrice, unit),
        size: product.size,
        quantityUnit: unit,
      );
    } else {
      _currentSaleItems.add(SaleItemModel(
        productId: product.id!,
        productName: product.name,
        quantity: quantity,
        salePrice: salePrice,
        totalPrice: totalPrice,
        size: product.size,
        quantityUnit: unit,
      ));
    }
    notifyListeners();
  }

  double _calcTotalPrice(int quantity, double salePrice, String unit) {
    if (unit == 'кг' || unit == 'л') {
      return quantity * salePrice; // quantity в кг/л, salePrice за кг/л
    }
    return salePrice * quantity;
  }
  
  void removeItemFromSale(int index) {
    if (index >= 0 && index < _currentSaleItems.length) {
      _currentSaleItems.removeAt(index);
      notifyListeners();
    }
  }
  
  void updateItemQuantity(int index, int quantity) {
    if (index >= 0 && index < _currentSaleItems.length) {
      final item = _currentSaleItems[index];
      _currentSaleItems[index] = SaleItemModel(
        id: item.id,
        productId: item.productId,
        productName: item.productName,
        quantity: quantity,
        salePrice: item.salePrice,
        totalPrice: _calcTotalPrice(quantity, item.salePrice, item.quantityUnit),
        size: item.size,
        quantityUnit: item.quantityUnit,
      );
      notifyListeners();
    }
  }
  
  void clearSale() {
    _currentSaleItems.clear();
    notifyListeners();
  }
  
  Future<bool> createSale() async {
    if (_currentSaleItems.isEmpty) {
      _error = 'Добавьте хотя бы один товар';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    _lastOperationMessage = null;
    _lastSaleSavedOffline = false;
    notifyListeners();
    
    try {
      final shopId = await _storageService.getShopId();
      if (shopId == null) {
        _error = 'Магазин не назначен';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final hasInternet = await _connectivityService.hasInternetConnection();
      _isOffline = !hasInternet;
      
      if (hasInternet) {
        try {
          final response = await _apiService.post(
            AppConfig.salesEndpoint,
            data: {
              'shopId': shopId,
              'items': _currentSaleItems.map((item) => item.toJson()).toList(),
            },
          );
          
          if (response.statusCode == 201 || response.statusCode == 200) {
            clearSale();
            _lastOperationMessage = 'Продажа сохранена';
            _lastSaleSavedOffline = false;
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            _error = response.data['message'] ?? 'Ошибка создания продажи';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } on DioException catch (e) {
          // Если сервер вернул ошибку (4xx/5xx) — это НЕ офлайн случай.
          if (e.response != null) {
            final data = e.response?.data;
            final message = (data is Map && data['message'] != null)
                ? data['message'].toString()
                : 'Ошибка создания продажи (HTTP ${e.response?.statusCode})';
            _error = message;
            _isLoading = false;
            notifyListeners();
            return false;
          }

          // Только сетевые проблемы — сохраняем офлайн
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout) {
            return await _saveSaleOffline(shopId);
          }

          _error = 'Ошибка создания продажи: ${e.message}';
          _isLoading = false;
          notifyListeners();
          return false;
        } catch (e) {
          // Неизвестная ошибка — НЕ сохраняем офлайн, чтобы не копить "битые" продажи
          _error = 'Ошибка создания продажи: $e';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        // Нет интернета - сохраняем локально
        return await _saveSaleOffline(shopId);
      }
    } catch (e) {
      _error = 'Ошибка создания продажи: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> _saveSaleOffline(int shopId) async {
    try {
      final saleData = {
        'shopId': shopId,
        'items': _currentSaleItems.map((item) {
          final json = item.toJson();
          json['totalPrice'] = item.totalPrice; // для отображения суммы в истории
          return json;
        }).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Загружаем существующие продажи
      final prefs = await SharedPreferences.getInstance();
      final pendingSalesJson = prefs.getString(_pendingSalesKey);
      List<dynamic> pendingSales = [];
      
      if (pendingSalesJson != null) {
        pendingSales = jsonDecode(pendingSalesJson) as List;
      }
      
      // Добавляем новую продажу
      pendingSales.add(saleData);
      
      // Сохраняем
      await prefs.setString(_pendingSalesKey, jsonEncode(pendingSales));
      _pendingSalesCount = pendingSales.length;
      
      clearSale();
      _error = null;
      _lastOperationMessage = 'Продажа сохранена офлайн (будет синхронизирована при появлении интернета)';
      _lastSaleSavedOffline = true;
      _isLoading = false;
      notifyListeners();
      _schedulePendingSalesSync();
      return true;
    } catch (e) {
      _error = 'Ошибка сохранения продажи локально: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Синхронизировать офлайн продажи
  Future<void> syncPendingSales() async {
    if (_isSyncingPendingSales) return;

    try {
      _isSyncingPendingSales = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final pendingSalesJson = prefs.getString(_pendingSalesKey);
      
      if (pendingSalesJson == null || pendingSalesJson.isEmpty) {
        _pendingSalesCount = 0;
        _pendingSalesSyncDelaySeconds = 10;
        _pendingSalesSyncTimer?.cancel();
        return;
      }
      
      List<dynamic> pendingSales;
      try {
        pendingSales = jsonDecode(pendingSalesJson) as List;
      } catch (e) {
        print('❌ Повреждённый JSON в pending_sales, сбрасываем: $e');
        await prefs.remove(_pendingSalesKey);
        _pendingSalesCount = 0;
        return;
      }

      if (pendingSales.isEmpty) {
        await prefs.remove(_pendingSalesKey);
        _pendingSalesCount = 0;
        return;
      }

      print('🔄 Начало синхронизации: ${pendingSales.length} офлайн продаж');

      final List<dynamic> failedSales = [];
      bool networkDown = false;
      
      for (int idx = 0; idx < pendingSales.length; idx++) {
        // Если сеть упала на предыдущей попытке — не пытаемся дальше
        if (networkDown) {
          failedSales.add(pendingSales[idx]);
          continue;
        }

        final saleData = pendingSales[idx];
        if (saleData is! Map) {
          print('⚠️ Продажа [$idx] не является Map, пропускаем');
          continue;
        }

        try {
          final rawItems = saleData['items'];
          if (rawItems is! List || rawItems.isEmpty) {
            print('⚠️ Продажа [$idx] без товаров, пропускаем');
            continue;
          }

          final items = List<Map<String, dynamic>>.from(
            rawItems.map((e) => Map<String, dynamic>.from(e as Map)),
          );

          bool hasUnresolvedTempIds = false;

          for (int i = 0; i < items.length; i++) {
            final rawId = items[i]['productId'];
            final productId = rawId is int ? rawId : (rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? ''));
            if (productId == null) continue;
            items[i]['productId'] = productId;

            if (ProductProvider.isTemporaryId(productId)) {
              final realId = await ProductProvider.getRealProductId(productId);
              if (realId != null) {
                items[i]['productId'] = realId;
                print('🔄 [$idx] productId: $productId -> $realId');
              } else {
                hasUnresolvedTempIds = true;
                print('⏳ [$idx] Ждёт синхронизацию товара. temp productId: $productId');
              }
            }
          }

          // Обновляем items в saleData для сохранения resolved ID
          final updatedSaleData = Map<String, dynamic>.from(saleData);
          updatedSaleData['items'] = items;

          if (hasUnresolvedTempIds) {
            failedSales.add(updatedSaleData);
            continue;
          }

          // Подготовка данных для API: убираем size, но ОСТАВЛЯЕМ totalPrice
          final itemsForApi = items.map((e) {
            final m = Map<String, dynamic>.from(e);
            m.remove('size');
            // Приводим типы к нужным (после JSON десериализации могут быть int вместо double)
            if (m['salePrice'] is int) m['salePrice'] = (m['salePrice'] as int).toDouble();
            if (m['totalPrice'] is int) m['totalPrice'] = (m['totalPrice'] as int).toDouble();
            if (m['quantity'] is double) m['quantity'] = (m['quantity'] as double).toInt();
            return m;
          }).toList();

          final shopId = saleData['shopId'] is int
              ? saleData['shopId']
              : int.tryParse(saleData['shopId']?.toString() ?? '');

          if (shopId == null) {
            print('❌ [$idx] shopId отсутствует, отбрасываем продажу');
            continue;
          }

          print('📤 [$idx] Отправка: shopId=$shopId, items=${itemsForApi.length}');

          final response = await _apiService.post(
            AppConfig.salesEndpoint,
            data: {
              'shopId': shopId,
              'items': itemsForApi,
            },
          );
          
          if (response.statusCode == 201 || response.statusCode == 200) {
            print('✅ [$idx] Продажа синхронизирована');
          } else {
            print('⚠️ [$idx] Ответ сервера: ${response.statusCode}');
            _incrementAttempts(updatedSaleData);
            if (_getAttempts(updatedSaleData) < _maxRetryAttempts) {
              failedSales.add(updatedSaleData);
            } else {
              print('🗑️ [$idx] Отброшена после $_maxRetryAttempts попыток');
            }
          }
        } on DioException catch (e) {
          final isNetworkError = e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout;
          
          if (isNetworkError) {
            print('⚠️ [$idx] Нет связи с сервером. Прекращаем попытки до следующего цикла.');
            networkDown = true;
            failedSales.add(saleData);
          } else {
            // Серверная ошибка (400, 500 и т.д.) — логируем и считаем попытку
            final statusCode = e.response?.statusCode;
            final responseData = e.response?.data;
            print('❌ [$idx] HTTP $statusCode: $responseData');

            final updatedSaleData = Map<String, dynamic>.from(saleData);
            _incrementAttempts(updatedSaleData);
            if (_getAttempts(updatedSaleData) < _maxRetryAttempts) {
              failedSales.add(updatedSaleData);
            } else {
              print('🗑️ [$idx] Отброшена после $_maxRetryAttempts попыток (ошибка $statusCode)');
            }
          }
        } catch (e) {
          print('❌ [$idx] Неожиданная ошибка: $e');
          final updatedSaleData = Map<String, dynamic>.from(saleData);
          _incrementAttempts(updatedSaleData);
          failedSales.add(updatedSaleData);
        }
      }
      
      if (failedSales.isEmpty) {
        await prefs.remove(_pendingSalesKey);
        _pendingSalesCount = 0;
        _pendingSalesSyncDelaySeconds = 10;
        _pendingSalesSyncTimer?.cancel();
        print('✅ Все офлайн продажи синхронизированы');
      } else {
        await prefs.setString(_pendingSalesKey, jsonEncode(failedSales));
        _pendingSalesCount = failedSales.length;
        _pendingSalesSyncDelaySeconds =
            (_pendingSalesSyncDelaySeconds * 2).clamp(5, 60);
        _schedulePendingSalesSync();
        print('⚠️ Осталось ${failedSales.length} несинхронизированных продаж. Повтор через $_pendingSalesSyncDelaySeconds сек.');
      }
    } catch (e) {
      print('❌ Критическая ошибка синхронизации продаж: $e');
      _pendingSalesSyncDelaySeconds =
          (_pendingSalesSyncDelaySeconds * 2).clamp(5, 60);
      _schedulePendingSalesSync();
    } finally {
      _isSyncingPendingSales = false;
      notifyListeners();
    }
  }

  int _getAttempts(Map<String, dynamic> saleData) {
    return (saleData['_syncAttempts'] is num)
        ? (saleData['_syncAttempts'] as num).toInt()
        : 0;
  }

  void _incrementAttempts(Map<String, dynamic> saleData) {
    saleData['_syncAttempts'] = _getAttempts(saleData) + 1;
  }
  
  /// Получить количество офлайн продаж
  Future<int> getPendingSalesCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingSalesJson = prefs.getString(_pendingSalesKey);
      
      if (pendingSalesJson == null) return 0;
      
      final pendingSales = jsonDecode(pendingSalesJson) as List;
      return pendingSales.length;
    } catch (e) {
      return 0;
    }
  }

  /// Офлайн-продажи в формате для отображения в истории (id: null, createdAt, totalAmount, isOffline: true).
  Future<List<Map<String, dynamic>>> getPendingSalesForDisplay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingSalesJson = prefs.getString(_pendingSalesKey);
      if (pendingSalesJson == null) return [];

      final pendingSales = jsonDecode(pendingSalesJson) as List;
      final result = <Map<String, dynamic>>[];

      for (final saleData in pendingSales) {
        if (saleData is! Map) continue;
        final items = saleData['items'] as List? ?? [];
        double totalAmount = 0.0;
        for (final item in items) {
          if (item is Map) {
            final total = item['totalPrice'];
            if (total != null) {
              if (total is num) {
                totalAmount += total.toDouble();
              } else if (total is String) totalAmount += double.tryParse(total) ?? 0.0;
            } else {
              // старые офлайн-продажи без totalPrice: считаем quantity × salePrice
              final q = item['quantity'];
              final p = item['salePrice'];
              final qty = q is num ? q.toInt() : (q is String ? int.tryParse(q) : null) ?? 0;
              final price = p is num ? p.toDouble() : (p is String ? double.tryParse(p) : null) ?? 0.0;
              totalAmount += qty * price;
            }
          }
        }
        final timestamp = saleData['timestamp'] as String? ?? DateTime.now().toIso8601String();
        result.add({
          'id': null,
          'createdAt': timestamp,
          'totalAmount': totalAmount,
          'isOffline': true,
        });
      }
      // Новые офлайн-продажи сверху
      result.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(0);
        final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
      return result;
    } catch (e) {
      return [];
    }
  }
}
