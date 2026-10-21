import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/shared/widgets/success_alert_dialog.dart';

void main() {
  testWidgets('keeps a white surface and green icon in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SuccessAlertDialog(
            title: 'สำเร็จ',
            message: 'ดำเนินการเรียบร้อยแล้ว',
            onConfirm: () {},
          ),
        ),
      ),
    );

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, Colors.white);
    expect(dialog.surfaceTintColor, Colors.transparent);

    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
    expect(icon.color, const Color(0xFF16A34A));

    final title = tester.widget<Text>(find.text('สำเร็จ'));
    expect(title.style?.color, const Color(0xFF111827));
  });
}
