import 'package:flutter_test/flutter_test.dart';
import 'package:yenkasa_ai_flutter/core/config/app_config.dart';

void main() {
  test('defaults local builds away from the production backend', () {
    expect(AppConfig.environment, 'development');
    expect(AppConfig.isProduction, isFalse);
    expect(AppConfig.aiApiBaseUrl, AppConfig.localDebugAiApiBaseUrl);
    expect(AppConfig.authApiBaseUrl, AppConfig.localDebugAuthServerBaseUrl);
    expect(AppConfig.allowInsecureAuthFallback, isFalse);
  });
}
