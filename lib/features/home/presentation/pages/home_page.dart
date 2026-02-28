import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/providers/sale_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static String _pendingSyncSubtitle(int total, int products, int sales, int updates) {
    final parts = <String>[];
    if (products > 0) parts.add('$products ${products == 1 ? 'товар' : 'товаров'}');
    if (sales > 0) parts.add('$sales ${sales == 1 ? 'продажа' : 'продаж'}');
    if (updates > 0) parts.add('$updates обнов.');
    return 'Ожидает отправки: ${parts.join(', ')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      final saleProvider = context.read<SaleProvider>();
      productProvider.loadProducts();
      // Сначала офлайн товары (реальные ID), затем офлайн продажи
      productProvider.syncPendingProducts().then((_) => saleProvider.syncPendingSales());
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final productProvider = context.watch<ProductProvider>();
    final saleProvider = context.watch<SaleProvider>();
    final isOffline = productProvider.isOffline || saleProvider.isOffline;
    final pendingSync = productProvider.pendingSyncCount;
    final pendingProducts = productProvider.pendingProductsCount;
    final pendingSales = saleProvider.pendingSalesCount;
    final totalPending = pendingSync + pendingProducts + pendingSales;

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HeaderCard(
                username: authProvider.user?.username ?? 'Пользователь',
                isOffline: isOffline,
                totalPending: totalPending,
                pendingProducts: pendingProducts,
                pendingSales: pendingSales,
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.paddingXL,
                AppTheme.paddingMD,
                AppTheme.paddingXL,
                AppTheme.paddingSM,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Быстрые действия',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.paddingSM,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                            size: 16,
                            color: isOffline ? AppTheme.warningColor : AppTheme.successColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOffline ? 'Офлайн' : 'Онлайн',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Одна умная карточка: офлайн продажи и товары / синхронизация.
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
              sliver: SliverToBoxAdapter(
                child: _OfflineOperationsCard(
                  isOffline: isOffline,
                  pendingSalesCount: saleProvider.pendingSalesCount,
                  pendingProductsCount: productProvider.pendingProductsCount,
                  isSyncingSales: saleProvider.isSyncingPendingSales,
                  isSyncingProducts: productProvider.isSyncingPendingProducts,
                  onSyncNow: () async {
                    final productProvider = context.read<ProductProvider>();
                    final saleProvider = context.read<SaleProvider>();
                    await productProvider.syncPendingProducts();
                    await saleProvider.syncPendingSales();
                  },
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.paddingXL,
                AppTheme.paddingXL,
                AppTheme.paddingXL,
                AppTheme.paddingXL,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сервис',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppTheme.paddingMD),

                    AppCard(
                      padding: const EdgeInsets.all(AppTheme.paddingMD),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isOffline
                                    ? const [Color(0xFFF97316), Color(0xFFEF4444)]
                                    : const [Color(0xFF0EA5E9), Color(0xFF22C55E)],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            ),
                            child: const Icon(Icons.sync_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: AppTheme.paddingMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Синхронизация',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isOffline
                                      ? 'Офлайн режим: синхронизация будет позже'
                                      : (totalPending > 0
                                          ? _pendingSyncSubtitle(totalPending, pendingProducts, pendingSales, pendingSync)
                                          : 'Все данные синхронизированы'),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTheme.paddingSM),
                          TextButton(
                            onPressed: () => context.read<ProductProvider>().syncNow(),
                            child: const Text('Сейчас'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.paddingXL),

                    Text(
                      'Аккаунт',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppTheme.paddingMD),

                    AppCard(
                      padding: const EdgeInsets.all(AppTheme.paddingMD),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            ),
                            child: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                          ),
                          const SizedBox(width: AppTheme.paddingMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Выйти из аккаунта',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Номер для QR очистится до следующего входа',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final shouldLogout = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                                  ),
                                  title: Text('Выйти?', style: Theme.of(context).textTheme.titleLarge),
                                  content: Text(
                                    'Вы уверены, что хотите выйти из аккаунта?',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Отмена'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.errorColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Выйти'),
                                    ),
                                  ],
                                ),
                              );

                              if (shouldLogout == true) {
                                await authProvider.logout();
                                if (context.mounted) context.go('/login');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              ),
                            ),
                            child: const Text('Выйти'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineOperationsCard extends StatelessWidget {
  final bool isOffline;
  final int pendingSalesCount;
  final int pendingProductsCount;
  final bool isSyncingSales;
  final bool isSyncingProducts;
  final VoidCallback onSyncNow;

  const _OfflineOperationsCard({
    required this.isOffline,
    required this.pendingSalesCount,
    required this.pendingProductsCount,
    required this.isSyncingSales,
    required this.isSyncingProducts,
    required this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    final totalPending = pendingSalesCount + pendingProductsCount;
    final isSyncing = isSyncingSales || isSyncingProducts;
    final shouldShow = totalPending > 0 || isSyncing || isOffline;
    if (!shouldShow) return const SizedBox.shrink();

    String title = 'Офлайн операции';
    String subtitle;
    
    if (isSyncing) {
      subtitle = 'Идёт синхронизация…';
    } else if (totalPending > 0) {
      final parts = <String>[];
      if (pendingSalesCount > 0) {
        parts.add('$pendingSalesCount продаж');
      }
      if (pendingProductsCount > 0) {
        parts.add('$pendingProductsCount товаров');
      }
      subtitle = 'Ожидает отправки: ${parts.join(', ')}';
    } else if (isOffline) {
      subtitle = 'Нет интернета — данные будут копиться локально';
    } else {
      subtitle = 'Все офлайн операции отправлены';
    }

    final colors = isSyncing
        ? const [Color(0xFF0EA5E9), Color(0xFF22C55E)]
        : (totalPending > 0
            ? const [Color(0xFFF97316), Color(0xFFEF4444)]
            : const [Color(0xFF6366F1), Color(0xFF8B5CF6)]);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingLG),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                ),
                child: Icon(
                  isSyncing
                      ? Icons.sync_rounded
                      : (totalPending > 0 ? Icons.cloud_upload_rounded : Icons.cloud_done_rounded),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppTheme.paddingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.paddingSM),
              if (!isOffline && totalPending > 0 && !isSyncing)
                ElevatedButton(
                  onPressed: onSyncNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: colors.first,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Отправить'),
                )
              else if (isSyncing)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String username;
  final bool isOffline;
  final int totalPending;
  final int pendingProducts;
  final int pendingSales;

  const _HeaderCard({
    required this.username,
    required this.isOffline,
    required this.totalPending,
    required this.pendingProducts,
    required this.pendingSales,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.paddingXL),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -60,
                bottom: -60,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.paddingLG),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                        border: Border.all(color: Colors.white.withOpacity(0.22)),
                      ),
                      child: const Icon(Icons.menu_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: AppTheme.paddingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Меню',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            username,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.92),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOffline
                                ? 'Офлайн'
                                : (totalPending > 0
                                    ? '$totalPending ждёт'
                                    : 'Ок'),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
