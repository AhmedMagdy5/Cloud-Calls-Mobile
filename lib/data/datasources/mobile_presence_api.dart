import 'package:dio/dio.dart';

import '../../core/constants/app_config.dart';
import '../../core/services/backend_settings_service.dart';

/// Awfar CC mobile presence API (`mobile_presence.php`).
class MobilePresenceApi {
  MobilePresenceApi({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  static Dio _buildDio() {
    return Dio(BaseOptions(
      connectTimeout: AppConfig.apiTimeout,
      receiveTimeout: AppConfig.apiTimeout,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  String get _endpoint =>
      '${BackendSettingsService.instance.apiBaseUrl}/mobile_presence.php';

  Future<Map<String, dynamic>> register({
    required String extension,
    required String registrationSecret,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint,
      queryParameters: const {'action': 'register'},
      data: {
        'extension': extension,
        'registration_secret': registrationSecret,
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> sendStatus({
    required String extension,
    required String status,
    required String token,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint,
      queryParameters: const {'action': 'status'},
      data: {
        'extension': extension,
        'status': status,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> logout({
    required String token,
    String logoutType = 'manual',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint,
      queryParameters: const {'action': 'logout'},
      data: {'logout_type': logoutType},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }
}
