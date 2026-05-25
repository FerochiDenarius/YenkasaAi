import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_response_models.dart';

const _savedResponsesKey = 'yenkasa_ai_saved_responses_v1';

final aiSavedResponsesRepositoryProvider = Provider<AiSavedResponsesRepository>((ref) {
  return AiSavedResponsesRepository();
});

final aiSavedResponsesControllerProvider =
    StateNotifierProvider<AiSavedResponsesController, AsyncValue<List<AiSavedResponse>>>((ref) {
  final controller = AiSavedResponsesController(ref.watch(aiSavedResponsesRepositoryProvider));
  controller.load();
  return controller;
});

class AiSavedResponsesRepository {
  Future<List<AiSavedResponse>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedResponsesKey) ?? '[]';
    return decodeAiSavedResponses(raw);
  }

  Future<void> saveAll(List<AiSavedResponse> responses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedResponsesKey, encodeAiSavedResponses(responses));
  }
}

class AiSavedResponsesController extends StateNotifier<AsyncValue<List<AiSavedResponse>>> {
  AiSavedResponsesController(this._repository) : super(const AsyncLoading());

  final AiSavedResponsesRepository _repository;

  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.loadAll);
  }

  Future<void> saveResponse(AiResponseSnapshot snapshot, {String note = ''}) async {
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
