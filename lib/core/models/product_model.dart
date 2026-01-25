class ProductModel {
  final int? id;
  final String name;
  final String? barcode;
  final String? category;
  final double purchasePrice;
  final int quantity;
  final String? size;
  final double? weight;
  final int shopId;

  ProductModel({
    this.id,
    required this.name,
    this.barcode,
    this.category,
    required this.purchasePrice,
    required this.quantity,
    this.size,
    this.weight,
    required this.shopId,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
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
    
    return ProductModel(
      id: json['id'] != null ? (json['id'] is num ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0) : null,
      name: json['name'] as String? ?? '',
      barcode: json['barcode'] as String?,
      category: json['category'] as String?,
      purchasePrice: parseDouble(json['purchasePrice']),
      quantity: parseInt(json['quantity']),
      size: json['size'] as String?,
      weight: json['weight'] != null ? parseDouble(json['weight']) : null,
      shopId: parseInt(json['shopId']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (barcode != null) 'barcode': barcode,
      if (category != null) 'category': category,
      'purchasePrice': purchasePrice,
      'quantity': quantity,
      if (size != null) 'size': size,
      if (weight != null) 'weight': weight,
      'shopId': shopId,
    };
  }
}
