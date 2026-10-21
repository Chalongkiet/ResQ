import 'package:flutter/material.dart';

abstract final class DisasterColors {
  static Color colorFor(String disasterType) {
    switch (disasterType) {
      case 'อุทกภัย (น้ำท่วม)':
        return const Color(0xFF0077FF);

      case 'วาตภัย (พายุ)':
        return const Color(0xFF7C3AED);

      case 'อัคคีภัย (ไฟไหม้)':
        return const Color(0xFFFF3B30);

      case 'แผ่นดินไหว':
        return const Color(0xFFFFB000);

      case 'ดินโคลนถล่ม':
        return const Color(0xFF9A5B13);

      default:
        return const Color(0xFFFF5A5F);
    }
  }

  static Color fillColorFor(String disasterType) {
    return colorFor(disasterType).withValues(alpha: 0.28);
  }

  DisasterColors._();
}
