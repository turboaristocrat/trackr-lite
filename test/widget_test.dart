import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackr_lite/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('TrackrLiteApp smoke test: loads header and navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const TrackrLiteApp());
    await tester.pumpAndSettle();

    expect(find.text('TRACKR'), findsOneWidget);
    expect(find.text('LITE'), findsOneWidget);
    expect(find.text('Active Shift'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });
}
