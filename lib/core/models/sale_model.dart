class SaleItemModel {
  final int? id;
  final int productId;
  final String productName;
  final int quantity; // для шт — кол-во, для кг — граммы, для л — мл
  final double salePrice;
  final double totalPrice;
  final String? size; // важно для магазинов одежды
  final String quantityUnit; // 'шт', 'кг', 'л'

  SaleItemModel({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.salePrice,
    required this.totalPrice,
    this.size,
    this.quantityUnit = 'шт',
  });

  double get displayQuantity {
    if (quantityUnit == 'кг') return quantity / 1000.0;
    if (quantityUnit == 'л') return quantity / 1000.0;
    return quantity.toDouble();
  }

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    // MySQL возвращает decimal как строки, нужно безопасное преобразование
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    return SaleItemModel(
      id: json['id'] != null ? (json['id'] is num ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0) : null,
      productId: parseInt(json['productId']),
      productName: json['product']?['name'] ?? json['productName'] ?? '',
      quantity: parseInt(json['quantity']),
      salePrice: parseDouble(json['salePrice']),
      totalPrice: parseDouble(json['totalPrice']),
      size: json['size'] as String?,
      quantityUnit: json['quantityUnit'] as String? ?? 'шт',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
      'salePrice': salePrice,
      'totalPrice': totalPrice, // отправляем готовый totalPrice для правильного расчёта на бэке
    };
  }
}

class SaleModel {
  final int? id;
  final double totalAmount;
  final int sellerId;
  final int shopId;
  final List<SaleItemModel> items;
  final DateTime? createdAt;

  SaleModel({
    this.id,
    required this.totalAmount,
    required this.sellerId,
    required this.shopId,
    required this.items,
    this.createdAt,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    // MySQL возвращает decimal как строки, нужно безопасное преобразование
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    return SaleModel(
      id: json['id'] != null ? (json['id'] is num ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0) : null,
      totalAmount: parseDouble(json['totalAmount']),
      sellerId: parseInt(json['sellerId']),
      shopId: parseInt(json['shopId']),
      items: (json['items'] as List?)
              ?.map((item) => SaleItemModel.fromJson(item))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : null,
    );
  }
}
