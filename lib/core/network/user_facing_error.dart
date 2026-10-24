import 'api_exception.dart';

String presentUserFacingError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is ApiException) {
    final statusCode = error.statusCode;
    final message = error.message.trim();

    if (statusCode == 401 || statusCode == 403) {
      return 'Session expired. Please login again.';
    }
    if (_looksLikeSecureConnectionError(message)) {
      return 'Unable to connect securely to YenkasaAi.';
    }
    if (_looksLikeReachabilityError(message)) {
      return 'Unable to reach YenkasaAi right now.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'YenkasaAi is temporarily unavailable. Please try again.';
    }
    if (message.isNotEmpty) {
      return message;
    }
  }

  final raw = error.toString().trim();
  if (_looksLikeSecureConnectionError(raw)) {
    return 'Unable to connect securely to YenkasaAi.';
  }
  if (_looksLikeReachabilityError(raw)) {
    return 'Unable to reach YenkasaAi right now.';
  }
  return fallback;
}

bool _looksLikeSecureConnectionError(String value) {
  final lowered = value.toLowerCase();
  return lowered.contains('certificate') ||
      lowered.contains('handshake') ||
      lowered.contains('ssl') ||
      lowered.contains('tls');
}

bool _looksLikeReachabilityError(String value) {
  final lowered = value.toLowerCase();
  return lowered.contains('timeout') ||
      lowered.contains('connection error') ||
      lowered.contains('unreachable') ||
      lowered.contains('socketexception') ||
      lowered.contains('failed host lookup');
}
