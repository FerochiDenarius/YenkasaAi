import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenkasa_ai_flutter/features/ingestion/presentation/ingestion_page.dart';
import 'package:yenkasa_ai_flutter/navigation/app_navigation.dart';

void main() {
  test('ingestion route is registered in navigation metadata', () {
    expect(canonicalRoute('/ingestion'), '/ingestion');
    expect(routeTitle('/ingestion'), 'Ingestion');
    expect(canonicalRoute('/saved-responses'), '/saved-responses');
    expect(routeTitle('/saved-responses'), 'Saved Chats');
    expect(canonicalRoute('/memory'), '/memory');
    expect(routeTitle('/memory'), 'Memory');
    expect(
      primaryDestinations.any(
        (destination) => destination.route == '/ingestion',
      ),
      isTrue,
    );
  });

  testWidgets('ingestion page exposes PDF selection action', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: IngestionPage())),
      ),
    );

    expect(find.text('Knowledge ingestion control surface'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.text('Select PDF files'), findsOneWidget);
  });
}
