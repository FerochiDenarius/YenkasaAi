import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_theme_preset.dart';

final aiThemePresetProvider =
    StateNotifierProvider<AiThemeController, AiThemePreset>((ref) {
      final controller = AiThemeController();
      controller.load();
      return controller;
    });

class AiThemeController extends StateNotifier<AiThemePreset> {
  AiThemeController() : super(AiThemePreset.darkAi);

  static const _storageKey = 'yenkasa_ai.theme_preset';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved == null || saved.isEmpty) return;
    state = AiThemePresetX.fromStorageKey(saved);
  }

  Future<void> select(AiThemePreset preset) async {
    if (state == preset) return;
    state = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, preset.storageKey);
  }
}
