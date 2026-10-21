import 'package:flutter/material.dart';

class MapControlButtons extends StatelessWidget {
  const MapControlButtons({
    super.key,
    required this.enabled,
    required this.isRefreshingLocation,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMyLocation,
  });

  final bool enabled;
  final bool isRefreshingLocation;

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onMyLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapButton(
          icon: Icons.add_rounded,
          tooltip: 'ซูมเข้า',
          enabled: enabled,
          onPressed: onZoomIn,
        ),
        const SizedBox(height: 8),
        _MapButton(
          icon: Icons.remove_rounded,
          tooltip: 'ซูมออก',
          enabled: enabled,
          onPressed: onZoomOut,
        ),
        const SizedBox(height: 12),
        _MapButton(
          icon: Icons.my_location_rounded,
          tooltip: 'ตำแหน่งของฉัน',
          enabled: enabled && !isRefreshingLocation,
          loading: isRefreshingLocation,
          onPressed: onMyLocation,
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
      ),
    );
  }
}
