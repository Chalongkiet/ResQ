import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/map_pin_marker.dart';

class EmergencyRequestMarker extends StatelessWidget {
  const EmergencyRequestMarker({
    super.key,
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visualScale = MapPinMarker.visualScaleForZoom(
      MapCamera.of(context).zoom,
    );

    return Semantics(
      label: 'คำร้องขอความช่วยเหลือ SOS',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Transform.scale(
          scale: visualScale,
          alignment: Alignment.bottomCenter,
          child: const ExcludeSemantics(
            child: MapPinMarker(
              kind: MapPinMarkerKind.sos,
              color: AppColors.emergency,
              semanticLabel: 'คำร้องขอความช่วยเหลือ SOS',
            ),
          ),
        ),
      ),
    );
  }
}
