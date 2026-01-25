import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Сервис для проверки подключения к интернету
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectionController;
  bool _hasConnection = true;

  /// Получить текущий статус подключения
  Future<bool> hasConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _hasConnection = result != ConnectivityResult.none;
      return _hasConnection;
    } catch (e) {
      print('❌ Ошибка проверки подключения: $e');
      return false;
    }
  }

  /// Получить поток изменений подключения
  Stream<bool> get onConnectionChanged {
    if (_connectionController == null) {
      _connectionController = StreamController<bool>.broadcast();
      
      _connectivity.onConnectivityChanged.listen(
        (result) {
          _hasConnection = result != ConnectivityResult.none;
          _connectionController?.add(_hasConnection);
          print(_hasConnection 
              ? '✅ Подключение к интернету восстановлено' 
              : '❌ Подключение к интернету потеряно');
        },
        onError: (error) {
          print('❌ Ошибка потока подключения: $error');
        },
      );
    }

    return _connectionController!.stream;
  }

  /// Проверить, есть ли активное подключение (не просто наличие сети, а реальный интернет)
  Future<bool> hasInternetConnection() async {
    try {
      // Простая проверка - если есть подключение, считаем что есть интернет
      // В реальном приложении можно добавить ping к серверу
      return await hasConnection();
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _connectionController?.close();
    _connectionController = null;
  }
}
