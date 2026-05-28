import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/operations_snapshot.dart';

final operationsApiServiceProvider = Provider<OperationsApiService>((ref) {
  return OperationsApiService(ref.watch(authApiClientProvider));
});

class OperationsApiService {
  OperationsApiService(this._dio);

  final Dio _dio;

  Future<OperationsSnapshot> fetchDashboard() async {
    try {
      final overviewFuture =
          _dio.get<Map<String, dynamic>>('/api/admin/analytics/overview');
      final systemHealthFuture =
          _dio.get<Map<String, dynamic>>('/api/admin/system-health');
      final activeSessionsFuture =
          _dio.get<Map<String, dynamic>>('/api/admin/active-sessions');
      final securityAlertsFuture =
          _dio.get<Map<String, dynamic>>('/api/admin/security-alerts');
      final logAlertsFuture = _dio.get<Map<String, dynamic>>('/api/alerts');
      final ymeAnalyticsFuture =
          _dio.get<Map<String, dynamic>>('/api/admin/yme/analytics');

      final overview = await overviewFuture;
      final systemHealth = await systemHealthFuture;
      final activeSessions = await activeSessionsFuture;
      final securityAlerts = await securityAlertsFuture;
      final logAlerts = await logAlertsFuture;
      final ymeAnalytics = await ymeAnalyticsFuture;

      return OperationsSnapshot(
        overview: AnalyticsOverview.fromJson(overview.data ?? const {}),
        systemHealth: SystemHealthSnapshot.fromJson(
          systemHealth.data ?? const {},
        ),
        activeSessions: SessionSummary.fromJson(
          activeSessions.data ?? const {},
        ),
        securityAlerts: SecurityAlertsSnapshot.fromJson(
          securityAlerts.data ?? const {},
        ),
        logAlerts: LogAlertsSnapshot.fromJson(logAlerts.data ?? const {}),
        ymeAnalytics: YmeAnalyticsSnapshot.fromJson(
          ymeAnalytics.data ?? const {},
        ),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  ApiException _mapError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'] ?? data['error'] ?? data['message'];
      if (detail is String && detail.isNotEmpty) {
        return ApiException(detail, statusCode: error.response?.statusCode);
      }
    }
    if (data is String && data.isNotEmpty) {
      return ApiException(data, statusCode: error.response?.statusCode);
    }
    return ApiException(
      error.message ?? 'Operations dashboard request failed.',
      statusCode: error.response?.statusCode,
    );
  }
}
