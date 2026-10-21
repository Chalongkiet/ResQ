import 'package:flutter/material.dart';

enum MapPinMarkerKind { citizen, rescueTeam, sos }

class MapPinMarker extends StatelessWidget {
  const MapPinMarker({
    super.key,
    required this.kind,
    required this.color,
    required this.semanticLabel,
    this.isSelected = false,
    this.onTap,
  });

  static const double markerWidth = 48;
  static const double markerHeight = 60;

  /// ลดขนาดภาพหมุดเมื่อซูมออก โดยยังคงจุดปลายหมุดไว้ที่พิกัดเดิม
  ///
  /// ที่ zoom 14 ขึ้นไปใช้ขนาดปกติ ส่วนแผนที่มุมกว้างจะลดลงสูงสุด
  /// เหลือประมาณ 58% เพื่อลดการบังกันของคำร้องที่อยู่ใกล้กัน
  static double visualScaleForZoom(double zoom) {
    return (0.6 + ((zoom - 10) * 0.1)).clamp(0.58, 1.0).toDouble();
  }

  final MapPinMarkerKind kind;
  final Color color;
  final String semanticLabel;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pin = SizedBox(
      width: markerWidth,
      height: markerHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapPinPainter(color: color, isSelected: isSelected),
            ),
          ),
          Positioned(
            top: 5,
            width: 28,
            height: 28,
            child: Center(child: ExcludeSemantics(child: _buildSymbol())),
          ),
        ],
      ),
    );

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: onTap == null
          ? pin
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: pin,
            ),
    );
  }

  Widget _buildSymbol() {
    return switch (kind) {
      MapPinMarkerKind.citizen => Icon(
        Icons.person_rounded,
        size: 21,
        color: color,
      ),
      MapPinMarkerKind.rescueTeam => _AmbulanceIcon(color: color),
      MapPinMarkerKind.sos => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'SOS',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            height: 1,
          ),
        ),
      ),
    };
  }
}

class _MapPinPainter extends CustomPainter {
  const _MapPinPainter({required this.color, required this.isSelected});

  final Color color;
  final bool isSelected;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPinPath(size);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);

    if (isSelected) {
      final selectedPaint = Paint()
        ..color = Color.lerp(color, Colors.black, 0.22)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, selectedPaint);
    }

    canvas.drawPath(path, Paint()..color = color);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);

    canvas.drawCircle(
      Offset(size.width / 2, 19),
      14,
      Paint()..color = Colors.white,
    );
  }

  Path _buildPinPath(Size size) {
    final centerX = size.width / 2;

    return Path()
      ..moveTo(centerX, size.height - 1)
      ..cubicTo(centerX - 5, size.height - 10, 2, 36, 2, 21)
      ..cubicTo(2, 9, 11, 1, centerX, 1)
      ..cubicTo(size.width - 11, 1, size.width - 2, 9, size.width - 2, 21)
      ..cubicTo(
        size.width - 2,
        36,
        centerX + 5,
        size.height - 10,
        centerX,
        size.height - 1,
      )
      ..close();
  }

  @override
  bool shouldRepaint(covariant _MapPinPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isSelected != isSelected;
  }
}

class _AmbulanceIcon extends StatelessWidget {
  const _AmbulanceIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 18),
      painter: _AmbulanceIconPainter(color),
    );
  }
}

class _AmbulanceIconPainter extends CustomPainter {
  const _AmbulanceIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final body = Path()
      ..moveTo(8, 4)
      ..lineTo(22, 4)
      ..lineTo(22, 14)
      ..lineTo(3, 14)
      ..lineTo(1.5, 12)
      ..lineTo(1.5, 9)
      ..lineTo(5, 6)
      ..lineTo(8, 6)
      ..close();
    canvas.drawPath(body, stroke);

    canvas.drawLine(const Offset(8, 4), const Offset(8, 14), stroke);
    canvas.drawCircle(const Offset(6, 14.5), 2.5, stroke);
    canvas.drawCircle(const Offset(18, 14.5), 2.5, stroke);

    canvas.drawLine(const Offset(15, 6), const Offset(15, 11), stroke);
    canvas.drawLine(const Offset(12.5, 8.5), const Offset(17.5, 8.5), stroke);
  }

  @override
  bool shouldRepaint(covariant _AmbulanceIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
