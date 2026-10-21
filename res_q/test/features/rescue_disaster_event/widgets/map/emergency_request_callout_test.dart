import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/core/constants/emergency_request_status.dart';
import 'package:res_q/data/models/emergency_request_model.dart';
import 'package:res_q/features/rescue_disaster_event/widgets/map/emergency_request_callout.dart';

void main() {
  testWidgets('renders request details without vertical overflow', (
    tester,
  ) async {
    const request = EmergencyRequest(
      requestId: 'request-1',
      userId: 'victim-1',
      disasterEventId: 'event-1',
      requestType: 'อุทกภัย (น้ำท่วม)',
      latitude: 18.895273,
      longitude: 99.031608,
      requestDetail: 'มีเด็กเล็ก ผู้สูงอายุ และสถานการณ์กำลังรุนแรงขึ้น',
      requestStatus: EmergencyRequestStatus.waiting,
      safeStatus: false,
      affectedCount: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 170,
              child: EmergencyRequestCallout(
                request: request,
                onClose: _doNothing,
                onViewDetail: _doNothing,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ผู้ประสบภัย 3 คน'), findsOneWidget);
    expect(find.text('ดูรายละเอียด'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _doNothing() {}
