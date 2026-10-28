import 'package:flutter_test/flutter_test.dart';
import 'package:digilens/main.dart';

void main() {
  testWidgets('DigiLens app smoke test', (WidgetTester tester) async {
    // Build DigiLens app and trigger a frame.
    await tester.pumpWidget(const DigiLensApp());

    // Verify app title is present
    expect(find.text('DigiLens'), findsOneWidget);

    // Verify DEMO badge is visible
    expect(find.text('DEMO'), findsOneWidget);

    // Verify Quick Scan section exists
    expect(find.text('Quick Scan'), findsOneWidget);

    // Verify quick action buttons
    expect(find.text('Link'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('QR Code'), findsOneWidget);

    // Verify recent activity section
    expect(find.text('Today'), findsOneWidget);
  });
}
