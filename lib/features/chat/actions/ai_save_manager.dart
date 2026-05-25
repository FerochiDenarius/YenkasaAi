import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_response_models.dart';
import 'ai_response_repository.dart';

final aiSaveManagerProvider = Provider<AiSaveManager>((ref) {
  return AiSaveManager(ref.watch(aiSavedResponsesControllerProvider.notifier));
});

class AiSaveManager {
  const AiSaveManager(this._controller);

  final AiSavedResponsesController _controller;

  Future<void> save(AiResponseSnapshot snapshot, {String note = ''}) {
    return _controller.saveResponse(snapshot, note: note);
  }

  Future<void> toggleFavorite(String responseId) {
    return _controller.toggleFavorite(responseId);
  }

  Future<void> togglePinned(String responseId) {
    return _controller.togglePinned(responseId);
  }
}
