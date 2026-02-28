import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart' show MobileScanner, Barcode;
import '../../../../core/providers/product_provider.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _sizeController = TextEditingController();
  final _weightController = TextEditingController();
  
  String? _selectedSize;
  String _sizeType = 'letter'; // letter, numeric, shoes
  Map<String, int> _sizeQuantities = {}; // Размер -> Количество
  bool _showBarcodeScanner = false;
  int? _shopId;
  String _productUnit = 'pieces'; // pieces, kg, liters (для grocery/general)

  List<String> _getAvailableSizes() {
    switch (_sizeType) {
      case 'letter':
        return AppConstants.clothingSizes;
      case 'numeric':
        return AppConstants.numericSizes;
      case 'shoes':
        return AppConstants.shoeSizes;
      default:
        return AppConstants.clothingSizes;
    }
  }

  Widget _buildSizeTypeButton(String label, String type) {
    final isSelected = _sizeType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sizeType = type;
          _selectedSize = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitButton(String label, String unit, IconData icon) {
    final isSelected = _productUnit == unit;
    return GestureDetector(
      onTap: () => setState(() => _productUnit = unit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadShopId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadShopInfo();
    });
  }

  Future<void> _loadShopId() async {
    final shopId = await StorageService().getShopId();
    setState(() {
      _shopId = shopId;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _sizeController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    setState(() {
      _showBarcodeScanner = true;
    });
  }

  void _onBarcodeDetected(String barcode) {
    setState(() {
      _barcodeController.text = barcode;
      _showBarcodeScanner = false;
    });
    
    // Попытка найти товар по штрихкоду
    context.read<ProductProvider>().findProductByBarcode(barcode).then((product) {
      if (product != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товар с таким штрихкодом уже существует'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  void _clearForm() {
    if (!mounted) return;
    _formKey.currentState?.reset();
    _nameController.clear();
    _barcodeController.clear();
    _categoryController.clear();
    _priceController.clear();
    _quantityController.clear();
    _sizeController.clear();
    _weightController.clear();
    setState(() {
      _selectedSize = null;
      _sizeQuantities = {};
    });
  }

  String _getQuantityLabel() {
    switch (_productUnit) {
      case 'kg': return 'Количество (кг)';
      case 'liters': return 'Количество (л)';
      default: return 'Количество (шт)';
    }
  }

  void _addSizeQuantity() {
    if (_selectedSize == null || _selectedSize!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите размер'), backgroundColor: Colors.orange),
      );
      return;
    }

    final quantityText = _sizeController.text.trim();
    if (quantityText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите количество'), backgroundColor: Colors.orange),
      );
      return;
    }

    final quantity = int.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректное количество'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _sizeQuantities[_selectedSize!] = quantity;
      _selectedSize = null;
      _sizeController.clear();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Магазин не назначен'), backgroundColor: Colors.red),
      );
      return;
    }

    final productProvider = context.read<ProductProvider>();
    final shop = productProvider.shop;

    // Валидация для одежды/обуви
    if (shop?.type == AppConstants.shopTypeClothing && _sizeQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы один размер'), backgroundColor: Colors.red),
      );
      return;
    }

    final price = double.parse(_priceController.text);

    if (shop?.type == AppConstants.shopTypeClothing && _sizeQuantities.isNotEmpty) {
      bool allSuccess = true;
      int successCount = 0;

      for (final entry in _sizeQuantities.entries) {
        final product = ProductModel(
          name: _nameController.text.trim(),
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
          category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
          purchasePrice: price,
          quantity: entry.value,
          size: entry.key,
          shopId: _shopId!,
        );

        final success = await productProvider.addProduct(product);
        if (success) {
          successCount++;
        } else {
          allSuccess = false;
        }
      }

      if (mounted) {
        if (allSuccess) {
          _clearForm();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Успешно добавлено товаров: $successCount'), backgroundColor: Colors.green),
          );
        }
      }
    } else {
      int qty;
      double? weightMarker;
      if (_productUnit == 'kg') {
        final kg = double.tryParse(_quantityController.text);
        if (kg == null || kg <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Введите корректное количество (кг)'), backgroundColor: Colors.red),
          );
          return;
        }
        qty = (kg * 1000).round(); // храним в граммах
        weightMarker = AppConstants.weightMarkerKg;
      } else if (_productUnit == 'liters') {
        final liters = double.tryParse(_quantityController.text);
        if (liters == null || liters <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Введите корректное количество (л)'), backgroundColor: Colors.red),
          );
          return;
        }
        qty = (liters * 1000).round(); // храним в мл
        weightMarker = AppConstants.weightMarkerLiters;
      } else {
        final pcs = int.tryParse(_quantityController.text);
        if (pcs == null || pcs <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Введите корректное количество'), backgroundColor: Colors.red),
          );
          return;
        }
        qty = pcs;
        weightMarker = AppConstants.weightMarkerPieces; // для grocery бэкенд требует weight
      }

      final product = ProductModel(
        name: _nameController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        purchasePrice: price,
        quantity: qty,
        weight: (shop?.type == AppConstants.shopTypeGrocery) ? weightMarker : (_productUnit == 'pieces' ? null : weightMarker),
        shopId: _shopId!,
      );

      final success = await productProvider.addProduct(product);
      if (success && mounted) {
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Товар успешно добавлен'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final shop = productProvider.shop;

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

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Новый товар',
              subtitle: 'Добавление позиции в базу',
              icon: Icons.add_box_rounded,
              iconColor: AppTheme.primaryColor,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(title: 'Основная информация'),
                      const SizedBox(height: AppTheme.paddingMD),
                      AppTextField(
                        controller: _nameController,
                        label: 'Название товара',
                        prefixIcon: Icons.inventory_rounded,
                        validator: (value) => value == null || value.isEmpty ? 'Введите название' : null,
                      ),
                      const SizedBox(height: AppTheme.paddingMD),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _barcodeController,
                              label: 'Штрихкод',
                              prefixIcon: Icons.qr_code_rounded,
                            ),
                          ),
                          const SizedBox(width: AppTheme.paddingSM),
                          GestureDetector(
                            onTap: _scanBarcode,
                            child: Container(
                              height: 56,
                              width: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                border: Border.all(color: AppTheme.borderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.paddingMD),
                      AppTextField(
                        controller: _categoryController,
                        label: 'Категория',
                        prefixIcon: Icons.category_rounded,
                      ),
                      const SizedBox(height: AppTheme.paddingXL),
                      SectionHeader(title: 'Цена и наличие'),
                      const SizedBox(height: AppTheme.paddingMD),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _priceController,
                              label: 'Цена закупки',
                              prefixIcon: Icons.attach_money_rounded,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) => value == null || value.isEmpty ? 'Введите цену' : null,
                            ),
                          ),
                          const SizedBox(width: AppTheme.paddingMD),
                          if (shop?.type != AppConstants.shopTypeClothing)
                            Expanded(
                              child: AppTextField(
                                controller: _quantityController,
                                label: _getQuantityLabel(),
                                prefixIcon: Icons.numbers_rounded,
                                keyboardType: _productUnit == 'pieces'
                                    ? TextInputType.number
                                    : const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) => value == null || value.isEmpty ? 'Введите кол-во' : null,
                              ),
                            ),
                        ],
                      ),
                      if (shop?.type == AppConstants.shopTypeGrocery || shop?.type == AppConstants.shopTypeGeneral) ...[
                        if (shop?.type != AppConstants.shopTypeClothing) ...[
                          const SizedBox(height: AppTheme.paddingMD),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Единица измерения:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildUnitButton('Штуки', 'pieces', Icons.inventory_2_rounded),
                                      const SizedBox(width: 8),
                                      _buildUnitButton('Килограммы', 'kg', Icons.scale_rounded),
                                      const SizedBox(width: 8),
                                      _buildUnitButton('Литры', 'liters', Icons.water_drop_rounded),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      if (shop?.type == AppConstants.shopTypeClothing) ...[
                        const SizedBox(height: AppTheme.paddingXL),
                        SectionHeader(title: 'Размеры и количество'),
                        const SizedBox(height: AppTheme.paddingMD),
                        
                        // Выбор категории размеров
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Выберите тип размера:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildSizeTypeButton('Буквенные', 'letter'),
                                    const SizedBox(width: 8),
                                    _buildSizeTypeButton('Цифровые', 'numeric'),
                                    const SizedBox(width: 8),
                                    _buildSizeTypeButton('Обувь', 'shoes'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.paddingMD),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                  border: Border.all(color: AppTheme.borderColor),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedSize,
                                    hint: Text(
                                      'Размер',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    isExpanded: true,
                                    items: _getAvailableSizes().map((size) {
                                      return DropdownMenuItem(
                                        value: size,
                                        child: Text(
                                          size,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedSize = val),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.paddingSM),
                            Expanded(
                              child: AppTextField(
                                controller: _sizeController,
                                label: 'Кол-во',
                                prefixIcon: Icons.numbers_rounded,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppTheme.paddingSM),
                            GestureDetector(
                              onTap: _addSizeQuantity,
                              child: Container(
                                height: 56,
                                width: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.add_rounded, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.paddingMD),
                        if (_sizeQuantities.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _sizeQuantities.entries.map((entry) {
                                  return Chip(
                                    backgroundColor: const Color(0xFFEEF2FF),
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    label: Text(
                                      '${entry.key}: ${entry.value} шт.',
                                      style: const TextStyle(
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    onDeleted: () => setState(() => _sizeQuantities.remove(entry.key)),
                                    deleteIconColor: const Color(0xFF6366F1),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],

                      const SizedBox(height: 40),
                      
                      GradientButton(
                        text: 'Сохранить товар',
                        onPressed: productProvider.isLoading ? null : _submitForm,
                        isLoading: productProvider.isLoading,
                        icon: Icons.save_rounded,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
