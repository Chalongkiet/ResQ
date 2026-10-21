import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/core/theme/disaster_icons.dart';

void main() {
  group('DisasterIcons', () {
    test('maps supported Thai disaster types to meaningful icons', () {
      expect(DisasterIcons.iconFor('อุทกภัย (น้ำท่วม)'), Icons.flood_rounded);
      expect(DisasterIcons.iconFor('วาตภัย (พายุ)'), Icons.cyclone_rounded);
      expect(
        DisasterIcons.iconFor('อัคคีภัย (ไฟไหม้)'),
        Icons.local_fire_department_rounded,
      );
      expect(DisasterIcons.iconFor('แผ่นดินไหว'), Icons.vibration_rounded);
      expect(DisasterIcons.iconFor('ดินโคลนถล่ม'), Icons.landslide_rounded);
    });

    test('supports short, extended, and English legacy values', () {
      expect(DisasterIcons.iconFor('อุทกภัย'), Icons.flood_rounded);
      expect(
        DisasterIcons.iconFor('เหตุไฟป่า'),
        Icons.local_fire_department_rounded,
      );
      expect(DisasterIcons.iconFor('TSUNAMI'), Icons.tsunami_rounded);
    });

    test('uses warning icon when disaster type is unknown', () {
      expect(
        DisasterIcons.iconFor('ภัยประเภทใหม่'),
        Icons.warning_amber_rounded,
      );
    });
  });
}
