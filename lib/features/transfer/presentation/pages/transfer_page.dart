import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cashReceivedController = TextEditingController();
  
  double _amount = 0.0;
  String _phoneNumber = '';
  double _cashReceived = 0.0;
  double _change = 0.0;

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    setState(() {
      _change = _cashReceived - _amount;
      if (_change < 0) _change = 0.0;
    });
  }

  void _clearAll() {
    setState(() {
      _amountController.clear();
      _phoneController.clear();
      _cashReceivedController.clear();
      _amount = 0.0;
      _phoneNumber = '';
      _cashReceived = 0.0;
      _change = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Перевод',
              subtitle: 'Калькулятор перевода и сдачи',
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppTheme.secondaryColor,
              actions: [
                if (_amount > 0 || _phoneNumber.isNotEmpty || _cashReceived > 0)
                  GestureDetector(
                    onTap: _clearAll,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: const Icon(Icons.clear_all_rounded, size: 22, color: AppTheme.errorColor),
                    ),
                  ),
              ],
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.paddingXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(title: 'Информация о переводе'),
                    const SizedBox(height: AppTheme.paddingMD),
                    
                    AppTextField(
                      controller: _amountController,
                      label: 'Сумма перевода',
                      prefixIcon: Icons.attach_money_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          _amount = double.tryParse(value) ?? 0.0;
                        });
                        _calculateChange();
                      },
                    ),

                    const SizedBox(height: AppTheme.paddingMD),

                    AppTextField(
                      controller: _phoneController,
                      label: 'Номер телефона',
                      prefixIcon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        setState(() {
                          _phoneNumber = value;
                        });
                      },
                    ),

                    const SizedBox(height: AppTheme.paddingXL),

                    SectionHeader(title: 'Оплата наличными'),
                    const SizedBox(height: AppTheme.paddingMD),

                    AppTextField(
                      controller: _cashReceivedController,
                      label: 'Получено наличными',
                      prefixIcon: Icons.money_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          _cashReceived = double.tryParse(value) ?? 0.0;
                        });
                        _calculateChange();
                      },
                    ),

                    if (_amount > 0 && _cashReceived > 0) ...[
                      const SizedBox(height: AppTheme.paddingXL),
                      AppCard(
                        padding: const EdgeInsets.all(AppTheme.paddingLG),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Сумма:', style: Theme.of(context).textTheme.titleMedium),
                                Text(
                                  '${_amount.toStringAsFixed(2)} ₽',
                                  style: AppTheme.priceText.copyWith(fontSize: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.paddingMD),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Получено:', style: Theme.of(context).textTheme.titleMedium),
                                Text(
                                  '${_cashReceived.toStringAsFixed(2)} ₽',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.successColor,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: AppTheme.paddingXL),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Сдача:', style: Theme.of(context).textTheme.titleLarge),
                                Text(
                                  '${_change.toStringAsFixed(2)} ₽',
                                  style: AppTheme.priceText.copyWith(
                                    fontSize: 24,
                                    color: _change > 0 ? AppTheme.successColor : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            if (_change < 0)
                              Padding(
                                padding: const EdgeInsets.only(top: AppTheme.paddingSM),
                                child: Text(
                                  'Недостаточно средств!',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.errorColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    if (_amount > 0 && _phoneNumber.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.paddingXL),
                      AppCard(
                        padding: const EdgeInsets.all(AppTheme.paddingMD),
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: AppTheme.paddingSM),
                            Expanded(
                              child: Text(
                                'Перевод на ${_phoneNumber} на сумму ${_amount.toStringAsFixed(2)} ₽',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
