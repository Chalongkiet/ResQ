import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/disaster_event_model.dart';

class DisasterWarningBanner extends StatefulWidget {
  const DisasterWarningBanner({super.key, required this.events});

  final List<DisasterEvent> events;

  @override
  State<DisasterWarningBanner> createState() => _DisasterWarningBannerState();
}

class _DisasterWarningBannerState extends State<DisasterWarningBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const SizedBox.shrink();
    }

    final latest = widget.events.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(14),
        color: AppColors.emergency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.events.length == 1
                            ? 'คุณอยู่ในพื้นที่ภัยพิบัติ'
                            : 'คุณอยู่ในพื้นที่ภัยพิบัติ '
                                  '${widget.events.length} เหตุการณ์',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'ล่าสุด: ${latest.eventName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  latest.disasterType,
                  style: const TextStyle(color: Colors.white70),
                ),
                if (_expanded && widget.events.length > 1) ...[
                  const Divider(color: Colors.white30, height: 20),
                  for (final event in widget.events.skip(1))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.eventName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            event.disasterType,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
