import 'dart:io' show Platform;

class AppConfig {
  // API Configuration
  // Для эмулятора Android используйте: 'http://10.0.2.2:3000'
  // Для реального устройства используйте IP вашего компьютера: 'http://192.168.x.x:3000'
  // Для iOS симулятора: 'http://localhost:3000'
  // ✅ Настраивается без правки кода:
  // flutter run --dart-define=API_BASE_URL=http://<PC_IP>:3000
  // Пример (часто для hotspot/Wi‑Fi): http://172.20.10.3:3000
  //
  // ВАЖНО:
  // - Production (по умолчанию): http://155.212.211.121:3000
  // - Android эмулятор: http://10.0.2.2:3000 (доступ к localhost ПК)
  // - iOS симулятор: http://localhost:3000
  // - Реальный телефон: http://<IP_ПК>:3000 (и разрешить порт в firewall)
  static String get baseUrl {
    const env = String.fromEnvironment('API_BASE_URL');
    if (env.isNotEmpty) return env;
    return _defaultBaseUrlByPlatform();
  }

  static String _defaultBaseUrlByPlatform() {
    // По умолчанию используем боевой сервер, dart-define остаётся приоритетнее.
    const prod = 'http://155.212.211.121:3000';
    if (Platform.isAndroid) return prod;
    if (Platform.isIOS) return prod;
    return prod;
  }
  
  // API Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String productsEndpoint = '/products';
  static const String salesEndpoint = '/sales';
  static const String warehouseEndpoint = '/warehouse';
  static const String customerDebtsEndpoint = '/customer-debts';
  static const String supplierDebtsEndpoint = '/supplier-debts';
  
  // App Info
  static const String appName = 'Seller App';
  static const String appVersion = '1.0.0';
}
