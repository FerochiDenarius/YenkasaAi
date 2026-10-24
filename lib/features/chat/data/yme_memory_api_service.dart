import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/yme_memory_models.dart';

final ymeMemoryApiServiceProvider = Provider<YmeMemoryApiService>((ref) {
  return YmeMemoryApiService(ref.watch(apiClientProvider));
});

class YmeMemoryApiService {
  YmeMemoryApiService(this._dio);

  final Dio _dio;

  Future<List<YmeMemoryItem>> fetchMemories({int limit = 50}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/yme/memories',
        queryParameters: {'limit': limit},
      );
      final rawItems = response.data?['memories'] as List? ?? const [];
      return rawItems
          .whereType<Map>()
          .map((item) => YmeMemoryItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<YmeMemorySearchResult> searchMemories({
    required String query,
    int limit = 12,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/yme/search',
        queryParameters: {'q': query, 'limit': limit},
      );
      return YmeMemorySearchResult.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<void> deleteMemory(String memoryId) async {
    try {
      await _dio.delete<void>('/api/yme/memory/$memoryId');
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  ApiException _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return ApiException(
        'YenkasaAI backend is unreachable at ${AppConfig.aiApiBaseUrl}.',
        statusCode: error.response?.statusCode,
      );
    }
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'] ?? data['error'];
      if (detail is String && detail.isNotEmpty) {
        return ApiException(detail, statusCode: error.response?.statusCode);
      }
    }
    if (data is String && data.isNotEmpty) {
      return ApiException(data, statusCode: error.response?.statusCode);
    }
    return ApiException(
      error.message ?? 'YenkasaAI memory request failed.',
      statusCode: error.response?.statusCode,
    );
  }
}
