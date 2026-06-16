import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextron_ai/app.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NextronApp(),
      ),
    );
    // Just verify the widget builds - app does async init that takes time
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MaterialApp), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
