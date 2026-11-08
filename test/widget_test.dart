// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_compost_system/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CompostWiseApp());
  });
}
