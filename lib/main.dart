import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/yenkasa_ai_app.dart';
import 'core/diagnostics/app_diagnostics.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  logStartupDiagnostics();
  runApp(const ProviderScope(child: YenkasaAiApp()));
}
