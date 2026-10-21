import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/features/emergency_info/controllers/emergency_info_form_controller.dart';
import 'package:res_q/features/emergency_info/widgets/emergency_info_validation_popup.dart';

void main() {
  group('EmergencyInfoFormController validation focus', () {
    late EmergencyInfoFormController controller;

    setUp(() {
      controller = EmergencyInfoFormController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('selects the first invalid field in screen order', () {
      final issue = controller.firstValidationIssue();

      expect(issue, isNotNull);
      expect(issue!.message, 'กรุณากรอกชื่อ-นามสกุล');
      expect(issue.focusNode, same(controller.fullNameFocusNode));
    });

    test('selects emergency contact phone when it duplicates victim phone', () {
      controller.fullName.text = 'สมชาย';
      controller.bloodGroup = 'O+';
      controller.phoneNumber.text = '0812345678';
      controller.emergencyContactName.text = 'สมหญิง';
      controller.emergencyContactPhone.text = '0812345678';

      final issue = controller.firstValidationIssue();

      expect(issue, isNotNull);
      expect(
        issue!.message,
        'เบอร์ผู้ติดต่อฉุกเฉินต้องไม่ซ้ำกับเบอร์ของผู้ประสบภัย',
      );
      expect(issue.focusNode, same(controller.emergencyContactPhoneFocusNode));
    });

    test('returns no issue when every required field is valid', () {
      controller.fullName.text = 'สมชาย';
      controller.bloodGroup = 'O+';
      controller.phoneNumber.text = '0812345678';
      controller.emergencyContactName.text = 'สมหญิง';
      controller.emergencyContactPhone.text = '0912345678';

      expect(controller.firstValidationIssue(), isNull);
    });

    testWidgets('shows popup above the page then focuses the invalid field', (
      tester,
    ) async {
      late BuildContext pageContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                pageContext = context;

                return ListView(
                  children: [
                    SizedBox(
                      key: controller.fullNameFieldKey,
                      child: TextField(focusNode: controller.fullNameFocusNode),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      final validation = controller.validateAndFocusFirstError(pageContext);

      await tester.pump();

      expect(find.byKey(EmergencyInfoValidationPopup.popupKey), findsOneWidget);
      expect(controller.fullNameFocusNode.hasFocus, isFalse);

      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump(const Duration(milliseconds: 300));
      await validation;

      expect(find.byKey(EmergencyInfoValidationPopup.popupKey), findsNothing);
      expect(controller.fullNameFocusNode.hasFocus, isTrue);
    });
  });
}
