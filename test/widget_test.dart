import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweets_app/app.dart';

void main() {
  testWidgets('SweetsApp builds', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SweetsApp()));
    await tester.pump();

    // In widget tests, there's no URL context, so the app shows the
    // "No merchant specified" fallback screen.
    expect(find.textContaining('No merchant specified'), findsOneWidget);
  });
}
