import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/shared/validators/rescue_action_validator.dart';

void main() {
  group('RescueActionValidator.validateTotalAffected', () {
    test('requires a value', () {
      expect(
        RescueActionValidator.validateTotalAffected('  '),
        'กรุณาระบุจำนวนผู้ประสบภัยที่ช่วยเหลือ',
      );
    });

    test('rejects values that are not positive integers', () {
      expect(
        RescueActionValidator.validateTotalAffected('0'),
        'กรุณาระบุจำนวนเต็มที่มากกว่า 0',
      );
      expect(
        RescueActionValidator.validateTotalAffected('-1'),
        'กรุณาระบุจำนวนเต็มที่มากกว่า 0',
      );
      expect(
        RescueActionValidator.validateTotalAffected('1.5'),
        'กรุณาระบุจำนวนเต็มที่มากกว่า 0',
      );
    });

    test('accepts a positive whole number', () {
      expect(RescueActionValidator.validateTotalAffected('2'), isNull);
    });
  });

  group('RescueActionValidator.validateSafeLocationName', () {
    test('requires a safe location', () {
      expect(
        RescueActionValidator.validateSafeLocationName('   '),
        'กรุณาระบุสถานที่ปลอดภัย',
      );
    });

    test('rejects a safe location longer than 255 characters', () {
      expect(
        RescueActionValidator.validateSafeLocationName('a' * 256),
        'ชื่อสถานที่ปลอดภัยต้องไม่เกิน 255 ตัวอักษร',
      );
    });

    test('accepts a valid safe location', () {
      expect(
        RescueActionValidator.validateSafeLocationName('ศูนย์อพยพเทศบาล'),
        isNull,
      );
    });
  });
}
