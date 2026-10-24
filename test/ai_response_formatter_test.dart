import 'package:flutter_test/flutter_test.dart';
import 'package:yenkasa_ai_flutter/features/chat/actions/ai_response_formatter.dart';

void main() {
  group('AiResponseFormatter.forDisplay', () {
    test('turns consecutive repository paths into a spaced bullet list', () {
      const answer = '''
Yenkasa chat files:
lib/features/chat/presentation/chat_page.dart
lib/features/chat/presentation/chat_controller.dart
backend/app/api/chat_routes.py
''';

      final formatted = AiResponseFormatter.forDisplay(answer);

      expect(formatted, contains('- `lib/features/chat/presentation/chat_page.dart`'));
      expect(
        formatted,
        contains('- `lib/features/chat/presentation/chat_controller.dart`'),
      );
      expect(formatted, contains('- `backend/app/api/chat_routes.py`'));
      expect(formatted, contains('Yenkasa chat files:\n\n- `'));
    });

    test('does not rewrite paths inside fenced code blocks', () {
      const answer = '''
```text
lib/first.dart
lib/second.dart
```
''';

      expect(AiResponseFormatter.forDisplay(answer), answer.trim());
    });
  });
}
