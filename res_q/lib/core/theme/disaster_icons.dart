import 'package:flutter/material.dart';

abstract final class DisasterIcons {
  static IconData iconFor(String disasterType) {
    final type = disasterType.trim().toLowerCase();

    if (_containsAny(type, const ['อุทกภัย', 'น้ำท่วม', 'flood'])) {
      return Icons.flood_rounded;
    }

    if (_containsAny(type, const [
      'วาตภัย',
      'พายุ',
      'storm',
      'cyclone',
      'typhoon',
    ])) {
      return Icons.cyclone_rounded;
    }

    if (_containsAny(type, const ['อัคคีภัย', 'ไฟไหม้', 'ไฟป่า', 'fire'])) {
      return Icons.local_fire_department_rounded;
    }

    if (_containsAny(type, const ['แผ่นดินไหว', 'earthquake'])) {
      return Icons.vibration_rounded;
    }

    if (_containsAny(type, const ['ดินโคลนถล่ม', 'ดินถล่ม', 'landslide'])) {
      return Icons.landslide_rounded;
    }

    if (_containsAny(type, const ['สึนามิ', 'tsunami'])) {
      return Icons.tsunami_rounded;
    }

    if (_containsAny(type, const ['ภูเขาไฟ', 'volcano'])) {
      return Icons.volcano_rounded;
    }

    if (_containsAny(type, const ['ภัยแล้ง', 'แห้งแล้ง', 'drought'])) {
      return Icons.wb_sunny_rounded;
    }

    if (_containsAny(type, const ['ภัยหนาว', 'อากาศหนาว', 'cold'])) {
      return Icons.severe_cold_rounded;
    }

    if (_containsAny(type, const ['ฝุ่น', 'หมอกควัน', 'มลพิษ', 'pollution'])) {
      return Icons.air_rounded;
    }

    return Icons.warning_amber_rounded;
  }

  static bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }

  DisasterIcons._();
}
