import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_calls_mobile/core/constants/app_config.dart';
import 'package:cloud_calls_mobile/core/utils/login_error_message.dart';

void main() {
  test('hasBackendConfigured is false for placeholder URL', () {
    expect(AppConfig.hasBackendConfigured, isFalse);
  });

  test('loginErrorMessage maps network errors', () {
    expect(
      loginErrorMessage(Exception('SocketException: Failed host lookup')),
      contains('Cannot reach the server'),
    );
  });

  test('loginErrorMessage maps StateError', () {
    expect(
      loginErrorMessage(StateError('FreePBX server IP or domain is required.')),
      'FreePBX server IP or domain is required.',
    );
  });
}
