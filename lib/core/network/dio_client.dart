import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/app_config.dart';
import '../services/storage_service.dart';

class DioClient {
  DioClient._();
  static Dio? _instance;

  static Dio get instance => _instance ??= _build();

  static void reset() {
    _instance?.close(force: true);
    _instance = null;
  }

  static Dio _build() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.apiTimeout,
      receiveTimeout: AppConfig.apiTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opt, h) async {
        final token = await StorageService.getSecure(StorageKeys.authToken);
        if (token != null) opt.headers['Authorization'] = 'Bearer $token';
        h.next(opt);
      },
      onError: (e, h) => h.next(e),
    ));
    if (kDebugMode && AppConfig.hasBackendConfigured) {
      dio.interceptors.add(
        PrettyDioLogger(requestBody: true, responseBody: true, error: true),
      );
    }
    return dio;
  }
}
