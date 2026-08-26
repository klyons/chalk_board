import 'package:flutter_test/flutter_test.dart';
import 'package:chalk_board/main.dart';

void main() {
  testWidgets('ChalkBoardApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChalkBoardApp());
    expect(find.text('ChalkBoard'), findsOneWidget);
    expect(find.text('Create New Board'), findsOneWidget);
  });
}
