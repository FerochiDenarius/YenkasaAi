import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yenkasa_ai_flutter/app/yenkasa_ai_app.dart';

void main() {
  testWidgets('renders YenkasaAI get started entry', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: YenkasaAiApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I have an account'), findsOneWidget);
  });
}
