import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants/app_constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();
  
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }
  
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }
  
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    // Сохраняем данные пользователя в JSON для восстановления
    await prefs.setString('user_data', jsonEncode(userData));
    // Также сохраняем shopId отдельно для быстрого доступа
    if (userData['shopId'] != null) {
      await prefs.setInt(AppConstants.shopIdKey, userData['shopId']);
    }
  }
  
  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataJson = prefs.getString('user_data');
    if (userDataJson != null) {
      try {
        return jsonDecode(userDataJson) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  Future<void> saveShopId(int shopId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.shopIdKey, shopId);
  }
  
  Future<int?> getShopId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.shopIdKey);
  }
  
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
