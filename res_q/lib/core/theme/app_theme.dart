import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.lightPrimaryContainer,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.information,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.lightInformationContainer,
          onSecondaryContainer: const Color(0xFF01579B),
          tertiary: AppColors.warning,
          onTertiary: Colors.white,
          tertiaryContainer: AppColors.lightWarningContainer,
          onTertiaryContainer: AppColors.warningDark,
          error: AppColors.error,
          errorContainer: AppColors.lightEmergencyContainer,
          onErrorContainer: AppColors.emergencyDark,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightTextPrimary,
          surfaceContainerHighest: AppColors.lightSurfaceVariant,
          onSurfaceVariant: AppColors.lightTextSecondary,
          outline: AppColors.lightBorder,
        );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.lightBackground,
      surfaceVariant: AppColors.lightSurfaceVariant,
      textPrimary: AppColors.lightTextPrimary,
      textSecondary: AppColors.lightTextSecondary,
      textDisabled: AppColors.lightTextDisabled,
      border: AppColors.lightBorder,
      divider: AppColors.lightDivider,
    );
  }

  static ThemeData get dark {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.information,
          onSecondary: Colors.white,
          tertiary: AppColors.warning,
          onTertiary: Colors.white,
          error: const Color(0xFFFF6B6B),
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          surfaceContainerHighest: AppColors.darkSurfaceVariant,
          onSurfaceVariant: AppColors.darkTextSecondary,
          outline: AppColors.darkBorder,
        );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.darkBackground,
      surfaceVariant: AppColors.darkSurfaceVariant,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      textDisabled: AppColors.darkTextDisabled,
      border: AppColors.darkBorder,
      divider: AppColors.darkDivider,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color surfaceVariant,
    required Color textPrimary,
    required Color textSecondary,
    required Color textDisabled,
    required Color border,
    required Color divider,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: textPrimary),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: textSecondary),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),

      appBarTheme: AppBarThemeData(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),

      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textDisabled),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: brightness == Brightness.dark ? 0 : 2,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      bottomAppBarTheme: BottomAppBarThemeData(
        color: colorScheme.surface,
        elevation: 12,
        surfaceTintColor: Colors.transparent,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.emergency,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: CircleBorder(),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightTextPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),

      iconTheme: IconThemeData(color: textPrimary),
    );
  }

  AppTheme._();
}
