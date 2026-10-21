import 'package:flutter/material.dart';

import '../../../data/models/disaster_event_model.dart';

import '../../home/controllers/home_map_controller.dart';
import '../../home/widgets/disaster_alert_card.dart';

import '../controllers/rescue_disaster_event_controller.dart';

class RescueDisasterEventList extends StatelessWidget {
  const RescueDisasterEventList({
    super.key,
    required this.mapController,
    required this.rescueController,
    required this.onEventTap,
    required this.onJoin,
  });

  final HomeMapController mapController;

  final RescueDisasterEventController rescueController;

  final ValueChanged<DisasterEvent> onEventTap;

  final ValueChanged<DisasterEvent> onJoin;

  @override
  Widget build(BuildContext context) {
    final map = mapController;

    // ==================================================
    // Disaster Events
    // ==================================================

    if (map.visibleEvents.isNotEmpty) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.only(top: 10),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 6),
          itemCount: map.visibleEvents.length,
          itemBuilder: (context, index) {
            final event = map.visibleEvents[index];

            final result = map.distanceResultForEvent(event.id);

            if (result == null) {
              return const SizedBox.shrink();
            }

            final isJoined = rescueController.isJoinedEvent(event.id);

            final isChecking =
                rescueController.isSessionLoading ||
                rescueController.isCheckingJoinEvent(event.id);

            return DisasterAlertCard(
              event: event,

              distanceMeters: result.distanceMeters,

              isInside: result.isInside,

              isSelected: map.isEventSelected(event.id),

              enabled: map.mapInteractionEnabled,

              onTap: () {
                onEventTap(event);
              },

              showJoinButton: true,

              isJoined: isJoined,

              isJoinChecking: isChecking,

              onJoin: () {
                onJoin(event);
              },
            );
          },
        ),
      );
    }

    // ==================================================
    // Error
    // ==================================================

    if (map.hasDisasterDataError) {
      return const _BottomMessage(
        icon: Icons.cloud_off_outlined,
        text:
            'ไม่สามารถอัปเดตข้อมูลภัยพิบัติได้ '
            'กำลังใช้ข้อมูลล่าสุดที่มี',
      );
    }

    // ==================================================
    // Empty
    // ==================================================

    return const _BottomMessage(
      icon: Icons.check_circle_outline,
      text: 'ไม่มีเหตุการณ์ภัยพิบัติในขณะนี้',
    );
  }
}

// ==================================================
// Bottom Message
// ==================================================

class _BottomMessage extends StatelessWidget {
  const _BottomMessage({required this.icon, required this.text});

  final IconData icon;

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
