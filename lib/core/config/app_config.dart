class AppConfig {
  static const String appName = 'YenkasaAi';
  static const String _productionServerBaseUrl =
      'https://yenkasa-ai-backend-496173204476.europe-west1.run.app';
  static const String _productionAiApiBaseUrl =
      _productionServerBaseUrl;
  static const String localDebugServerBaseUrl = 'http://127.0.0.1:8008';
  static const String localDebugAiApiBaseUrl =
      localDebugServerBaseUrl;
  static const String aiApiBaseUrl = String.fromEnvironment(
    'YENKASA_AI_API_BASE_URL',
    defaultValue: _productionAiApiBaseUrl,
  );
  static const String authApiBaseUrl = String.fromEnvironment(
    'YENKASA_AUTH_API_BASE_URL',
    defaultValue: _productionServerBaseUrl,
  );
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 90);
  static const Duration healthPollInterval = Duration(seconds: 20);
  static const String defaultAudience = 'public';
  static const String logoAsset = String.fromEnvironment(
    'YENKASA_AI_LOGO_ASSET',
    defaultValue: 'assets/branding/yenkasa_ai_logo.png',
  );
}
