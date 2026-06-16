import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('test harness renders a basic widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Academy Hub'),
        ),
      ),
    );

    expect(find.text('Academy Hub'), findsOneWidget);
  });
}
