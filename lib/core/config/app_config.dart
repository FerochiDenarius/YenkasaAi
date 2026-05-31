class AppConfig {
  static const String appName = 'YenkasaAi';
  static const String _productionAiBackendBaseUrl =
      'https://yenkasa-ai-backend-496173204476.europe-west1.run.app';
  static const String _productionYenkasaAppBackendBaseUrl =
      'https://yenkasa-8rjea.ondigitalocean.app';
  static const String _productionAuthServerBaseUrl =
      _productionYenkasaAppBackendBaseUrl;
  static const String _legacyAuthServerBaseUrl = _productionAiBackendBaseUrl;
  static const String _productionAiApiBaseUrl = _productionAiBackendBaseUrl;
  static const String _productionPublicAiEngineBaseUrl =
      _productionAiBackendBaseUrl;
  static const String localDebugServerBaseUrl = 'http://127.0.0.1:8008';
  static const String localDebugAuthServerBaseUrl = localDebugServerBaseUrl;
  static const String localLegacyAuthServerBaseUrl = localDebugServerBaseUrl;
  static const String localPublicAiEngineBaseUrl = localDebugServerBaseUrl;
  static const String localDebugAiApiBaseUrl = localDebugServerBaseUrl;
  static const String aiApiBaseUrl = String.fromEnvironment(
    'YENKASA_AI_API_BASE_URL',
    defaultValue: _productionAiApiBaseUrl,
  );
  static const String authApiBaseUrl = String.fromEnvironment(
    'YENKASA_AUTH_API_BASE_URL',
    defaultValue: _productionAuthServerBaseUrl,
  );
  static const String legacyAuthApiBaseUrl = String.fromEnvironment(
    'YENKASA_LEGACY_AUTH_API_BASE_URL',
    defaultValue: _legacyAuthServerBaseUrl,
  );
  static const String publicAiEngineBaseUrl = String.fromEnvironment(
    'YENKASA_PUBLIC_AI_ENGINE_BASE_URL',
    defaultValue: _productionPublicAiEngineBaseUrl,
  );
  static const String yenkasaAppBackendBaseUrl = String.fromEnvironment(
    'YENKASA_APP_BACKEND_BASE_URL',
    defaultValue: _productionYenkasaAppBackendBaseUrl,
  );
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 90);
  static const Duration healthPollInterval = Duration(seconds: 20);
  static const String defaultAudience = 'public';
  static const String logoAsset = String.fromEnvironment(
    'YENKASA_AI_LOGO_ASSET',
    defaultValue: 'assets/branding/yenkasa_ai_logo.png',
  );

  static bool get usesUnifiedAiBackend =>
      authApiBaseUrl.trim() == aiApiBaseUrl.trim() &&
      aiApiBaseUrl.trim() == publicAiEngineBaseUrl.trim();

  static String get canonicalAuthBackendBaseUrl => authApiBaseUrl.trim();
  static String get canonicalAiBackendBaseUrl => aiApiBaseUrl.trim();
}
