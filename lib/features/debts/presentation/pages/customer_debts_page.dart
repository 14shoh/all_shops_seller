import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/providers/debt_provider.dart';
import '../../../../core/constants/app_constants.dart';

class CustomerDebtsPage extends StatefulWidget {
  const CustomerDebtsPage({super.key});

  @override
  State<CustomerDebtsPage> createState() => _CustomerDebtsPageState();
}

class _CustomerDebtsPageState extends State<CustomerDebtsPage> {
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Загружаем долги при открытии страницы
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtProvider>().loadCustomerDebts();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _paymentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> _filterDebts(List<dynamic> debts) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return debts;

    String digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');
    final qDigits = digitsOnly(q);

    return debts.where((d) {
      final name = (d.customerName as String).toLowerCase();
      final phone = (d.phone?.toString() ?? '').toLowerCase();
      final phoneDigits = digitsOnly(phone);

      final matchName = name.contains(q);
      final matchPhone = qDigits.isEmpty ? phone.contains(q) : phoneDigits.contains(qDigits);
      return matchName || matchPhone;
    }).toList();
  }

  Future<void> _addDebt() async {
    if (_nameController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните имя и сумму долга')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму')),
      );
      return;
    }

    Navigator.pop(context);

    final debtProvider = context.read<DebtProvider>();
    final success = await debtProvider.createCustomerDebt(
      customerName: _nameController.text,
      phone: _phoneController.text.isEmpty ? null : _phoneController.text.trim(),
      amount: amount,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      debtDate: _selectedDate,
    );

    if (success) {
      _nameController.clear();
      _phoneController.clear();
      _amountController.clear();
      _descriptionController.clear();
      _selectedDate = DateTime.now();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Долг успешно добавлен')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(debtProvider.customerDebtsError ?? 'Ошибка добавления долга'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _addPayment(int debtId, double currentRemainingAmount) async {
    if (_paymentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите сумму платежа')),
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

    if (payment > currentRemainingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сумма платежа не может превышать остаток долга')),
      );
      return;
    }

    Navigator.pop(context);

    final debtProvider = context.read<DebtProvider>();
    final success = await debtProvider.addPaymentToCustomerDebt(debtId, payment);

    if (success) {
      _paymentController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(debtProvider.lastOperationMessage ?? 'Платеж успешно добавлен')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(debtProvider.customerDebtsError ?? 'Ошибка добавления платежа'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showAddDebtDialog() {
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
                  Text('Добавить долг', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.paddingMD),
              
              AppTextField(
                controller: _nameController,
                label: 'Имя клиента',
                prefixIcon: Icons.person_rounded,
              ),
              
              const SizedBox(height: AppTheme.paddingMD),
              
              AppTextField(
                controller: _phoneController,
                label: 'Номер телефона',
                prefixIcon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
              
              const SizedBox(height: AppTheme.paddingMD),
              
              AppTextField(
                controller: _amountController,
                label: 'Сумма долга',
                prefixIcon: Icons.attach_money_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              
              const SizedBox(height: AppTheme.paddingMD),
              
              AppTextField(
                controller: _descriptionController,
                label: 'За что (описание)',
                prefixIcon: Icons.description_rounded,
              ),
              
              const SizedBox(height: AppTheme.paddingMD),
              
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
                child: AppCard(
                  padding: const EdgeInsets.all(AppTheme.paddingMD),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Дата', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd.MM.yyyy').format(_selectedDate),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                      const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryColor),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: AppTheme.paddingXL),
              
              GradientButton(
                text: 'Добавить долг',
                onPressed: _addDebt,
                icon: Icons.add_rounded,
              ),
              
              const SizedBox(height: AppTheme.paddingMD),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog(int debtId, String customerName, double currentRemainingAmount) {
    _paymentController.clear();
    
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
                  Text('Добавить платеж', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.paddingMD),
              
              AppCard(
                padding: const EdgeInsets.all(AppTheme.paddingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Клиент: $customerName', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Остаток долга: ${currentRemainingAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                      style: AppTheme.priceText.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.paddingMD),
              
              AppTextField(
                controller: _paymentController,
                label: 'Сумма платежа',
                prefixIcon: Icons.payment_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              
              const SizedBox(height: AppTheme.paddingXL),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        ),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingMD),
                  Expanded(
                    flex: 2,
                    child: GradientButton(
                      text: 'Оплатить',
                      onPressed: () => _addPayment(debtId, currentRemainingAmount),
                      icon: Icons.check_rounded,
                      colors: const [AppTheme.successColor, Color(0xFF059669)],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppTheme.paddingMD),
            ],
          ),
        ),
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
            final debtsAll = debtProvider.customerDebts.where((d) => d.remainingAmount > 0).toList();
            final debts = _filterDebts(debtsAll);
            final totalDebts = debtsAll.fold(0.0, (sum, debt) => sum + debt.remainingAmount);
            final isLoading = debtProvider.isLoadingCustomerDebts;
            final pendingPayments = debtProvider.pendingDebtPaymentsCount;

            return Column(
              children: [
                ScreenHeader(
                  title: 'Долги клиентов',
                  subtitle: pendingPayments > 0
                      ? 'Всего: ${totalDebts.toStringAsFixed(2)} ${AppConstants.currencySymbol} • В очереди: $pendingPayments'
                      : 'Всего: ${totalDebts.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppTheme.warningColor,
                ),

                // Компактная статистика
                if (debtsAll.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
                    child: Wrap(
                      spacing: AppTheme.paddingSM,
                      runSpacing: AppTheme.paddingSM,
                      children: [
                        _MiniStatChip(
                          icon: Icons.summarize_rounded,
                          label: '${totalDebts.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                          color: AppTheme.warningColor,
                        ),
                        _MiniStatChip(
                          icon: Icons.people_alt_rounded,
                          label: '${debtsAll.length} клиентов',
                          color: AppTheme.primaryColor,
                        ),
                        if (pendingPayments > 0)
                          _MiniStatChip(
                            icon: Icons.sync_rounded,
                            label: 'Очередь: $pendingPayments',
                            color: AppTheme.successColor,
                          ),
                      ],
                    ),
                  ),

                // Поиск
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.paddingXL,
                    AppTheme.paddingMD,
                    AppTheme.paddingXL,
                    0,
                  ),
                  child: AppTextField(
                    controller: _searchController,
                    label: 'Поиск по имени или телефону',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (v) {
                      setState(() => _searchQuery = v);
                    },
                    suffixIcon: _searchQuery.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),

                const SizedBox(height: AppTheme.paddingMD),

                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (debtProvider.customerDebtsError != null && debts.isEmpty)
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
                                      debtProvider.customerDebtsError ?? 'Неизвестная ошибка',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppTheme.paddingLG),
                                    ElevatedButton.icon(
                                      onPressed: () => debtProvider.loadCustomerDebts(),
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
                      : debtsAll.isEmpty
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
                                      Icons.account_balance_wallet_outlined,
                                      size: 64,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.paddingXL),
                                  Text(
                                    'Нет долгов',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: AppTheme.paddingSM),
                                  Text(
                                    'Добавьте первый долг',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            )
                          : debts.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppTheme.paddingXL),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(22),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.search_off_rounded,
                                            size: 46,
                                            color: AppTheme.textTertiary,
                                          ),
                                        ),
                                        const SizedBox(height: AppTheme.paddingLG),
                                        Text(
                                          'Ничего не найдено',
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: AppTheme.paddingSM),
                                        Text(
                                          'Попробуйте другое имя или номер',
                                          style: Theme.of(context).textTheme.bodySmall,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
                              itemCount: debts.length,
                              itemBuilder: (context, index) {
                                final debt = debts[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppTheme.paddingSM),
                                  child: _CompactDebtCard(
                                    title: debt.customerName,
                                    extra: (debt.phone != null && debt.phone.toString().trim().isNotEmpty)
                                        ? debt.phone.toString().trim()
                                        : null,
                                    subtitle: DateFormat('dd.MM.yyyy').format(debt.debtDate),
                                    description: debt.description,
                                    remaining: debt.remainingAmount,
                                    paid: debt.paidAmount,
                                    color: AppTheme.warningColor,
                                    onPay: () => _showPaymentDialog(
                                      debt.id!,
                                      debt.customerName,
                                      debt.remainingAmount,
                                    ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDebtDialog,
        backgroundColor: AppTheme.warningColor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить долг'),
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

class _CompactDebtCard extends StatelessWidget {
  final String title;
  final String? extra;
  final String subtitle;
  final String? description;
  final double remaining;
  final double paid;
  final Color color;
  final VoidCallback onPay;

  const _CompactDebtCard({
    required this.title,
    this.extra,
    required this.subtitle,
    required this.description,
    required this.remaining,
    required this.paid,
    required this.color,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                    ),
                    if (extra != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.phone_rounded, size: 14, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          extra!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                    if (paid > 0) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.successColor),
                      const SizedBox(width: 4),
                      Text(
                        paid.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
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
