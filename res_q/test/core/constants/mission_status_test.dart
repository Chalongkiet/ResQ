import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/core/constants/mission_status.dart';

void main() {
  group('MissionStatus next active status', () {
    test('advances active mission one step at a time', () {
      expect(
        MissionStatus.nextActiveStatus(MissionStatus.onTheWay),
        MissionStatus.arrived,
      );
      expect(
        MissionStatus.nextActiveStatus(MissionStatus.arrived),
        MissionStatus.rescuing,
      );
      expect(
        MissionStatus.nextActiveStatus(MissionStatus.rescuing),
        MissionStatus.transporting,
      );
      expect(
        MissionStatus.nextActiveStatus(MissionStatus.transporting),
        MissionStatus.evacuationCenterReached,
      );
    });

    test('has no next active status at the final active stage', () {
      expect(
        MissionStatus.nextActiveStatus(MissionStatus.evacuationCenterReached),
        isNull,
      );
    });

    test('provides a clear action label for the next step', () {
      expect(
        MissionStatus.nextActionLabel(MissionStatus.onTheWay),
        'ถึงจุดเกิดเหตุแล้ว',
      );
      expect(
        MissionStatus.nextActionLabel(MissionStatus.arrived),
        'เริ่มช่วยเหลือผู้ประสบภัย',
      );
    });
  });

  group('MissionStatus queued assignment', () {
    test('is assigned but is not an active progress status', () {
      expect(MissionStatus.isQueued(MissionStatus.queued), isTrue);
      expect(MissionStatus.isAssigned(MissionStatus.queued), isTrue);
      expect(MissionStatus.isActive(MissionStatus.queued), isFalse);
      expect(MissionStatus.nextActiveStatus(MissionStatus.queued), isNull);
    });

    test(
      'uses stage 2 while explaining that the team is finishing prior work',
      () {
        expect(MissionStatus.stageOf(MissionStatus.queued), 2);
        expect(
          MissionStatus.labelOf(MissionStatus.queued),
          contains('ภารกิจก่อนหน้า'),
        );
      },
    );
  });
}
