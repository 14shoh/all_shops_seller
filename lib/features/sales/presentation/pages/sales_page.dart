import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/storage_service.dart';
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
  
  bool _isLoading = false;
  List<dynamic> _sales = [];

  // Безопасное преобразование строк в числа (MySQL возвращает decimal как строки)
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
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

  // Вычислить общую сумму за день
  double _calculateDailyTotal() {
    final now = DateTime.now();
    final todayDateOnly = DateTime(now.year, now.month, now.day);
    
    return _sales.fold<double>(0.0, (sum, sale) {
      try {
        final saleDate = _parseDate(sale['createdAt']);
        final saleDateOnly = DateTime(saleDate.year, saleDate.month, saleDate.day);
        
        if (saleDateOnly.isAtSameMomentAs(todayDateOnly)) {
          return sum + _parseDouble(sale['totalAmount']);
        }
      } catch (e) {}
      return sum;
    });
  }

  // Вычислить общую сумму за неделю
  double _calculateWeeklyTotal() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    
    return _sales.fold<double>(0.0, (sum, sale) {
      try {
        final saleDate = _parseDate(sale['createdAt']);
        final saleDateOnly = DateTime(saleDate.year, saleDate.month, saleDate.day);
        
        if (saleDateOnly.isAfter(weekStartDay) || saleDateOnly.isAtSameMomentAs(weekStartDay)) {
          return sum + _parseDouble(sale['totalAmount']);
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

  Future<void> _loadSales() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final shopId = await _storageService.getShopId();
      if (shopId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await _apiService.get(
        AppConfig.salesEndpoint,
        queryParameters: {'limit': 200, 'page': 1},
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = response.data;
          if (data is Map && data.containsKey('data')) {
            final salesList = data['data'] as List;
            setState(() {
              _sales = salesList;
              _isLoading = false;
            });
          } else if (data is List) {
            setState(() {
              _sales = data;
              _isLoading = false;
            });
          } else {
            setState(() {
              _sales = [];
              _isLoading = false;
            });
          }
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Единый Header
            ScreenHeader(
              title: 'История продаж',
              subtitle: 'Всего продаж: ${_sales.length}',
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

            // Статистика
            if (_sales.isNotEmpty)
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _sales.isEmpty
                      ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadSales,
                            child: ListView.builder(
                              itemCount: _sales.length,
                              padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
                              itemBuilder: (context, index) {
                                final sale = _sales[index];
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
    return AppCard(
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
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.paddingMD),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: const Icon(
              Icons.receipt_rounded,
              color: AppTheme.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Продажа #${sale['id']}',
                  style: AppTheme.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd.MM.yyyy HH:mm').format(_parseDate(sale['createdAt'])),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingSM, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Text(
              '${_parseDouble(sale['totalAmount']).toStringAsFixed(2)} ${AppConstants.currencySymbol}',
              style: AppTheme.priceText.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
