import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  static const String _pendingSalesKey = 'pending_sales';
  
  final List<SaleItemModel> _currentSaleItems = [];
  bool _isLoading = false;
  String? _error;
  bool _isOffline = false;
  bool _isSyncingPendingSales = false;
  int _pendingSalesCount = 0;
  StreamSubscription<bool>? _connectivitySubscription;
  
  List<SaleItemModel> get currentSaleItems => _currentSaleItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;
  bool get isSyncingPendingSales => _isSyncingPendingSales;
  int get pendingSalesCount => _pendingSalesCount;
  
  SaleProvider() {
    _initializeConnectivityListener();
    _refreshPendingSalesCount();
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
          // Интернет восстановлен - синхронизируем офлайн продажи
          await syncPendingSales();
        }
      },
    );
    
    // Проверяем текущий статус
    _connectivityService.hasConnection().then((hasConnection) {
      _isOffline = !hasConnection;
      notifyListeners();
    });
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
  
  double get totalAmount {
    return _currentSaleItems.fold(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
  }
  
  void addItemToSale(ProductModel product, int quantity, double salePrice) {
    final existingIndex = _currentSaleItems.indexWhere(
      (item) => item.productId == product.id,
    );
    
    if (existingIndex >= 0) {
      // Обновляем существующий товар
      final existingItem = _currentSaleItems[existingIndex];
      _currentSaleItems[existingIndex] = SaleItemModel(
        id: existingItem.id,
        productId: product.id!,
        productName: product.name,
        quantity: existingItem.quantity + quantity,
        salePrice: salePrice,
        totalPrice: salePrice * (existingItem.quantity + quantity),
        size: product.size,
      );
    } else {
      // Добавляем новый товар
      _currentSaleItems.add(SaleItemModel(
        productId: product.id!,
        productName: product.name,
        quantity: quantity,
        salePrice: salePrice,
        totalPrice: salePrice * quantity,
        size: product.size,
      ));
    }
    
    notifyListeners();
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
        totalPrice: item.salePrice * quantity,
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
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            _error = response.data['message'] ?? 'Ошибка создания продажи';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } catch (e) {
          // Ошибка сети - сохраняем локально
          return await _saveSaleOffline(shopId);
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
        'items': _currentSaleItems.map((item) => item.toJson()).toList(),
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
      _error = 'Продажа сохранена локально (нет интернета)';
      _isLoading = false;
      notifyListeners();
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
    // Если уже синхронизируем — не запускаем параллельно
    if (_isSyncingPendingSales) return;

    try {
      _isSyncingPendingSales = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final pendingSalesJson = prefs.getString(_pendingSalesKey);
      
      if (pendingSalesJson == null) {
        _pendingSalesCount = 0;
        return;
      }
      
      final pendingSales = jsonDecode(pendingSalesJson) as List;
      final List<dynamic> failedSales = [];
      
      for (final saleData in pendingSales) {
        try {
          // Обновляем временные ID товаров на реальные
          final items = List<Map<String, dynamic>>.from(saleData['items'] as List);
          bool hasUpdatedItems = false;
          bool hasUnresolvedTempIds = false;
          
          for (int i = 0; i < items.length; i++) {
            final productId = items[i]['productId'] as int?;
            if (productId != null && ProductProvider.isTemporaryId(productId)) {
              // Это временный ID - пытаемся найти реальный
              final realId = await ProductProvider.getRealProductId(productId);
              if (realId != null) {
                items[i]['productId'] = realId;
                hasUpdatedItems = true;
                print('🔄 Обновлен productId: $productId -> $realId');
              } else {
                // Не отправляем такую продажу на сервер (иначе будет 404 "товар не найден").
                hasUnresolvedTempIds = true;
                print('⏳ Продажа ждёт синхронизацию товара. temp productId: $productId');
              }
            }
          }
          
          // Если были обновления, сохраняем обратно в saleData
          if (hasUpdatedItems) {
            saleData['items'] = items;
          }

          // Если есть неразрешённые временные ID — оставляем продажу в очереди, без запроса к серверу.
          if (hasUnresolvedTempIds) {
            failedSales.add(saleData);
            continue;
          }
          
          final response = await _apiService.post(
            AppConfig.salesEndpoint,
            data: {
              'shopId': saleData['shopId'],
              'items': items,
            },
          );
          
          if (response.statusCode != 201 && response.statusCode != 200) {
            failedSales.add(saleData);
          }
        } catch (e) {
          print('❌ Ошибка синхронизации продажи: $e');
          failedSales.add(saleData);
        }
      }
      
      // Сохраняем только неудавшиеся продажи
      if (failedSales.isEmpty) {
        await prefs.remove(_pendingSalesKey);
        _pendingSalesCount = 0;
      } else {
        await prefs.setString(_pendingSalesKey, jsonEncode(failedSales));
        _pendingSalesCount = failedSales.length;
      }
    } catch (e) {
      print('❌ Ошибка синхронизации продаж: $e');
    } finally {
      _isSyncingPendingSales = false;
      notifyListeners();
    }
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
}
