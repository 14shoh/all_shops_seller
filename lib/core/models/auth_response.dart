import 'user_model.dart';

class AuthResponse {
  final String accessToken;
  final UserModel user;
  
  AuthResponse({
    required this.accessToken,
    required this.user,
  });
  
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    try {
      // Поддержка обоих форматов: access_token и accessToken
      final token = json['access_token'] ?? json['accessToken'];
      if (token == null) {
        throw Exception('Токен не найден в ответе: ${json.keys}');
      }
      
      if (json['user'] == null) {
        throw Exception('Данные пользователя не найдены в ответе: ${json.keys}');
      }
      
      return AuthResponse(
        accessToken: token.toString(),
        user: UserModel.fromJson(json['user']),
      );
    } catch (e) {
      print('❌ Ошибка парсинга AuthResponse: $e');
      print('📦 JSON: $json');
      rethrow;
    }
  }
}
