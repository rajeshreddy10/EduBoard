import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eduboard_mobile/main.dart';

void main() {
  testWidgets('EduBoard smoke test - launches and renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EduBoardApp(),
      ),
    );

    // Initial frame renders splash screen branding
    expect(find.text('EduBoard'), findsOneWidget);

    // Pump beyond the splash timer
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
  });
}
