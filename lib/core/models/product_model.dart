import '../constants/app_constants.dart';

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

  /// Единица измерения: шт, кг, л (по weight-маркеру 0.001/1/2)
  String get unitType {
    if (weight == null) return AppConstants.unitPieces;
    if (weight! >= 0.9 && weight! < 1.1) return AppConstants.unitKg;
    if (weight! >= 1.9 && weight! < 2.1) return AppConstants.unitLiters;
    return AppConstants.unitPieces; // старое или 0.001
  }

  bool get isSoldByKg => unitType == AppConstants.unitKg;
  bool get isSoldByLiters => unitType == AppConstants.unitLiters;
  bool get isSoldByPieces => unitType == AppConstants.unitPieces;

  /// Количество для отображения (quantity уже в кг/л/шт)
  double get displayQuantity {
    return quantity.toDouble();
  }

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
