import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fluxzy_connect/main.dart';

void main() {
  testWidgets('Fluxzy Connect page loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FluxzyApp()));

    expect(find.text('Fluxzy Connect'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);

    // Allow pending timers to complete before test ends
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
