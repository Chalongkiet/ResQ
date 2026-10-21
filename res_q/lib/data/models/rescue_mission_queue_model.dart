class RescueMissionQueueEntry {
  const RescueMissionQueueEntry({
    required this.requestId,
    required this.missionId,
  });

  final String requestId;
  final String missionId;

  bool get isValid => requestId.isNotEmpty && missionId.isNotEmpty;

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'requestId': requestId,
    'missionId': missionId,
  };

  static RescueMissionQueueEntry? fromDynamic(dynamic value) {
    if (value is! Map) return null;

    final requestId = (value['requestId'] ?? '').toString().trim();
    final missionId = (value['missionId'] ?? '').toString().trim();
    final entry = RescueMissionQueueEntry(
      requestId: requestId,
      missionId: missionId,
    );
    return entry.isValid ? entry : null;
  }
}

class RescueMissionQueueState {
  const RescueMissionQueueState({required this.active, required this.queued});

  static const int maximumQueuedMissions = 2;

  final RescueMissionQueueEntry? active;
  final List<RescueMissionQueueEntry> queued;

  bool get hasQueueCapacity => queued.length < maximumQueuedMissions;

  factory RescueMissionQueueState.fromDeployment(Map<String, dynamic> data) {
    final activeRequestId = (data['activeMissionRequestId'] ?? '')
        .toString()
        .trim();
    final activeMissionId = (data['activeMissionId'] ?? '').toString().trim();
    final active = RescueMissionQueueEntry(
      requestId: activeRequestId,
      missionId: activeMissionId,
    );

    final parsedQueue = <RescueMissionQueueEntry>[];
    final seenMissionIds = <String>{};
    final rawQueue = data['missionQueue'];
    if (rawQueue is Iterable) {
      for (final rawEntry in rawQueue) {
        final entry = RescueMissionQueueEntry.fromDynamic(rawEntry);
        if (entry == null ||
            entry.missionId == activeMissionId ||
            !seenMissionIds.add(entry.missionId)) {
          continue;
        }
        parsedQueue.add(entry);
      }
    }

    return RescueMissionQueueState(
      active: active.isValid ? active : null,
      queued: List<RescueMissionQueueEntry>.unmodifiable(parsedQueue),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'activeMissionRequestId': active?.requestId,
    'activeMissionId': active?.missionId,
    'missionQueue': queued.map((entry) => entry.toFirestore()).toList(),
  };
}
