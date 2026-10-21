import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);

  // Emergency / SOS
  static const Color emergency = Color(0xFFD32F2F);
  static const Color emergencyDark = Color(0xFFB71C1C);

  // Status
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color warningDark = Color(0xFFA54B00);
  static const Color information = Color(0xFF0288D1);
  static const Color error = emergency;

  // Light semantic containers
  static const Color lightPrimaryContainer = Color(0xFFE3F2FD);
  static const Color lightEmergencyContainer = Color(0xFFFFEBEE);
  static const Color lightWarningContainer = Color(0xFFFFF3E0);
  static const Color lightSuccessContainer = Color(0xFFE8F5E9);
  static const Color lightInformationContainer = Color(0xFFE1F5FE);

  // Light mode
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEEF2F7);
  static const Color lightTextPrimary = Color(0xFF1F2937);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextDisabled = Color(0xFF9CA3AF);
  static const Color lightBorder = Color(0xFFD7DEE8);
  static const Color lightDivider = Color(0xFFE5EAF0);

  // Dark mode
  static const Color darkBackground = Color(0xFF101114);
  static const Color darkSurface = Color(0xFF1A1C20);
  static const Color darkSurfaceVariant = Color(0xFF24272D);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFB5B8C0);
  static const Color darkTextDisabled = Color(0xFF777B84);
  static const Color darkBorder = Color(0xFF353840);
  static const Color darkDivider = Color(0xFF2C2F35);

  AppColors._();
}
