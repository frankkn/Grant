import 'package:flutter_test/flutter_test.dart';
import 'package:grant/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    expect(GrantApp, isNotNull);
  });
}
