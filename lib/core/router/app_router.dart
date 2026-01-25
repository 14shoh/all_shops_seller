import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/main_screen.dart';
import '../../features/products/presentation/pages/add_product_page.dart';
import '../../features/products/presentation/pages/products_list_page.dart';
import '../../features/sales/presentation/pages/sales_page.dart';
import '../../features/sales/presentation/pages/create_sale_page.dart';
import '../providers/auth_provider.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authProvider,
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authProvider.isAuthenticated;
      final currentLocation = state.matchedLocation;
      final isLoginRoute = currentLocation == '/login' || currentLocation == '/';
      
      // Если пользователь не залогинен
      if (!isLoggedIn) {
        // Разрешаем только страницу логина
        if (!isLoginRoute) {
          return '/login';
        }
        return null; // Разрешаем оставаться на странице логина
      }
      
      // Если пользователь залогинен
      if (isLoggedIn) {
        // Если пытается попасть на страницу логина - перенаправляем на главную
        if (isLoginRoute) {
          return '/main';
        }
        // Для всех остальных маршрутов разрешаем переход
        return null;
      }
      
      return null; // Разрешаем переход
    },
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) {
        // Редирект с "/" в зависимости от авторизации
        return authProvider.isAuthenticated ? '/main' : '/login';
      },
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/main',
      name: 'main',
      builder: (context, state) => const MainScreen(),
      routes: [
        GoRoute(
          path: ':tab',
          name: 'main-tab',
          builder: (context, state) {
            final raw = state.pathParameters['tab'] ?? '0';
            final index = int.tryParse(raw) ?? 0;
            return MainScreen(initialIndex: index);
          },
        ),
      ],
    ),
    // Остальные маршруты остаются для возможности прямого перехода, 
    // но теперь они будут встроены в MainScreen через IndexedStack
    GoRoute(
      path: '/home',
      name: 'home',
      // Раньше это был отдельный экран меню. Сейчас все экраны живут внутри `MainScreen`.
      // Если где-то остались переходы на /home, не даем "застрять" без нижней навигации.
      redirect: (context, state) => '/main',
    ),
    GoRoute(
      path: '/products',
      name: 'products',
      builder: (context, state) => const ProductsListPage(),
    ),
    GoRoute(
      path: '/products/add',
      name: 'add-product',
      builder: (context, state) => const AddProductPage(),
    ),
    GoRoute(
      path: '/sales',
      name: 'sales',
      builder: (context, state) => const SalesPage(),
    ),
    GoRoute(
      path: '/sales/create',
      name: 'create-sale',
      builder: (context, state) => const CreateSalePage(),
    ),
  ],
  );
}

// Router создается в main.dart с передачей authProvider
