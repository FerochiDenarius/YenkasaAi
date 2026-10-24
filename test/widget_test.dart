import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:yenkasa_ai_flutter/features/auth/presentation/pages/get_started_page.dart';

void main() {
  testWidgets('renders YenkasaAI get started entry', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GetStartedPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I have an account'), findsOneWidget);
  });
}
