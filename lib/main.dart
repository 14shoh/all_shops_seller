import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/router/app_router.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/product_provider.dart';
import 'core/providers/sale_provider.dart';
import 'core/providers/debt_provider.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализируем локализацию для русского языка
  try {
    await initializeDateFormatting('ru', null);
    print('✅ Локализация русского языка успешно инициализирована');
  } catch (e) {
    print('⚠️ Ошибка инициализации локализации: $e');
    // Продолжаем работу, но даты будут отображаться в английском формате
  }
  
  // Инициализируем провайдеры
  final authProvider = AuthProvider();
  final productProvider = ProductProvider();
  final saleProvider = SaleProvider();
  final debtProvider = DebtProvider();
  
  // Проверяем авторизацию при запуске (загружаем данные пользователя из хранилища)
  await authProvider.initialize();
  
  // Если авторизован, загружаем товары и синхронизируем продажи
  if (authProvider.isAuthenticated) {
    await productProvider.loadProducts();
    await saleProvider.syncPendingSales();
  }
  
  print('🚀 Запуск приложения. Авторизован: ${authProvider.isAuthenticated}');
  
  runApp(MyApp(
    authProvider: authProvider,
    productProvider: productProvider,
    saleProvider: saleProvider,
    debtProvider: debtProvider,
  ));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  final ProductProvider productProvider;
  final SaleProvider saleProvider;
  final DebtProvider debtProvider;
  
  const MyApp({
    super.key,
    required this.authProvider,
    required this.productProvider,
    required this.saleProvider,
    required this.debtProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: productProvider),
        ChangeNotifierProvider.value(value: saleProvider),
        ChangeNotifierProvider.value(value: debtProvider),
      ],
      child: MaterialApp.router(
        title: 'Seller App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: createRouter(authProvider),
      ),
    );
  }
}
