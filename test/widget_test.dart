import 'package:flutter_test/flutter_test.dart';

import 'package:pxlr/main.dart';

void main() {
  testWidgets('PXLR app loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PxlrApp());
    await tester.pump();

    expect(find.textContaining('PXLR'), findsWidgets);
  });
}
