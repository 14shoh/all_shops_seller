import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart' show MobileScanner, Barcode;
import '../../../../core/providers/product_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class ProductsListPage extends StatefulWidget {
  const ProductsListPage({super.key});

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends State<ProductsListPage> {
  final _searchController = TextEditingController();
  bool _showBarcodeScanner = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
    _searchController.addListener(() {
      context.read<ProductProvider>().searchProducts(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    setState(() {
      _showBarcodeScanner = true;
    });
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    setState(() {
      _showBarcodeScanner = false;
    });

    final productProvider = context.read<ProductProvider>();
    final product = await productProvider.findProductByBarcode(barcode);

    if (product != null && mounted) {
      _showEditProductDialog(product);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Товар не найден'), backgroundColor: Colors.orange),
      );
    }
  }

  void _showEditProductDialog(ProductModel product) {
    final priceController = TextEditingController(text: product.purchasePrice.toStringAsFixed(2));
    final quantityController = TextEditingController(text: product.quantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Редактировать: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: 'Закупочная цена (${AppConstants.currencySymbol})',
                prefixIcon: const Icon(Icons.attach_money),
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Количество',
                prefixIcon: Icon(Icons.inventory),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(priceController.text);
              final newQuantity = int.tryParse(quantityController.text);
              if (newPrice == null || newQuantity == null) return;

              final success = await context.read<ProductProvider>().updateProduct(
                product.id!,
                purchasePrice: newPrice,
                quantity: newQuantity,
              );

              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Товар успешно обновлен'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.products;
    final isLoading = productProvider.isLoading;

    if (_showBarcodeScanner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Сканирование штрихкода')),
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
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {}
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundPrimary,
        body: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Товары',
                subtitle: '${products.length} позиций на складе',
                icon: Icons.inventory_2_rounded,
                iconColor: AppTheme.primaryColor,
                actions: [
                  GestureDetector(
                    onTap: () => productProvider.loadProducts(),
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
                      child: const Icon(Icons.refresh_rounded, size: 22, color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingLG),
                child: Row(
                  children: [
                      Expanded(
                        child: AppTextField(
                          controller: _searchController,
                          label: 'Поиск',
                          hint: 'Поиск по названию или штрихкоду...',
                          prefixIcon: Icons.search_rounded,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: AppTheme.textTertiary, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: AppTheme.paddingSM),
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
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : products.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: () async => productProvider.loadProducts(),
                            child: ListView.builder(
                              itemCount: products.length,
                              padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingLG),
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: AppTheme.paddingSM),
                                child: _buildProductCard(products[index]),
                              ),
                            ),
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
            decoration: const BoxDecoration(color: AppTheme.surfaceColor, shape: BoxShape.circle),
            child: Icon(
              _searchController.text.isNotEmpty ? Icons.search_off_rounded : Icons.inventory_2_outlined,
              size: 64,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: AppTheme.paddingXL),
          Text(
            _searchController.text.isNotEmpty ? 'Товары не найдены' : 'Нет товаров',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final quantityColor = product.quantity < 10 ? AppTheme.errorColor : AppTheme.successColor;
    final quantityBgColor = product.quantity < 10 ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5);
    
    return AppCard(
      onTap: () => _showEditProductDialog(product),
      padding: const EdgeInsets.all(AppTheme.paddingMD),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Center(
              child: Text(
                product.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTheme.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.purchasePrice.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                  style: AppTheme.priceText.copyWith(fontSize: 14, color: AppTheme.primaryColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingSM, vertical: 6),
                decoration: BoxDecoration(
                  color: quantityBgColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  '${product.quantity} шт.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: quantityColor),
                ),
              ),
              const SizedBox(height: AppTheme.paddingXS),
              const Icon(Icons.edit_rounded, size: 18, color: AppTheme.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}
