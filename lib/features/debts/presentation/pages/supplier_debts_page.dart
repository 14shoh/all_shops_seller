import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/providers/debt_provider.dart';
import '../../../../core/constants/app_constants.dart';

class SupplierDebtsPage extends StatefulWidget {
  const SupplierDebtsPage({super.key});

  @override
  State<SupplierDebtsPage> createState() => _SupplierDebtsPageState();
}

class _SupplierDebtsPageState extends State<SupplierDebtsPage> {
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _totalDebtController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  String? _selectedSupplierId;

  @override
  void initState() {
    super.initState();
    // Загружаем долги при открытии страницы
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtProvider>().loadSupplierDebts();
    });
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _totalDebtController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  Future<void> _addSupplierDebt() async {
    if (_supplierNameController.text.isEmpty || _totalDebtController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните название фирмы и сумму долга')),
      );
      return;
    }

    final totalDebt = double.tryParse(_totalDebtController.text);
    if (totalDebt == null || totalDebt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму долга')),
      );
      return;
    }

    Navigator.pop(context);

    final debtProvider = context.read<DebtProvider>();
    final success = await debtProvider.createSupplierDebt(
      supplierName: _supplierNameController.text,
      totalDebt: totalDebt,
    );

    if (success) {
      _supplierNameController.clear();
      _totalDebtController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Долг перед фирмой успешно добавлен')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(debtProvider.supplierDebtsError ?? 'Ошибка добавления долга'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _addPayment() async {
    if (_selectedSupplierId == null || _paymentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите фирму и введите сумму платежа')),
      );
      return;
    }

    final payment = double.tryParse(_paymentController.text);
    if (payment == null || payment <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму платежа')),
      );
      return;
    }

    final debtId = int.tryParse(_selectedSupplierId!);
    if (debtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: неверный ID долга')),
      );
      return;
    }

    final debtProvider = context.read<DebtProvider>();
    final debt = debtProvider.supplierDebts.firstWhere((d) => d.id == debtId);
    
    if (payment > debt.remainingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сумма платежа не может превышать остаток долга')),
      );
      return;
    }

    Navigator.pop(context);

    final success = await debtProvider.addPaymentToSupplierDebt(debtId, payment);

    if (success) {
      _paymentController.clear();
      _selectedSupplierId = null;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(debtProvider.lastOperationMessage ?? 'Платеж успешно добавлен')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(debtProvider.supplierDebtsError ?? 'Ошибка добавления платежа'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showAddSupplierDebtDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: AppTheme.paddingXL,
          right: AppTheme.paddingXL,
          top: AppTheme.paddingXL,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Добавить долг перед фирмой', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.paddingMD),
              
              AppTextField(
                controller: _supplierNameController,
                label: 'Название фирмы',
                prefixIcon: Icons.business_rounded,
              ),
              
              const SizedBox(height: AppTheme.paddingMD),
              
              AppTextField(
                controller: _totalDebtController,
                label: 'Сумма долга',
                prefixIcon: Icons.attach_money_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              
              const SizedBox(height: AppTheme.paddingXL),
              
              GradientButton(
                text: 'Добавить',
                onPressed: _addSupplierDebt,
                icon: Icons.add_rounded,
              ),
              
              const SizedBox(height: AppTheme.paddingMD),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog() {
    final debtProvider = context.read<DebtProvider>();
    final debts = debtProvider.supplierDebts.where((d) => d.remainingAmount > 0).toList();
    
    if (debts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет долгов для оплаты')),
      );
      return;
    }

    // Сбрасываем выбор при каждом открытии (чтобы не упасть, если список изменился/есть дубликаты)
    _selectedSupplierId = null;
    _paymentController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<DebtProvider>(
        builder: (context, debtProvider, child) {
          final supplierDebtsRaw = debtProvider.supplierDebts.where((d) => d.remainingAmount > 0).toList();
          // Дедупликация для Dropdown: один value -> один item
          final seenIds = <String>{};
          final supplierDebts = <dynamic>[];
          for (final d in supplierDebtsRaw) {
            final id = d.id?.toString();
            if (id == null) continue;
            if (seenIds.add(id)) supplierDebts.add(d);
          }

          final safeSelected = (_selectedSupplierId != null && seenIds.contains(_selectedSupplierId))
              ? _selectedSupplierId
              : null;
          
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: AppTheme.paddingXL,
              right: AppTheme.paddingXL,
              top: AppTheme.paddingXL,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Добавить платеж', style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.paddingMD),
                  
                  DropdownButtonFormField<String>(
                    initialValue: safeSelected,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Фирма',
                      prefixIcon: const Icon(Icons.business_rounded, color: AppTheme.primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                    ),
                    items: supplierDebts.map((debt) {
                      return DropdownMenuItem(
                        value: debt.id?.toString(),
                        // В выпадающем списке можно показать детали, но выбранное значение
                        // должно быть компактным, иначе DropdownButton ловит overflow.
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                debt.supplierName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${debt.remainingAmount.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    selectedItemBuilder: (context) {
                      // Выбранный элемент — строго 1 строка (без overflow)
                      return supplierDebts.map((debt) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            debt.supplierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList();
                    },
                    onChanged: (value) {
                      setState(() {
                        _selectedSupplierId = value;
                      });
                    },
                  ),

                  if (safeSelected != null) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final id = int.tryParse(safeSelected);
                        if (id == null) return const SizedBox.shrink();
                        final debt = debtProvider.supplierDebts.firstWhere(
                          (d) => d.id == id,
                          orElse: () => debtProvider.supplierDebts.first,
                        );
                        return Text(
                          'Остаток: ${debt.remainingAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        );
                      },
                    ),
                  ],
                  
                  if (safeSelected != null) ...[
                    const SizedBox(height: AppTheme.paddingMD),
                    Consumer<DebtProvider>(
                      builder: (context, debtProvider, child) {
                        final debtId = int.tryParse(safeSelected);
                        if (debtId == null) return const SizedBox.shrink();
                        
                        final debt = debtProvider.supplierDebts.firstWhere(
                          (d) => d.id == debtId,
                          orElse: () => debtProvider.supplierDebts.first,
                        );
                        
                        return AppCard(
                          padding: const EdgeInsets.all(AppTheme.paddingMD),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Общий долг:', style: Theme.of(context).textTheme.bodyMedium),
                                  Text(
                                    '${debt.totalDebt.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                    style: AppTheme.priceText,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Отдано:', style: Theme.of(context).textTheme.bodyMedium),
                                  Text(
                                    '${debt.paidAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.successColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Осталось:', style: Theme.of(context).textTheme.titleMedium),
                                  Text(
                                    '${debt.remainingAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                    style: AppTheme.priceText.copyWith(
                                      color: AppTheme.errorColor,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  
                  const SizedBox(height: AppTheme.paddingMD),
                  
                  AppTextField(
                    controller: _paymentController,
                    label: 'Сумма платежа',
                    prefixIcon: Icons.payment_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  
                  const SizedBox(height: AppTheme.paddingXL),
                  
                  GradientButton(
                    text: 'Добавить платеж',
                    onPressed: _addPayment,
                    icon: Icons.payment_rounded,
                    colors: const [AppTheme.successColor, Color(0xFF059669)],
                  ),
                  
                  const SizedBox(height: AppTheme.paddingMD),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: Consumer<DebtProvider>(
          builder: (context, debtProvider, child) {
            // Фильтруем долги с нулевым остатком
            final debts = debtProvider.supplierDebts.where((d) => d.remainingAmount > 0).toList();
            final totalDebts = debts.fold(0.0, (sum, debt) => sum + debt.totalDebt);
            final totalPaid = debts.fold(0.0, (sum, debt) => sum + debt.paidAmount);
            final totalRemaining = debts.fold(0.0, (sum, debt) => sum + debt.remainingAmount);
            final isLoading = debtProvider.isLoadingSupplierDebts;
            final pendingPayments = debtProvider.pendingDebtPaymentsCount;

            return Column(
              children: [
                ScreenHeader(
                  title: 'Долги перед фирмами',
                  subtitle: pendingPayments > 0
                      ? 'Осталось: ${totalRemaining.toStringAsFixed(2)} ${AppConstants.currencySymbol} • В очереди: $pendingPayments'
                      : 'Осталось: ${totalRemaining.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                  icon: Icons.business_rounded,
                  iconColor: AppTheme.errorColor,
                ),

                // Компактная статистика
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
                  child: Wrap(
                    spacing: AppTheme.paddingSM,
                    runSpacing: AppTheme.paddingSM,
                    children: [
                      _MiniStatChip(
                        icon: Icons.summarize_rounded,
                        label: 'Всего: ${totalDebts.toStringAsFixed(0)}',
                        color: AppTheme.errorColor,
                      ),
                      _MiniStatChip(
                        icon: Icons.check_circle_rounded,
                        label: 'Отдано: ${totalPaid.toStringAsFixed(0)}',
                        color: AppTheme.successColor,
                      ),
                      _MiniStatChip(
                        icon: Icons.payments_rounded,
                        label: 'Осталось: ${totalRemaining.toStringAsFixed(0)}',
                        color: AppTheme.warningColor,
                      ),
                      if (pendingPayments > 0)
                        _MiniStatChip(
                          icon: Icons.sync_rounded,
                          label: 'Очередь: $pendingPayments',
                          color: AppTheme.primaryColor,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.paddingMD),

                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (debtProvider.supplierDebtsError != null && debts.isEmpty)
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppTheme.paddingXL),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.error_outline_rounded,
                                        size: 48,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                    const SizedBox(height: AppTheme.paddingLG),
                                    Text(
                                      'Ошибка загрузки',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                    const SizedBox(height: AppTheme.paddingSM),
                                    Text(
                                      debtProvider.supplierDebtsError ?? 'Неизвестная ошибка',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppTheme.paddingLG),
                                    ElevatedButton.icon(
                                      onPressed: () => debtProvider.loadSupplierDebts(),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Повторить'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.errorColor,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : debts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.surfaceColor,
                                          AppTheme.surfaceColor.withOpacity(0.7),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.business_outlined,
                                      size: 64,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.paddingXL),
                                  Text('Нет долгов', style: Theme.of(context).textTheme.titleLarge),
                                  const SizedBox(height: AppTheme.paddingSM),
                                  Text(
                                    'Добавьте первую фирму',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                AppTheme.paddingXL,
                                0,
                                AppTheme.paddingXL,
                                110, // место под FAB, чтобы не перекрывал карточки
                              ),
                              itemCount: debts.length,
                              itemBuilder: (context, index) {
                                final debt = debts[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppTheme.paddingSM),
                                  child: _CompactSupplierCard(
                                    title: debt.supplierName,
                                    remaining: debt.remainingAmount,
                                    paid: debt.paidAmount,
                                    total: debt.totalDebt,
                                    color: AppTheme.errorColor,
                                    onPay: _showPaymentDialog,
                                  ),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
      // Убираем нижнюю кнопку "Оплатить" — она уже есть в карточках.
      // Оставляем одну компактную кнопку "Добавить фирму" и даём списку нижний отступ.
      floatingActionButton: FloatingActionButton(
        heroTag: 'add',
        onPressed: _showAddSupplierDebtDialog,
        backgroundColor: AppTheme.errorColor,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniStatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSupplierCard extends StatelessWidget {
  final String title;
  final double remaining;
  final double paid;
  final double total;
  final Color color;
  final VoidCallback onPay;

  const _CompactSupplierCard({
    required this.title,
    required this.remaining,
    required this.paid,
    required this.total,
    required this.color,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.paddingMD),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              borderRadius: BorderRadius.circular(8),
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${remaining.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppTheme.backgroundSecondary,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? AppTheme.successColor : AppTheme.warningColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Отдано: ${paid.toStringAsFixed(2)} • Всего: ${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.paddingSM),
          IconButton(
            onPressed: onPay,
            icon: const Icon(Icons.payment_rounded),
            color: AppTheme.successColor,
            tooltip: 'Оплатить',
          ),
        ],
      ),
    );
  }
}
