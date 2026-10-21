import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:res_q/core/theme/app_colors.dart';
import 'package:res_q/core/theme/app_theme.dart';

void main() {
  testWidgets('แอปเริ่มต้นด้วยธีมหลักของ ResQ', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: Text('ResQ'))),
      ),
    );

    final context = tester.element(find.text('ResQ'));

    expect(find.text('ResQ'), findsOneWidget);
    expect(Theme.of(context).colorScheme.primary, AppColors.primary);
  });
}
