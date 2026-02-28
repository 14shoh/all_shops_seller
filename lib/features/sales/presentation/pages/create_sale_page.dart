import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart' show MobileScanner, Barcode;
import 'package:intl/intl.dart';
import '../../../../core/providers/sale_provider.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../payment/presentation/pages/payment_page.dart';

class CreateSalePage extends StatefulWidget {
  const CreateSalePage({super.key});

  @override
  State<CreateSalePage> createState() => _CreateSalePageState();
}

class _CreateSalePageState extends State<CreateSalePage> {
  bool _showBarcodeScanner = false;
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _barcodeInputController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _barcodeInputController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    setState(() {
      _showBarcodeScanner = true;
    });
  }

  Future<void> _searchProductByBarcode() async {
    final barcode = _barcodeInputController.text.trim();
    if (barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите штрихкод'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _onBarcodeDetected(barcode);
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    setState(() {
      _showBarcodeScanner = false;
    });

    final productProvider = context.read<ProductProvider>();
    final isClothingShop = productProvider.isClothingShop;

    if (isClothingShop) {
      // Для магазинов одежды получаем все товары с этим штрихкодом
      final products = await productProvider.findAllProductsByBarcode(barcode);
      
      if (products.isNotEmpty && mounted) {
        _barcodeInputController.clear();
        _showSizeSelectionDialog(products, barcode);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товар не найден'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Для других магазинов используем старую логику
      final product = await productProvider.findProductByBarcode(barcode);

      if (product != null && mounted) {
        // Очищаем поле ввода штрихкода после успешного поиска
        _barcodeInputController.clear();
        _showAddProductDialog(product);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товар не найден'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showSizeSelectionDialog(List<ProductModel> products, String barcode) {
    // Вычисляем общее количество и количество по размерам
    final totalQuantity = products.fold<int>(0, (sum, p) => sum + p.quantity);
    final sizeMap = <String, int>{};
    for (final product in products) {
      if (product.size != null) {
        sizeMap[product.size!] = (sizeMap[product.size!] ?? 0) + product.quantity;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.straighten_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    products.isNotEmpty ? products.first.name : 'Товар',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Штрихкод: $barcode',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Общее количество
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Всего на складе:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$totalQuantity шт.',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Список размеров
            const Text(
              'Доступные размеры:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            ...sizeMap.entries.map((entry) {
              final size = entry.key;
              final quantity = entry.value;
              final product = products.firstWhere((p) => p.size == size);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: quantity > 0 ? Colors.green : Colors.red,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: quantity > 0 ? () {
                      Navigator.pop(context);
                      _showAddProductDialog(product);
                    } : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  size,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Остаток: $quantity шт.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: quantity > 0 ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  Text(
                                    'Цена: ${product.purchasePrice.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Icon(
                            quantity > 0 ? Icons.arrow_forward_ios_rounded : Icons.block_rounded,
                            color: quantity > 0 ? const Color(0xFF8B5CF6) : Colors.red,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Отмена',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(ProductModel product) {
    _priceController.clear();
    _quantityController.text = product.isSoldByKg || product.isSoldByLiters ? '1' : '1';

    final unit = product.unitType;
    final priceLabel = unit == 'кг' ? 'Цена за кг' : (unit == 'л' ? 'Цена за л' : 'Цена продажи');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.barcode != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Штрихкод: ${product.barcode}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: product.quantity > 0 
                    ? (product.quantity < 10 
                        ? Colors.orange.withOpacity(0.1) 
                        : Colors.green.withOpacity(0.1))
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: product.quantity > 0 
                      ? (product.quantity < 10 
                          ? Colors.orange 
                          : Colors.green)
                      : Colors.red,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    product.quantity > 0 
                        ? (product.quantity < 10 
                            ? Icons.warning_amber_rounded 
                            : Icons.check_circle)
                        : Icons.error_outline,
                    color: product.quantity > 0 
                        ? (product.quantity < 10 
                            ? Colors.orange 
                            : Colors.green)
                        : Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Остаток на складе',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${product.displayQuantity.toStringAsFixed(product.isSoldByPieces ? 0 : 2)} $unit',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: product.quantity > 0 
                                ? (product.quantity < 10 
                                    ? Colors.orange 
                                    : Colors.green)
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: 'Количество ($unit)',
                border: const OutlineInputBorder(),
                hintText: product.isSoldByPieces ? '1' : '0.5',
              ),
              keyboardType: product.isSoldByPieces 
                  ? TextInputType.number 
                  : const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: priceLabel,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(_priceController.text);
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Введите корректную цену'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              int quantityInt;
              if (product.isSoldByKg || product.isSoldByLiters) {
                final inputText = _quantityController.text.trim().replaceAll(',', '.');
                final val = double.tryParse(inputText);
                if (val == null || val <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Введите корректное количество ($unit)'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                quantityInt = val.round(); // quantity в кг/л
              } else {
                quantityInt = int.tryParse(_quantityController.text) ?? 1;
                if (quantityInt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Введите корректное количество'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }

              if (product.quantity < quantityInt) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Недостаточно товара. Доступно: ${product.displayQuantity.toStringAsFixed(product.isSoldByPieces ? 0 : 2)} $unit'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              context.read<SaleProvider>().addItemToSale(
                    product,
                    quantityInt,
                    price,
                  );
              Navigator.pop(context);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSale() async {
    final saleProvider = context.read<SaleProvider>();
    final items = saleProvider.currentSaleItems;
    final totalAmount = saleProvider.totalAmount;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте товары в чек'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Открываем экран оплаты
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentPage(
            totalAmount: totalAmount,
            onComplete: () => _finalizeSale(),
          ),
        ),
      );
    }
  }

  Future<void> _finalizeSale() async {
    final saleProvider = context.read<SaleProvider>();
    
    final success = await saleProvider.createSale();

    if (success && mounted) {
      final message = saleProvider.lastOperationMessage ?? 'Продажа сохранена';
      final isOfflineSaved = saleProvider.lastSaleSavedOffline;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isOfflineSaved ? Colors.orange : Colors.green,
        ),
      );
      // Возвращаемся на экран оплаты, затем на экран продажи
      if (mounted) {
        Navigator.pop(context); // Закрываем экран оплаты
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saleProvider.error ?? 'Ошибка создания продажи'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showClearConfirmation(SaleProvider saleProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Очистить чек?'),
        content: const Text('Все добавленные товары будут удалены из текущей продажи.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              saleProvider.clearSale();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    try {
      return DateFormat('EEEE, d MMMM', 'ru').format(DateTime.now());
    } catch (e) {
      final now = DateTime.now();
      final months = ['Января', 'Февраля', 'Марта', 'Апреля', 'Мая', 'Июня',
        'Июля', 'Августа', 'Сентября', 'Октября', 'Ноября', 'Декабря'];
      final weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
      return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final saleProvider = context.watch<SaleProvider>();
    final items = saleProvider.currentSaleItems;

    if (_showBarcodeScanner) {
      return WillPopScope(
        onWillPop: () async {
          setState(() {
            _showBarcodeScanner = false;
          });
          return false; // Предотвращаем стандартное поведение
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Сканирование штрихкода'),
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _onBarcodeDetected(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // На главном экране блокируем выход назад
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundPrimary,
        body: Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundPrimary,
          ),
          // Внутри `MainScreen` уже есть нижняя навигация и системный inset учтён.
          // Чтобы избежать "BOTTOM OVERFLOWED" на устройствах с нав. кнопками,
          // отключаем bottom SafeArea здесь.
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Единый Header
                ScreenHeader(
                  title: 'Новая продажа',
                  subtitle: _getFormattedDate(),
                  icon: Icons.shopping_bag_rounded,
                  iconColor: AppTheme.successColor,
                  actions: items.isNotEmpty
                      ? [
                          GestureDetector(
                            onTap: () => _showClearConfirmation(saleProvider),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                              ),
                              child: const Icon(
                                Icons.delete_sweep_rounded,
                                size: 22,
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ),
                        ]
                      : null,
                ),
                // Поле для ввода штрихкода
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingLG),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _barcodeInputController,
                          label: 'Штрихкод',
                          hint: 'Введите штрихкод вручную',
                          prefixIcon: Icons.qr_code_rounded,
                          suffixIcon: _barcodeInputController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: AppTheme.textTertiary, size: 20),
                                  onPressed: () {
                                    _barcodeInputController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          keyboardType: TextInputType.number,
                          onChanged: (value) => setState(() {}),
                          onSubmitted: (value) => _searchProductByBarcode(),
                        ),
                      ),
                      const SizedBox(width: AppTheme.paddingSM),
                      GestureDetector(
                        onTap: _searchProductByBarcode,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.successColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: AppTheme.paddingXS),
                      GestureDetector(
                        onTap: _scanBarcode,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.paddingMD),
                // Список товаров в чеке
                Expanded(
                  child: items.isEmpty
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
                                  Icons.shopping_cart_outlined,
                                  size: 64,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              const SizedBox(height: AppTheme.paddingXL),
                              Text('Чек пуст', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: AppTheme.paddingXS),
                              Text(
                                'Отсканируйте штрихкод товара',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingLG),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return AppCard(
                              padding: const EdgeInsets.all(AppTheme.paddingMD),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppTheme.warningColor, AppTheme.errorColor],
                                      ),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.paddingMD),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: AppTheme.cardTitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.displayQuantity.toStringAsFixed(item.quantityUnit == 'шт' ? 0 : 2)} ${item.quantityUnit} × ${item.salePrice.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item.totalPrice.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                        style: AppTheme.priceText.copyWith(fontSize: 16),
                                      ),
                                      const SizedBox(height: AppTheme.paddingXS),
                                      GestureDetector(
                                        onTap: () => saleProvider.removeItemFromSale(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.delete_rounded,
                                            size: 18,
                                            color: AppTheme.errorColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                // Итоговая панель
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingLG),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Итого:', style: Theme.of(context).textTheme.titleLarge),
                          Text(
                            '${saleProvider.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                            style: AppTheme.priceText.copyWith(fontSize: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.paddingMD),
                      GradientButton(
                        text: 'Оформить продажу',
                        onPressed: items.isEmpty || saleProvider.isLoading ? null : _completeSale,
                        isLoading: saleProvider.isLoading,
                        colors: const [AppTheme.successColor, Color(0xFF059669)],
                        icon: Icons.check_circle_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
