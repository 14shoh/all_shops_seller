class UserModel {
  final int id;
  final String username;
  final String role;
  final String? fullName;
  final int? shopId;
  
  UserModel({
    required this.id,
    required this.username,
    required this.role,
    this.fullName,
    this.shopId,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      return UserModel(
        id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
        username: json['username']?.toString() ?? '',
        role: json['role']?.toString() ?? 'seller',
        fullName: json['fullName']?.toString(),
        shopId: json['shopId'] is int ? json['shopId'] as int? : (json['shopId'] != null ? int.tryParse(json['shopId'].toString()) : null),
      );
    } catch (e) {
      print('❌ Ошибка парсинга UserModel: $e');
      print('📦 JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'fullName': fullName,
      'shopId': shopId,
    };
  }
}
