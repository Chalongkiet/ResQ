import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/features/emergency/models/emergency_situation.dart';
import 'package:res_q/shared/validators/emergency_info_validator.dart';
import 'package:res_q/shared/validators/emergency_request_validator.dart';
import 'package:res_q/shared/validators/rescue_action_validator.dart';
import 'package:res_q/shared/validators/rescue_login_validator.dart';

void main() {
  group('EmergencyInfoValidator', () {
    test('validates required personal and contact fields', () {
      expect(EmergencyInfoValidator.validateFullName('Somchai Jaidee'), isNull);
      expect(EmergencyInfoValidator.validateFullName('John'), isNull);
      expect(EmergencyInfoValidator.validateFullName('Jon'), isNotNull);
      expect(EmergencyInfoValidator.validateFullName('  '), isNotNull);
      expect(EmergencyInfoValidator.validateBloodGroup('O+'), isNull);
      expect(EmergencyInfoValidator.validateBloodGroup('X'), isNotNull);
      expect(EmergencyInfoValidator.validatePhoneNumber('0812345678'), isNull);
      expect(
        EmergencyInfoValidator.validatePhoneNumber('0212345678'),
        isNotNull,
      );
      expect(
        EmergencyInfoValidator.validateEmergencyContactName('Somsri Jaidee'),
        isNull,
      );
      expect(
        EmergencyInfoValidator.validateEmergencyContactName('Jane'),
        isNull,
      );
      expect(
        EmergencyInfoValidator.validateEmergencyContactName('Jan'),
        isNotNull,
      );
      expect(
        EmergencyInfoValidator.validateEmergencyContactPhone(
          '0912345678',
          victimPhoneNumber: '0812345678',
        ),
        isNull,
      );
      expect(
        EmergencyInfoValidator.validateEmergencyContactPhone(
          '0812345678',
          victimPhoneNumber: '0812345678',
        ),
        'เบอร์ผู้ติดต่อฉุกเฉินต้องไม่ซ้ำกับเบอร์ของผู้ประสบภัย',
      );
    });

    test('allows short, punctuated optional medical information', () {
      expect(EmergencyInfoValidator.validateMedicalCondition('หอบหืด'), isNull);
      expect(
        EmergencyInfoValidator.validateAllergy('แพ้ยา: Penicillin'),
        isNull,
      );
      expect(
        EmergencyInfoValidator.validateRegularMedication('Aspirin 81 mg/day'),
        isNull,
      );
      expect(EmergencyInfoValidator.validateAllergy(''), isNull);
      expect(EmergencyInfoValidator.validateAllergy('a' * 256), isNotNull);
    });

    test('requires consent', () {
      expect(EmergencyInfoValidator.validateConsent(true), isNull);
      expect(EmergencyInfoValidator.validateConsent(false), isNotNull);
    });
  });

  group('EmergencyRequestValidator', () {
    test(
      'accepts 1-99 affected people and rejects values outside the range',
      () {
        expect(EmergencyRequestValidator.validateAffectedCount(1), isNull);
        expect(EmergencyRequestValidator.validateAffectedCount(99), isNull);
        expect(EmergencyRequestValidator.validateAffectedCount(0), isNotNull);
        expect(EmergencyRequestValidator.validateAffectedCount(100), isNotNull);
      },
    );

    test('accepts useful punctuation and line breaks', () {
      expect(
        EmergencyRequestValidator.validateDetail(
          'ติดอยู่ชั้น 2/3 - ห้อง A, ประตูสีแดง.\nมีผู้บาดเจ็บ 1 คน',
        ),
        isNull,
      );
      expect(EmergencyRequestValidator.validateDetail('   '), isNotNull);
      expect(EmergencyRequestValidator.validateDetail('a' * 256), isNotNull);
    });

    test('requires a situation but allows optional additional detail', () {
      expect(
        EmergencyRequestValidator.validateSituationSelection(const []),
        isNotNull,
      );
      expect(
        EmergencyRequestValidator.validateSituationSelection([
          EmergencySituation.trapped,
        ]),
        isNull,
      );
      expect(
        EmergencyRequestValidator.validateOptionalAdditionalDetail(''),
        isNull,
      );
      expect(
        EmergencyRequestValidator.validateOtherSituationDetail(
          otherSelected: true,
          value: '',
        ),
        isNotNull,
      );
    });

    test('builds a readable detail from selected situations', () {
      expect(
        EmergencySituationSummary.build(
          situations: const [
            EmergencySituation.trapped,
            EmergencySituation.elderly,
          ],
          additionalDetail: 'อยู่ชั้น 2',
        ),
        'ติดอยู่ในพื้นที่ • มีผู้สูงอายุ\nรายละเอียด: อยู่ชั้น 2',
      );
    });
  });

  group('RescueActionValidator', () {
    test('validates required reasons and optional details', () {
      expect(
        RescueActionValidator.validateLeaveReason(
          'น้ำท่วมสูง / เข้าพื้นที่ไม่ได้',
        ),
        isNull,
      );
      expect(RescueActionValidator.validateLeaveReason('  '), isNotNull);
      expect(
        RescueActionValidator.validateCancelMissionReason(
          'รถเสีย - ไปต่อไม่ได้',
        ),
        isNull,
      );
      expect(RescueActionValidator.validateOptionalDetail(null), isNull);
      expect(
        RescueActionValidator.validateOptionalDetail('a' * 256),
        isNotNull,
      );
    });
  });

  group('RescueLoginValidator', () {
    test('validates username and password formats', () {
      expect(RescueLoginValidator.validateUsername('rescue01'), isNull);
      expect(RescueLoginValidator.validateUsername('rescue-01'), isNotNull);
      expect(RescueLoginValidator.validatePassword('Pass_123'), isNull);
      expect(RescueLoginValidator.validatePassword('short'), isNotNull);
    });
  });
}
