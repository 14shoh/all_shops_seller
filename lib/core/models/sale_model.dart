class SaleItemModel {
  final int? id;
  final int productId;
  final String productName;
  final int quantity;
  final double salePrice;
  final double totalPrice;
  final String? size; // важно для магазинов одежды

  SaleItemModel({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.salePrice,
    required this.totalPrice,
    this.size,
  });

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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
      'salePrice': salePrice,
      if (size != null) 'size': size,
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
