import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/constants/app_constants.dart';

class PaymentPage extends StatefulWidget {
  final double totalAmount;
  final VoidCallback onComplete;

  const PaymentPage({
    super.key,
    required this.totalAmount,
    required this.onComplete,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final TextEditingController _cashReceivedController = TextEditingController();
  double _cashReceived = 0.0;
  double _change = 0.0;
  String? _accountNumber;

  @override
  void initState() {
    super.initState();
    _loadAccountNumber();
  }

  Future<void> _loadAccountNumber() async {
    final accountNumber = await StorageService.getString('payment_account_number');
    setState(() {
      // Используем номер из локального хранилища (загружен при входе)
      // Если номер не установлен, используем дефолтный
      _accountNumber = (accountNumber != null && accountNumber.isNotEmpty) 
          ? accountNumber 
          : '9762000121115488'; // Default
    });
  }

  @override
  void dispose() {
    _cashReceivedController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    setState(() {
      _change = _cashReceived - widget.totalAmount;
      if (_change < 0) _change = 0.0;
    });
  }

  String _generatePaymentUrl() {
    final accountNumber = _accountNumber ?? '9762000121115488';
    final amount = widget.totalAmount.toInt();
    return 'http://pay.expresspay.tj/?A=$accountNumber&s=$amount&c=&f1=133&FIELD2=&FIELD3=';
  }

  void _showCompleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Text('Завершить заказ?', style: Theme.of(context).textTheme.titleLarge),
        content: Text(
          'Вы уверены, что хотите завершить заказ на сумму ${widget.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: Theme.of(context).textTheme.labelLarge),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Завершить', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentUrl = _generatePaymentUrl();

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Оплата заказа',
              subtitle: 'Итоговая сумма: ${widget.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
              icon: Icons.payment_rounded,
              iconColor: AppTheme.successColor,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.paddingXL),
                child: Column(
                  children: [
                    // Итоговая сумма
                    AppCard(
                      padding: const EdgeInsets.all(AppTheme.paddingLG),
                      child: Column(
                        children: [
                          Text(
                            'К оплате',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppTheme.paddingXS),
                          Text(
                            '${widget.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                            style: AppTheme.priceText.copyWith(fontSize: 36),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.paddingXL),

                    // Оплата наличными
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

                    if (_cashReceived > 0) ...[
                      const SizedBox(height: AppTheme.paddingMD),
                      AppCard(
                        padding: const EdgeInsets.all(AppTheme.paddingMD),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Сдача:', style: Theme.of(context).textTheme.titleLarge),
                            Text(
                              '${_change.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                              style: AppTheme.priceText.copyWith(
                                fontSize: 24,
                                color: _change > 0 ? AppTheme.successColor : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
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

                    const SizedBox(height: AppTheme.paddingXL),

                    // QR код для оплаты
                    SectionHeader(title: 'Сканировать QR для оплаты'),
                    const SizedBox(height: AppTheme.paddingMD),

                    AppCard(
                      padding: const EdgeInsets.all(AppTheme.paddingLG),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.paddingMD),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            ),
                            child: QrImageView(
                              data: paymentUrl,
                              version: QrVersions.auto,
                              size: 200.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppTheme.paddingMD),
                          Text(
                            'Сумма: ${widget.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppTheme.paddingXS),
                          Text(
                            'Душанбе Сити',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Кнопка завершить заказ
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingXL),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: GradientButton(
                text: 'Завершить заказ',
                onPressed: _showCompleteConfirmation,
                icon: Icons.check_circle_rounded,
                colors: const [AppTheme.successColor, Color(0xFF059669)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
