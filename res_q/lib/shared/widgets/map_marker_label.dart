import 'package:flutter/material.dart';

class MapMarkerLabel extends StatelessWidget {
  const MapMarkerLabel({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 132),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
