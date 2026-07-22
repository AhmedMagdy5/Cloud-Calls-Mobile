import '../constants/app_config.dart';
import '../network/dio_client.dart';
import 'storage_service.dart';

/// Runtime backend / webphone integration settings (saved on device).
class BackendSettingsService {
  BackendSettingsService._();
  static final instance = BackendSettingsService._();

  static const _placeholderHosts = {'your-freepbx-domain.com', 'your-freepbx-domain'};

  String get apiBaseUrl {
    final stored = StorageService.getString(StorageKeys.apiBaseUrl);
    if (stored != null && stored.trim().isNotEmpty) {
      return _normalizeBaseUrl(stored);
    }
    return _normalizeBaseUrl(AppConfig.defaultApiBaseUrl);
  }

  String get integrationCommandsPath {
    final stored = StorageService.getString(StorageKeys.integrationCommandsPath);
    if (stored != null && stored.trim().isNotEmpty) return _normalizePath(stored);
    return AppConfig.defaultIntegrationCommandsPath;
  }

  String get integrationSendPath {
    final stored = StorageService.getString(StorageKeys.integrationSendPath);
    if (stored != null && stored.trim().isNotEmpty) return _normalizePath(stored);
    return AppConfig.defaultIntegrationSendPath;
  }

  bool get isConfigured {
    final stored = StorageService.getString(StorageKeys.apiBaseUrl);
    if (stored != null && stored.trim().isNotEmpty) {
      return !_isPlaceholderUrl(stored);
    }
    return !_isPlaceholderUrl(AppConfig.defaultApiBaseUrl);
  }

  String? get savedApiBaseUrl => StorageService.getString(StorageKeys.apiBaseUrl);

  String get registrationSecret =>
      StorageService.getString(StorageKeys.registrationSecret)?.trim() ?? '';

  /// True when API URL + registration secret are saved (mobile presence ready).
  bool get isPresenceConfigured => isConfigured && registrationSecret.isNotEmpty;

  Future<void> save({
    required String apiBaseUrl,
    String? registrationSecret,
    String? integrationCommandsPath,
    String? integrationSendPath,
  }) async {
    final normalized = _normalizeBaseUrl(apiBaseUrl);
    if (_isPlaceholderUrl(normalized)) {
      throw ArgumentError('Enter a valid API URL for your system.');
    }
    await StorageService.setString(StorageKeys.apiBaseUrl, normalized);
    if (registrationSecret != null && registrationSecret.trim().isNotEmpty) {
      await StorageService.setString(
        StorageKeys.registrationSecret,
        registrationSecret.trim(),
      );
    } else {
      await StorageService.remove(StorageKeys.registrationSecret);
    }
    if (integrationCommandsPath != null && integrationCommandsPath.trim().isNotEmpty) {
      await StorageService.setString(
        StorageKeys.integrationCommandsPath,
        _normalizePath(integrationCommandsPath),
      );
    } else {
      await StorageService.remove(StorageKeys.integrationCommandsPath);
    }
    if (integrationSendPath != null && integrationSendPath.trim().isNotEmpty) {
      await StorageService.setString(
        StorageKeys.integrationSendPath,
        _normalizePath(integrationSendPath),
      );
    } else {
      await StorageService.remove(StorageKeys.integrationSendPath);
    }
    DioClient.reset();
  }

  Future<void> clear() async {
    await StorageService.remove(StorageKeys.apiBaseUrl);
    await StorageService.remove(StorageKeys.registrationSecret);
    await StorageService.remove(StorageKeys.integrationCommandsPath);
    await StorageService.remove(StorageKeys.integrationSendPath);
    await StorageService.deleteSecure(StorageKeys.presenceToken);
    DioClient.reset();
  }

  bool _isPlaceholderUrl(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.isEmpty) return true;
    return _placeholderHosts.any(lower.contains);
  }

  String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    url = url.replaceAll(RegExp(r'/+$'), '');
    return url;
  }

  String _normalizePath(String raw) {
    var path = raw.trim();
    if (path.isEmpty) return path;
    if (!path.startsWith('/')) path = '/$path';
    return path.replaceAll(RegExp(r'/+$'), '');
  }
}
