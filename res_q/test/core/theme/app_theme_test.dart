import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/core/theme/app_colors.dart';
import 'package:res_q/core/theme/app_theme.dart';

void main() {
  group('AppColors', () {
    test('uses the ResQ semantic emergency-response palette', () {
      expect(AppColors.primary, const Color(0xFF1565C0));
      expect(AppColors.primaryDark, const Color(0xFF0D47A1));
      expect(AppColors.emergency, const Color(0xFFD32F2F));
      expect(AppColors.warning, const Color(0xFFF57C00));
      expect(AppColors.success, const Color(0xFF2E7D32));
      expect(AppColors.information, const Color(0xFF0288D1));
    });
  });

  group('AppTheme', () {
    test('light theme assigns colors by their intended roles', () {
      final theme = AppTheme.light;

      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.information);
      expect(theme.colorScheme.tertiary, AppColors.warning);
      expect(theme.colorScheme.error, AppColors.emergency);
      expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
      expect(theme.appBarTheme.backgroundColor, AppColors.primaryDark);
      expect(
        theme.floatingActionButtonTheme.backgroundColor,
        AppColors.emergency,
      );
    });

    test('dark theme keeps readable content on brand actions', () {
      final theme = AppTheme.dark;

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.onPrimary, Colors.white);
      expect(theme.appBarTheme.foregroundColor, Colors.white);
    });
  });
}
