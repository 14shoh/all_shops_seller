import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/sales_cache_service.dart';
import '../../../../core/providers/sale_provider.dart';
import '../../../../config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final SalesCacheService _salesCache = SalesCacheService();

  bool _isLoading = false;
  bool _isBackgroundRefreshing = false;
  List<dynamic> _sales = [];
  List<Map<String, dynamic>> _pendingSales = [];
  int _lastPendingCount = -1;

  // Безопасное преобразование строк в числа (MySQL возвращает decimal как строки)
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Достаём сумму продажи с максимальной совместимостью:
  /// - totalAmount (основное поле на бэкенде)
  /// - total_amount / total (если вдруг приходит так)
  /// - items[].totalPrice или salePrice*quantity (с учётом кг/л для grocery/general)
  double _extractTotal(dynamic sale) {
    try {
      if (sale is Map) {
        final ta = sale['totalAmount'] ?? sale['total_amount'] ?? sale['total'];
        if (ta != null) return _parseDouble(ta);

        // Попытка посчитать по позициям
        final items = sale['items'];
        if (items is List) {
          double sum = 0.0;
          for (final it in items) {
            if (it is Map) {
              final tp = it['totalPrice'] ?? it['total_price'];
              if (tp != null) {
                sum += _parseDouble(tp);
              } else if ((it['salePrice'] ?? it['sale_price']) != null && (it['quantity']) != null) {
                final price = _parseDouble(it['salePrice'] ?? it['sale_price']);
                final qtyRaw = it['quantity'];
                final qtyInt = (qtyRaw is num) ? qtyRaw.toInt() : int.tryParse(qtyRaw.toString()) ?? 0;
                final unit = (it['quantityUnit'] ?? it['quantity_unit'] ?? 'шт').toString();
                // quantity уже в кг/л/шт
                final itemTotal = price * qtyInt;
                sum += itemTotal;
              }
            }
          }
          if (sum > 0) return sum;
        }
      }
    } catch (_) {}
    return 0.0;
  }

  // Парсинг даты с учетом UTC
  DateTime _parseDate(dynamic dateValue) {
    try {
      final dateStr = dateValue.toString().trim();
      final parsed = DateTime.parse(dateStr);
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (e) {
      try {
        return DateTime.parse(dateValue.toString());
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  /// Объединённый список: офлайн-продажи + серверные, по дате (новые сверху).
  List<dynamic> get _combinedSales {
    final combined = <dynamic>[..._pendingSales, ..._sales];
    combined.sort((a, b) {
      final aDate = _parseDate(a['createdAt']);
      final bDate = _parseDate(b['createdAt']);
      return bDate.compareTo(aDate);
    });
    return combined;
  }

  double _calculateDailyTotal() {
    final now = DateTime.now();
    final todayDateOnly = DateTime(now.year, now.month, now.day);
    return _combinedSales.fold<double>(0.0, (sum, sale) {
      try {
        final saleDate = _parseDate(sale['createdAt']);
        final saleDateOnly = DateTime(saleDate.year, saleDate.month, saleDate.day);
        if (saleDateOnly.isAtSameMomentAs(todayDateOnly)) {
          return sum + _extractTotal(sale);
        }
      } catch (e) {}
      return sum;
    });
  }

  double _calculateWeeklyTotal() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _combinedSales.fold<double>(0.0, (sum, sale) {
      try {
        final saleDate = _parseDate(sale['createdAt']);
        final saleDateOnly = DateTime(saleDate.year, saleDate.month, saleDate.day);
        if (saleDateOnly.isAfter(weekStartDay) || saleDateOnly.isAtSameMomentAs(weekStartDay)) {
          return sum + _extractTotal(sale);
        }
      } catch (e) {}
      return sum;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadPendingAndNotify() async {
    final saleProvider = context.read<SaleProvider>();
    final pending = await saleProvider.getPendingSalesForDisplay();
    if (mounted) setState(() => _pendingSales = pending);
  }

  Future<void> _loadSales() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isBackgroundRefreshing = false;
    });

    try {
      final shopId = await _storageService.getShopId();
      if (shopId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. Сначала попробуем отправить офлайн продажи (если интернет есть)
      final saleProvider = context.read<SaleProvider>();
      await saleProvider.syncPendingSales();

      // 2. Сразу показать кеш + обновлённые офлайн-продажи
      final cached = await _salesCache.getCachedSales();
      await _loadPendingAndNotify();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _sales = cached;
          _isLoading = false;
          _isBackgroundRefreshing = true;
        });
      }

      // 3. Фоново загрузить с сервера
      try {
        final response = await _apiService.get(
          AppConfig.salesEndpoint,
          queryParameters: {'limit': 200, 'page': 1, 'scope': 'shop'},
        );

        if (mounted && response.statusCode == 200) {
          final data = response.data;
          List<dynamic> salesList = [];
          if (data is Map && data.containsKey('data')) {
            salesList = data['data'] as List;
          } else if (data is List) {
            salesList = data;
          }
          final asMaps = salesList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          await _salesCache.setCachedSales(asMaps);
          await _loadPendingAndNotify();
          if (mounted) {
            setState(() {
              _sales = salesList;
              _isBackgroundRefreshing = false;
              _isLoading = false;
            });
          }
        } else if (mounted) {
          setState(() => _isBackgroundRefreshing = false);
          setState(() => _isLoading = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isBackgroundRefreshing = false);
          if (_sales.isEmpty) setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saleProvider = context.watch<SaleProvider>();
    if (saleProvider.pendingSalesCount != _lastPendingCount) {
      _lastPendingCount = saleProvider.pendingSalesCount;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPendingAndNotify());
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Единый Header
            ScreenHeader(
              title: 'История продаж',
              subtitle: _isBackgroundRefreshing
                  ? 'Обновление... • ${_combinedSales.length} продаж'
                  : 'Всего продаж: ${_combinedSales.length}',
              icon: Icons.receipt_long_rounded,
              iconColor: AppTheme.successColor,
              actions: [
                GestureDetector(
                  onTap: _loadSales,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 22,
                      color: AppTheme.successColor,
                    ),
                  ),
                ),
              ],
            ),

            // Статистика (всегда показываем для всех типов магазинов: clothing, grocery, general)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.paddingXL,
                vertical: AppTheme.paddingXS,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Сегодня',
                      '${_calculateDailyTotal().toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                      AppTheme.primaryColor,
                      Icons.today_rounded,
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingSM),
                  Expanded(
                    child: _buildStatCard(
                      'Неделя',
                      '${_calculateWeeklyTotal().toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                      AppTheme.successColor,
                      Icons.calendar_view_week_rounded,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.paddingMD),

            // Список
            Expanded(
              child: _isLoading && _combinedSales.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _combinedSales.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadSales,
                          child: ListView.builder(
                            itemCount: _combinedSales.length,
                            padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
                            itemBuilder: (context, index) {
                              final sale = _combinedSales[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppTheme.paddingSM),
                                  child: _buildSaleCard(sale),
                                );
                              },
                            ),
                          ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    VoidCallback? onTap;
    if (title == 'Сегодня') {
      onTap = () => _showDailySales(context);
    } else if (title == 'Неделя') {
      onTap = () => _showWeeklySales(context);
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(title, style: AppTheme.labelText.copyWith(color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: AppTheme.paddingXS),
          Text(
            value,
            style: AppTheme.priceText.copyWith(fontSize: 16, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showDailySales(BuildContext context) {
    final now = DateTime.now();
    final todayDateOnly = DateTime(now.year, now.month, now.day);
    final todaySales = _combinedSales.where((sale) {
      try {
        final saleDate = _parseDate(sale['createdAt']);
        final saleDateOnly = DateTime(saleDate.year, saleDate.month, saleDate.day);
        return saleDateOnly.isAtSameMomentAs(todayDateOnly);
      } catch (e) {
        return false;
      }
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.paddingXL),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Продажи за сегодня',
                          style: AppTheme.screenTitle.copyWith(fontSize: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${todaySales.length} продаж',
                          style: AppTheme.screenSubtitle,
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: todaySales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                            const SizedBox(height: AppTheme.paddingXL),
                            Text(
                              'Нет продаж за сегодня',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppTheme.paddingXS),
                            Text(
                              'Совершите первую продажу',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
                        itemCount: todaySales.length,
                        itemBuilder: (context, index) {
                          final sale = todaySales[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppTheme.paddingSM),
                            child: _buildSaleCard(sale),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWeeklySales(BuildContext context) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weeklySales = _combinedSales.where((sale) {
      try {
        final saleDate = _parseDate(sale['createdAt']);
        final saleDateOnly = DateTime(saleDate.year, saleDate.month, saleDate.day);
        return saleDateOnly.isAfter(weekStartDay) || saleDateOnly.isAtSameMomentAs(weekStartDay);
      } catch (e) {
        return false;
      }
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.paddingXL),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Продажи за неделю',
                          style: AppTheme.screenTitle.copyWith(fontSize: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${weeklySales.length} продаж',
                          style: AppTheme.screenSubtitle,
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: weeklySales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                            const SizedBox(height: AppTheme.paddingXL),
                            Text(
                              'Нет продаж за неделю',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppTheme.paddingXS),
                            Text(
                              'Совершите первую продажу',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
                        itemCount: weeklySales.length,
                        itemBuilder: (context, index) {
                          final sale = weeklySales[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppTheme.paddingSM),
                            child: _buildSaleCard(sale),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: AppTheme.paddingXL),
          Text('Нет продаж', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTheme.paddingXS),
          Text(
            'Совершите первую продажу',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(dynamic sale) {
    final isOffline = sale['isOffline'] == true;
    final idLabel = sale['id'] != null ? 'Продажа #${sale['id']}' : 'Офлайн продажа';
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.paddingMD),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isOffline ? AppTheme.warningColor.withOpacity(0.15) : AppTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Icon(
              isOffline ? Icons.cloud_off_rounded : Icons.receipt_rounded,
              color: isOffline ? AppTheme.warningColor : AppTheme.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        idLabel,
                        style: AppTheme.cardTitle.copyWith(fontSize: 15),
                      ),
                    ),
                    if (isOffline)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Офлайн',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd.MM.yyyy HH:mm').format(_parseDate(sale['createdAt'])),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingSM, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  '${_extractTotal(sale).toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                  style: AppTheme.priceText.copyWith(fontSize: 14),
                ),
              ),
              if (!isOffline && sale['id'] != null) ...[
                const SizedBox(height: AppTheme.paddingXS),
                GestureDetector(
                  onTap: () => _showDeleteConfirmation(sale['id']),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_rounded,
                      size: 18,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int saleId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить продажу?'),
        content: const Text('Товары вернутся на склад. Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSale(saleId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSale(int saleId) async {
    try {
      final response = await _apiService.delete('/sales/$saleId');
      
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Продажа удалена'),
              backgroundColor: Colors.green,
            ),
          );
          _loadSales();
        }
      } else {
        throw Exception('Ошибка удаления');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
