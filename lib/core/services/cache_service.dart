import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';

/// Сервис для кеширования товаров локально.
/// In-memory кеш убирает повторное чтение 20k+ товаров с диска при каждом сканировании.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _productsCacheKey = 'cached_products';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const String _lastSyncKey = 'last_sync_timestamp';

  List<ProductModel>? _memoryProducts;
  Map<String, ProductModel>? _barcodeIndex;

  void _invalidateMemoryCache() {
    _memoryProducts = null;
    _barcodeIndex = null;
  }

  /// Сохранить товары в кеш
  Future<void> cacheProducts(List<ProductModel> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJson = products.map((p) => p.toJson()).toList();
      await prefs.setString(_productsCacheKey, jsonEncode(productsJson));
      await prefs.setString(_cacheTimestampKey, DateTime.now().toIso8601String());
      _memoryProducts = List.from(products);
      _barcodeIndex = { for (final p in products) if (p.barcode != null && p.barcode!.isNotEmpty) p.barcode!: p };
      print('💾 Товары сохранены в кеш: ${products.length} шт.');
    } catch (e) {
      print('❌ Ошибка сохранения кеша: $e');
      _invalidateMemoryCache();
    }
  }

  /// Загрузить товары из кеша (один раз с диска, дальше из памяти)
  Future<List<ProductModel>> getCachedProducts() async {
    if (_memoryProducts != null) return _memoryProducts!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJsonString = prefs.getString(_productsCacheKey);
      if (productsJsonString == null) return [];

      final productsJson = jsonDecode(productsJsonString) as List;
      final products = productsJson
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
      _memoryProducts = products;
      _barcodeIndex = { for (final p in products) if (p.barcode != null && p.barcode!.isNotEmpty) p.barcode!: p };
      print('📦 Товары загружены из кеша: ${products.length} шт.');
      return products;
    } catch (e) {
      print('❌ Ошибка загрузки кеша: $e');
      return [];
    }
  }

  /// Обновить один товар в кеше
  Future<void> updateCachedProduct(ProductModel product) async {
    try {
      final products = await getCachedProducts();
      final index = products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        products[index] = product;
      } else {
        products.add(product);
      }
      await cacheProducts(products);
      print('✅ Товар обновлен в кеше: ${product.name}');
    } catch (e) {
      print('❌ Ошибка обновления товара в кеше: $e');
      _invalidateMemoryCache();
    }
  }

  /// Получить товар из кеша по ID
  Future<ProductModel?> getCachedProductById(int productId) async {
    try {
      final products = await getCachedProducts();
      final found = products.where((p) => p.id == productId).toList();
      return found.isNotEmpty ? found.first : null;
    } catch (e) {
      return null;
    }
  }

  /// Получить товар из кеша по штрихкоду (O(1) после первой загрузки)
  Future<ProductModel?> getCachedProductByBarcode(String barcode) async {
    try {
      if (_barcodeIndex != null) return _barcodeIndex![barcode];
      await getCachedProducts();
      return _barcodeIndex?[barcode];
    } catch (e) {
      return null;
    }
  }

  /// Очистить кеш
  Future<void> clearCache() async {
    try {
      _invalidateMemoryCache();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_productsCacheKey);
      await prefs.remove(_cacheTimestampKey);
      await prefs.remove(_lastSyncKey);
      print('🗑️ Кеш очищен');
    } catch (e) {
      print('❌ Ошибка очистки кеша: $e');
    }
  }

  /// Получить время последнего кеширования
  Future<DateTime?> getCacheTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampString = prefs.getString(_cacheTimestampKey);
      if (timestampString != null) {
        return DateTime.parse(timestampString);
      }
    } catch (e) {
      print('❌ Ошибка получения времени кеша: $e');
    }
    return null;
  }

  /// Сохранить время последней синхронизации
  Future<void> setLastSyncTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, time.toIso8601String());
    } catch (e) {
      print('❌ Ошибка сохранения времени синхронизации: $e');
    }
  }

  /// Получить время последней синхронизации
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampString = prefs.getString(_lastSyncKey);
      if (timestampString != null) {
        return DateTime.parse(timestampString);
      }
    } catch (e) {
      print('❌ Ошибка получения времени синхронизации: $e');
    }
    return null;
  }
}
