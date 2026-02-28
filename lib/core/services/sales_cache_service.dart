import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Кеш истории продаж для быстрого отображения при входе и офлайне.
class SalesCacheService {
  static final SalesCacheService _instance = SalesCacheService._internal();
  factory SalesCacheService() => _instance;
  SalesCacheService._internal();

  static const String _salesCacheKey = 'cached_sales';
  List<Map<String, dynamic>>? _memorySales;

  /// Получить кешированные продажи (из памяти или с диска).
  Future<List<Map<String, dynamic>>> getCachedSales() async {
    if (_memorySales != null) return _memorySales!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_salesCacheKey);
      if (json == null) return [];
      final list = jsonDecode(json) as List;
      _memorySales = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return _memorySales!;
    } catch (e) {
      return [];
    }
  }

  /// Сохранить продажи в кеш.
  Future<void> setCachedSales(List<Map<String, dynamic>> sales) async {
    try {
      _memorySales = List.from(sales);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_salesCacheKey, jsonEncode(sales));
    } catch (e) {
      _memorySales = null;
    }
  }

  void invalidate() {
    _memorySales = null;
  }
}
