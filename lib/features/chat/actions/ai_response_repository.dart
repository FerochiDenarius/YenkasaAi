import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import 'ai_response_models.dart';

const _legacySavedResponsesKey = 'yenkasa_ai_saved_responses_v1';

final aiSavedResponsesRepositoryProvider = Provider<AiSavedResponsesRepository>(
  (ref) {
    final userId = ref.watch(currentAuthUserIdProvider);
    return AiSavedResponsesRepository(userId: userId);
  },
);

final aiSavedResponsesControllerProvider =
    StateNotifierProvider<
      AiSavedResponsesController,
      AsyncValue<List<AiSavedResponse>>
    >((ref) {
      final controller = AiSavedResponsesController(
        ref.watch(aiSavedResponsesRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class AiSavedResponsesRepository {
  AiSavedResponsesRepository({required String? userId})
    : _userId = _normalizeUserId(userId);

  final String _userId;

  Future<List<AiSavedResponse>> loadAll() async {
    if (_userId.isEmpty) {
      return const [];
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? '[]';
    return decodeAiSavedResponses(raw);
  }

  Future<void> saveAll(List<AiSavedResponse> responses) async {
    if (_userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, encodeAiSavedResponses(responses));
  }

  String get _storageKey => '$_legacySavedResponsesKey.$_userId';

  static String _normalizeUserId(String? userId) {
    return (userId ?? '').trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }
}

class AiSavedResponsesController
    extends StateNotifier<AsyncValue<List<AiSavedResponse>>> {
  AiSavedResponsesController(this._repository) : super(const AsyncLoading());

  final AiSavedResponsesRepository _repository;

  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.loadAll);
  }

  Future<void> saveResponse(
    AiResponseSnapshot snapshot, {
    String note = '',
  }) async {
    final current = await _current();
    final next = [
      AiSavedResponse(
        id: snapshot.responseId,
        snapshot: snapshot,
        createdAt: DateTime.now(),
        note: note,
      ),
      ...current.where((item) => item.id != snapshot.responseId),
    ];
    await _repository.saveAll(next);
    state = AsyncData(next);
  }

  Future<void> toggleFavorite(String responseId) async {
    final current = await _current();
    final next = current
        .map(
          (item) => item.id == responseId
              ? item.copyWith(isFavorite: !item.isFavorite)
              : item,
        )
        .toList();
    await _repository.saveAll(next);
    state = AsyncData(next);
  }

  Future<void> togglePinned(String responseId) async {
    final current = await _current();
    final next = current
        .map(
          (item) => item.id == responseId
              ? item.copyWith(isPinned: !item.isPinned)
              : item,
        )
        .toList();
    await _repository.saveAll(next);
    state = AsyncData(next);
  }

  Future<void> deleteResponse(String responseId) async {
    final current = await _current();
    final next = current.where((item) => item.id != responseId).toList();
    await _repository.saveAll(next);
    state = AsyncData(next);
  }

  Future<List<AiSavedResponse>> _current() async {
    final current = state.valueOrNull;
    if (current != null) return current;
    final loaded = await _repository.loadAll();
    state = AsyncData(loaded);
    return loaded;
  }
}
