import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/features/emergency_info/controllers/emergency_info_form_controller.dart';
import 'package:res_q/features/emergency_info/widgets/emergency_info_form.dart';

void main() {
  testWidgets('disables blood group selection when editing is not allowed', (
    tester,
  ) async {
    final controller = EmergencyInfoFormController()..bloodGroup = 'O+';
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmergencyInfoForm(
            formKey: GlobalKey<FormState>(),
            controller: controller,
            isSaving: false,
            onSave: () {},
            onBloodGroupChanged: (_) {},
            submitLabel: 'บันทึก',
            bloodGroupEditable: false,
          ),
        ),
      ),
    );

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );

    expect(dropdown.onChanged, isNull);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('allows blood group selection during initial setup', (
    tester,
  ) async {
    final controller = EmergencyInfoFormController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmergencyInfoForm(
            formKey: GlobalKey<FormState>(),
            controller: controller,
            isSaving: false,
            onSave: () {},
            onBloodGroupChanged: (_) {},
            submitLabel: 'บันทึก',
          ),
        ),
      ),
    );

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );

    expect(dropdown.onChanged, isNotNull);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
  });
}
