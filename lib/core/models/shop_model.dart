class ShopModel {
  final int id;
  final String name;
  final String type;
  final bool isActive;

  ShopModel({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    return ShopModel(
      id: parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'grocery',
      isActive: json['isActive'] == true || json['isActive'] == 1 || json['isActive'] == '1',
    );
  }
}
