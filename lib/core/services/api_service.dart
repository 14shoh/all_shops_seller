import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../config/app_config.dart';

class ApiService {
  late Dio _dio;
  static final ApiService _instance = ApiService._internal();
  
  factory ApiService() => _instance;
  
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Handle unauthorized - logout user
        }
        return handler.next(error);
      },
    ));
  }
  
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      print('🌐 API GET Request:');
      print('   URL: ${_dio.options.baseUrl}$path');
      print('   Query: $queryParameters');
      final response = await _dio.get(path, queryParameters: queryParameters);
      print('✅ API GET Response:');
      print('   Status: ${response.statusCode}');
      print('   Data type: ${response.data.runtimeType}');
      return response;
    } catch (e) {
      print('❌ API GET Error:');
      if (e is DioException) {
        print('   Type: ${e.type}');
        print('   Message: ${e.message}');
        print('   Response: ${e.response?.data}');
        print('   Status Code: ${e.response?.statusCode}');
        print('   Request URL: ${e.requestOptions.uri}');
        print('   Request Headers: ${e.requestOptions.headers}');
      } else {
        print('   Error: $e');
      }
      rethrow;
    }
  }
  
  Future<Response> post(String path, {dynamic data}) async {
    try {
      print('🌐 API POST Request:');
      print('   URL: ${_dio.options.baseUrl}$path');
      print('   Data: $data');
      final response = await _dio.post(path, data: data);
      print('✅ API POST Response:');
      print('   Status: ${response.statusCode}');
      print('   Data: ${response.data}');
      return response;
    } catch (e) {
      print('❌ API POST Error:');
      if (e is DioException) {
        print('   Type: ${e.type}');
        print('   Message: ${e.message}');
        print('   Response: ${e.response?.data}');
        print('   Status Code: ${e.response?.statusCode}');
      } else {
        print('   Error: $e');
      }
      rethrow;
    }
  }
  
  Future<Response> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } catch (e) {
      rethrow;
    }
  }
  
  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } catch (e) {
      rethrow;
    }
  }

  
}

