import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/shared/widgets/map_pin_marker.dart';

void main() {
  testWidgets('SOS pin exposes its label and handles taps', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MapPinMarker(
              kind: MapPinMarkerKind.sos,
              color: const Color(0xFFD32F2F),
              semanticLabel: 'คำร้องขอความช่วยเหลือ SOS',
              onTap: () => tapCount++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('SOS'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('คำร้องขอความช่วยเหลือ SOS')),
      findsOneWidget,
    );

    await tester.tap(find.byType(MapPinMarker));

    expect(tapCount, 1);
  });

  testWidgets('citizen and rescue pins expose different symbols', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              MapPinMarker(
                kind: MapPinMarkerKind.citizen,
                color: Color(0xFF1565C0),
                semanticLabel: 'ตำแหน่งผู้ประสบภัย',
              ),
              MapPinMarker(
                kind: MapPinMarkerKind.rescueTeam,
                color: Color(0xFFF97316),
                semanticLabel: 'ตำแหน่งหน่วยกู้ภัย',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('ตำแหน่งผู้ประสบภัย'), findsOneWidget);
    expect(find.bySemanticsLabel('ตำแหน่งหน่วยกู้ภัย'), findsOneWidget);
  });
}
