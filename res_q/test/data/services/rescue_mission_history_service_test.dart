import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/core/constants/emergency_request_status.dart';
import 'package:res_q/core/constants/mission_status.dart';
import 'package:res_q/data/models/emergency_request_model.dart';
import 'package:res_q/data/models/rescue_mission_history_item.dart';
import 'package:res_q/data/models/rescue_mission_model.dart';
import 'package:res_q/data/services/rescue_mission_history_service.dart';

void main() {
  RescueMissionHistoryItem item({
    required String id,
    required DateTime completedAt,
    required bool safe,
    String eventId = 'event',
    String eventName = 'น้ำท่วมเมือง',
    String victimName = '',
    int affectedCount = 1,
    int? totalAffected,
  }) {
    return RescueMissionHistoryItem(
      request: EmergencyRequest(
        requestId: 'request-$id',
        userId: 'citizen',
        disasterEventId: eventId,
        requestType: 'อุทกภัย',
        latitude: 18.0,
        longitude: 99.0,
        requestDetail: '',
        requestStatus: EmergencyRequestStatus.completed,
        safeStatus: safe,
        affectedCount: affectedCount,
      ),
      mission: RescueMission(
        missionId: id,
        missionName: 'ภารกิจ $id',
        missionStatus: MissionStatus.completed,
        deploymentId: 'deployment',
        missionEndDate: completedAt,
        totalAffected: totalAffected,
      ),
      disasterEventName: eventName,
      victimName: victimName,
    );
  }

  group('RescueMissionHistoryService', () {
    final older = item(
      id: 'older',
      completedAt: DateTime(2026, 8, 26),
      safe: false,
    );
    final newer = item(
      id: 'newer',
      completedAt: DateTime(2026, 8, 27),
      safe: true,
    );

    test('sorts newest completed mission first', () {
      final result = RescueMissionHistoryService.sortNewestFirst([
        older,
        newer,
      ]);

      expect(result.map((item) => item.mission.missionId), ['newer', 'older']);
    });

    test('filters records by safety confirmation', () {
      expect(
        RescueMissionHistoryService.filter([
          older,
          newer,
        ], RescueMissionHistoryFilter.safetyConfirmed),
        [newer],
      );
      expect(
        RescueMissionHistoryService.filter([
          older,
          newer,
        ], RescueMissionHistoryFilter.awaitingSafety),
        [older],
      );
    });

    test('shows victim name with a fallback for legacy data', () {
      final named = item(
        id: 'named',
        completedAt: DateTime(2026, 8, 28),
        safe: true,
        victimName: 'สมชาย ใจดี',
      );

      expect(named.displayVictimName, 'สมชาย ใจดี');
      expect(older.displayVictimName, 'ไม่พบข้อมูลชื่อผู้ประสบภัย');
    });

    test('filters by year, month, and disaster event', () {
      final otherEvent = item(
        id: 'other-event',
        completedAt: DateTime(2026, 8, 20),
        safe: true,
        eventId: 'event-2',
      );
      final otherMonth = item(
        id: 'other-month',
        completedAt: DateTime(2026, 7, 20),
        safe: true,
      );

      final result = RescueMissionHistoryService.filterByPeriodAndDisaster(
        [newer, otherEvent, otherMonth],
        year: 2026,
        month: 8,
        disasterEventId: 'event',
      );

      expect(result, [newer]);
    });

    test(
      'totals only safety-confirmed affected people with old data fallback',
      () {
        final confirmed = item(
          id: 'confirmed',
          completedAt: DateTime(2026, 8, 28),
          safe: true,
          affectedCount: 2,
          totalAffected: 4,
        );
        final legacyConfirmed = item(
          id: 'legacy',
          completedAt: DateTime(2026, 8, 27),
          safe: true,
          affectedCount: 3,
        );
        final awaiting = item(
          id: 'awaiting',
          completedAt: DateTime(2026, 8, 26),
          safe: false,
          totalAffected: 10,
        );

        expect(
          RescueMissionHistoryService.totalSafetyConfirmedAffected([
            confirmed,
            legacyConfirmed,
            awaiting,
          ]),
          7,
        );
      },
    );
  });
}
