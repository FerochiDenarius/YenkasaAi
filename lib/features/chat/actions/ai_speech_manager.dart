import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'ai_response_formatter.dart';

final aiSpeechManagerProvider = Provider<AiSpeechManager>((ref) {
  return AiSpeechManager();
});

final aiSpeechControllerProvider =
    StateNotifierProvider<AiSpeechController, AiSpeechState>((ref) {
  final controller = AiSpeechController(ref.watch(aiSpeechManagerProvider));
  controller.initialize();
  return controller;
});

class AiSpeechState {
  const AiSpeechState({
    this.isSpeaking = false,
    this.language = 'en-US',
    this.rate = 0.48,
    this.pitch = 1.0,
  });

  final bool isSpeaking;
  final String language;
  final double rate;
  final double pitch;

  AiSpeechState copyWith({
    bool? isSpeaking,
    String? language,
    double? rate,
    double? pitch,
  }) {
    return AiSpeechState(
      isSpeaking: isSpeaking ?? this.isSpeaking,
      language: language ?? this.language,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
    );
  }
}

class AiSpeechManager {
  AiSpeechManager() {
    _tts = FlutterTts();
  }

  late final FlutterTts _tts;

  Future<void> initialize({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => onStart?.call());
    _tts.setCompletionHandler(() => onComplete?.call());
    _tts.setCancelHandler(() => onComplete?.call());
    _tts.setErrorHandler((_) => onError?.call());
  }

  Future<void> speak(String markdown, {String language = 'en-US', double rate = 0.48}) async {
    final text = AiResponseFormatter.plainText(markdown);
    if (text.isEmpty) return;
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  Future<void> pause() => _tts.pause();
  Future<void> stop() => _tts.stop();
  Future<void> setLanguage(String language) => _tts.setLanguage(language);
  Future<void> setRate(double rate) => _tts.setSpeechRate(rate);
}

class AiSpeechController extends StateNotifier<AiSpeechState> {
  AiSpeechController(this._manager) : super(const AiSpeechState());

  final AiSpeechManager _manager;

  Future<void> initialize() async {
    await _manager.initialize(
      onStart: () => state = state.copyWith(isSpeaking: true),
      onComplete: () => state = state.copyWith(isSpeaking: false),
      onError: () => state = state.copyWith(isSpeaking: false),
    );
  }

  Future<void> speak(String markdown) async {
    await _manager.speak(markdown, language: state.language, rate: state.rate);
  }

  Future<void> pause() async {
    await _manager.pause();
    state = state.copyWith(isSpeaking: false);
  }

  Future<void> stop() async {
    await _manager.stop();
    state = state.copyWith(isSpeaking: false);
  }

  Future<void> setLanguage(String language) async {
    state = state.copyWith(language: language);
    await _manager.setLanguage(language);
  }

  Future<void> setRate(double rate) async {
    state = state.copyWith(rate: rate);
    await _manager.setRate(rate);
  }
}
