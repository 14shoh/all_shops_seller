import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../config/app_config.dart';

/// Сервис для проверки подключения к интернету
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectionController;
  bool _hasConnection = true;

  /// Получить текущий статус подключения (только наличие сети, без пинга)
  Future<bool> hasConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _hasConnection = results.any((r) => r != ConnectivityResult.none);
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
        (results) {
          _hasConnection = results.any((r) => r != ConnectivityResult.none);
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

  /// Реальная проверка доступности сервера (пинг API)
  Future<bool> hasInternetConnection() async {
    try {
      final hasNet = await hasConnection();
      if (!hasNet) return false;

      final uri = Uri.parse(AppConfig.baseUrl);
      final socket = await Socket.connect(
        uri.host,
        uri.port,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (e) {
      print('⚠️ Ошибка пинга сервера: $e');
      return false;
    }
  }

  void dispose() {
    _connectionController?.close();
    _connectionController = null;
  }
}
