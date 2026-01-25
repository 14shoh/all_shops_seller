import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';
import '../../config/app_config.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('🔐 Попытка входа: $username'); // Отладка
      
      final response = await _apiService.post(
        AppConfig.loginEndpoint,
        data: {
          'username': username,
          'password': password,
        },
      );
      
      print('✅ Ответ получен: ${response.statusCode}'); // Отладка
      print('📦 Данные: ${response.data}'); // Отладка
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          print('🔄 Начинаю парсинг ответа...'); // Отладка
          final authResponse = AuthResponse.fromJson(response.data);
          print('✅ Парсинг успешен!'); // Отладка
          print('✅ Токен получен: ${authResponse.accessToken.substring(0, 20)}...'); // Отладка
          print('👤 Пользователь: ${authResponse.user.username}, ID: ${authResponse.user.id}'); // Отладка
          
          _user = authResponse.user;
          print('✅ Пользователь установлен в provider'); // Отладка
          
          await _storageService.saveToken(authResponse.accessToken);
          print('✅ Токен сохранен'); // Отладка
          
          await _storageService.saveUserData(authResponse.user.toJson());
          print('✅ Данные пользователя сохранены'); // Отладка
          
          if (authResponse.user.shopId != null) {
            await _storageService.saveShopId(authResponse.user.shopId!);
            print('✅ ShopId сохранен: ${authResponse.user.shopId}'); // Отладка
            
            // Получаем номер счета для оплаты
            await _loadPaymentAccountNumber(authResponse.user.shopId!);
          }
          
          _isLoading = false;
          notifyListeners();
          print('✅ Вход выполнен успешно!'); // Отладка
          return true;
        } catch (parseError, stackTrace) {
          print('❌ Ошибка парсинга ответа: $parseError'); // Отладка
          print('📚 Stack trace: $stackTrace'); // Отладка
          _error = 'Ошибка обработки ответа сервера: $parseError';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        _error = 'Неверный логин или пароль (код: ${response.statusCode})';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      String errorMessage = 'Ошибка подключения к серверу';
      
      // Детальная обработка ошибок Dio
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout || 
            e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Превышено время ожидания. Проверьте подключение';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = 'Не удалось подключиться к серверу.\n'
              'Проверьте, что бэкенд запущен на ${AppConfig.baseUrl}';
        } else if (e.response != null) {
          // Обработка HTTP ошибок
          final statusCode = e.response!.statusCode;
          if (statusCode == 401) {
            final message = e.response!.data?['message'] ?? 'Неверный логин или пароль';
            errorMessage = message;
          } else if (statusCode == 400) {
            final message = e.response!.data?['message'] ?? 'Неверный запрос';
            errorMessage = 'Ошибка запроса: $message';
          } else {
            errorMessage = 'Ошибка сервера ($statusCode): ${e.response!.data?.toString() ?? e.message}';
          }
        } else {
          errorMessage = 'Ошибка сети: ${e.message}';
        }
      } else if (e.toString().contains('SocketException') || 
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused')) {
        errorMessage = 'Не удалось подключиться к серверу.\n'
            'Проверьте, что бэкенд запущен на ${AppConfig.baseUrl}';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Превышено время ожидания. Проверьте подключение к интернету';
      } else {
        errorMessage = 'Ошибка: ${e.toString()}';
      }
      
      print('Login error: $e'); // Для отладки
      
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> logout() async {
    _user = null;
    await _storageService.clearAll();
    // Удаляем номер счета при выходе
    await StorageService.setString('payment_account_number', '');
    notifyListeners();
  }
  
  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final token = await _storageService.getToken();
      
      if (token != null) {
        // Загружаем данные пользователя из хранилища
        final userData = await _storageService.getUserData();
        
        if (userData != null) {
          try {
            _user = UserModel.fromJson(userData);
            print('✅ Пользователь восстановлен из хранилища: ${_user?.username}');
          } catch (e) {
            print('❌ Ошибка восстановления пользователя: $e');
            _user = null;
          }
        }
      } else {
        _user = null;
      }
    } catch (e) {
      print('❌ Ошибка проверки авторизации: $e');
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> initialize() async {
    await checkAuth();
    
    // Если пользователь авторизован, загружаем номер счета
    if (_user != null && _user!.shopId != null) {
      await _loadPaymentAccountNumber(_user!.shopId!);
    }
  }

  Future<void> _loadPaymentAccountNumber(int shopId) async {
    try {
      // Берем номер 1 раз за сессию: если уже есть в локальном хранилище — не дергаем API.
      final cached = await StorageService.getString('payment_account_number');
      if (cached != null && cached.trim().isNotEmpty) {
        return;
      }

      // По требованию: номер для QR берём из таблицы shops (поле phone)
      final response = await _apiService.get('/shops/$shopId/phone');
      
      if (response.statusCode == 200) {
        final phone = response.data['phone'];
        if (phone != null && phone.toString().trim().isNotEmpty) {
          await StorageService.setString('payment_account_number', phone.toString().trim());
          print('✅ Номер для QR загружен из shops.phone: $phone');
        } else {
          // Если номер не установлен — оставляем дефолтный (PaymentPage подставит его)
          await StorageService.setString('payment_account_number', '');
          print('⚠️ shops.phone пустой, будет использован дефолтный номер на экране оплаты');
        }
      }
    } catch (e) {
      print('⚠️ Ошибка загрузки номера счета: $e');
      // В случае ошибки не затираем, оставляем пустым (PaymentPage подставит дефолтный)
      await StorageService.setString('payment_account_number', '');
    }
  }
}
