import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

String currentPlatformLabel() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

void logStartupDiagnostics() {
  developer.log(
    'startup platform=${currentPlatformLabel()} '
    'release=$kReleaseMode debug=$kDebugMode profile=$kProfileMode '
    'authApiBaseUrl=${AppConfig.authApiBaseUrl} '
    'aiApiBaseUrl=${AppConfig.aiApiBaseUrl} '
    'publicAiEngineBaseUrl=${AppConfig.publicAiEngineBaseUrl} '
    'yenkasaAppBackendBaseUrl=${AppConfig.yenkasaAppBackendBaseUrl} '
    'usesUnifiedAiBackend=${AppConfig.usesUnifiedAiBackend}',
    name: 'app_diagnostics',
  );
}

void logRequestDiagnostics({
  required String method,
  required String baseUrl,
  required String path,
  required bool hasToken,
  required int tokenLength,
}) {
  developer.log(
    'request platform=${currentPlatformLabel()} method=$method baseUrl=$baseUrl '
    'path=$path hasToken=$hasToken tokenLength=$tokenLength',
    name: 'network_diagnostics',
  );
}

void logResponseDiagnostics({
  required String method,
  required String baseUrl,
  required String path,
  required int? statusCode,
}) {
  developer.log(
    'response platform=${currentPlatformLabel()} method=$method baseUrl=$baseUrl '
    'path=$path statusCode=$statusCode',
    name: 'network_diagnostics',
  );
}

void logAuthDiagnostics({
  required String event,
  required bool hasToken,
  required int tokenLength,
  required String source,
}) {
  developer.log(
    'auth event=$event platform=${currentPlatformLabel()} '
    'hasToken=$hasToken tokenLength=$tokenLength source=$source',
    name: 'auth_diagnostics',
  );
}
