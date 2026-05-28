enum AiThemePreset { darkAi, midnight, neonPurple, enterpriseBlue }

extension AiThemePresetX on AiThemePreset {
  String get storageKey => switch (this) {
    AiThemePreset.darkAi => 'dark_ai',
    AiThemePreset.midnight => 'midnight',
    AiThemePreset.neonPurple => 'neon_purple',
    AiThemePreset.enterpriseBlue => 'enterprise_blue',
  };

  String get label => switch (this) {
    AiThemePreset.darkAi => 'Dark AI',
    AiThemePreset.midnight => 'Midnight',
    AiThemePreset.neonPurple => 'Neon Purple',
    AiThemePreset.enterpriseBlue => 'Enterprise Blue',
  };

  String get description => switch (this) {
    AiThemePreset.darkAi => 'Default control-plane palette with violet focus.',
    AiThemePreset.midnight => 'Lower-contrast deep navy workspace surfaces.',
    AiThemePreset.neonPurple =>
      'Sharper purple glow with brighter edge lighting.',
    AiThemePreset.enterpriseBlue =>
      'Blue-led enterprise runtime and observability tone.',
  };

  static AiThemePreset fromStorageKey(String value) {
    return AiThemePreset.values.firstWhere(
      (preset) => preset.storageKey == value,
      orElse: () => AiThemePreset.darkAi,
    );
  }
}
