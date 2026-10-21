import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/data/models/rescue_mission_queue_model.dart';

void main() {
  group('RescueMissionQueueState', () {
    test('parses active mission and ordered queue from deployment data', () {
      final state = RescueMissionQueueState.fromDeployment({
        'activeMissionRequestId': 'request-active',
        'activeMissionId': 'mission-active',
        'missionQueue': [
          {'requestId': 'request-1', 'missionId': 'mission-1'},
          {'requestId': 'request-2', 'missionId': 'mission-2'},
        ],
      });

      expect(state.active?.missionId, 'mission-active');
      expect(state.queued.map((entry) => entry.missionId), [
        'mission-1',
        'mission-2',
      ]);
      expect(state.hasQueueCapacity, isFalse);
    });

    test('ignores invalid, duplicated, and active entries in queue', () {
      final state = RescueMissionQueueState.fromDeployment({
        'activeMissionRequestId': 'request-active',
        'activeMissionId': 'mission-active',
        'missionQueue': [
          {'requestId': '', 'missionId': 'invalid'},
          {'requestId': 'request-active', 'missionId': 'mission-active'},
          {'requestId': 'request-1', 'missionId': 'mission-1'},
          {'requestId': 'request-1', 'missionId': 'mission-1'},
        ],
      });

      expect(state.queued, hasLength(1));
      expect(state.queued.single.missionId, 'mission-1');
      expect(state.hasQueueCapacity, isTrue);
    });

    test('serializes empty active mission as null fields', () {
      const state = RescueMissionQueueState(
        active: null,
        queued: <RescueMissionQueueEntry>[],
      );

      expect(state.toFirestore(), {
        'activeMissionRequestId': null,
        'activeMissionId': null,
        'missionQueue': <Map<String, dynamic>>[],
      });
    });
  });
}
