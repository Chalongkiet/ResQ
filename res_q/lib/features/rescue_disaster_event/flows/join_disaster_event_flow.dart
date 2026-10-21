import 'package:flutter/material.dart';

import '../../../data/models/disaster_event_model.dart';
import '../../../shared/widgets/success_alert_dialog.dart';

import '../controllers/join_disaster_event_controller.dart';
import '../controllers/rescue_disaster_event_controller.dart';

import '../models/rescue_deployment.dart';

import '../widgets/join/join_disaster_event_popup.dart';

class JoinDisasterEventFlowResult {
  const JoinDisasterEventFlowResult({
    required this.event,
    required this.deployment,
    required this.alreadyJoined,
  });

  final DisasterEvent event;

  final RescueDeployment deployment;

  final bool alreadyJoined;
}

class JoinDisasterEventFlow {
  const JoinDisasterEventFlow._();

  // ==================================================
  // Run
  // ==================================================

  static Future<JoinDisasterEventFlowResult?> run({
    required BuildContext context,
    required DisasterEvent event,
    required RescueDisasterEventController rescueController,
  }) async {
    debugPrint('================================');

    debugPrint('[JOIN] BUTTON PRESSED');

    debugPrint('[JOIN] eventId=${event.id}');

    debugPrint(
      '[JOIN] rescueTeamId='
      '${rescueController.rescueTeamId}',
    );

    final teamId = rescueController.rescueTeamId?.trim();

    // ==================================================
    // Validate Session
    // ==================================================

    if (teamId == null || teamId.isEmpty) {
      _showMessage(
        context,
        'ไม่พบข้อมูลหน่วยกู้ภัย '
        'กรุณาเข้าสู่ระบบใหม่อีกครั้ง',
      );

      return null;
    }

    // ==================================================
    // Prevent Duplicate Click
    // ==================================================

    if (rescueController.isCheckingJoinEvent(event.id)) {
      _showMessage(
        context,
        'กำลังตรวจสอบสถานะการเข้าร่วม '
        'กรุณารอสักครู่',
      );

      return null;
    }

    JoinDisasterEventController? joinController;

    try {
      // ==================================================
      // Check Existing Deployment
      // ==================================================

      debugPrint('[JOIN] checking existing deployment...');

      final existingDeployment = await rescueController
          .checkActiveDeploymentBeforeJoin(eventId: event.id);

      if (!context.mounted) {
        return null;
      }

      // ==================================================
      // Already Joined
      // ==================================================

      if (existingDeployment != null) {
        debugPrint('[JOIN] already joined');

        debugPrint(
          '[JOIN] deployment='
          '${existingDeployment.deploymentId}',
        );

        rescueController.markJoined(
          eventId: event.id,
          deployment: existingDeployment,
        );

        await _showAlreadyJoinedDialog(context);

        return JoinDisasterEventFlowResult(
          event: event,
          deployment: existingDeployment,
          alreadyJoined: true,
        );
      }

      // ==================================================
      // Load Resources
      // ==================================================

      debugPrint('[JOIN] preparing resources...');

      joinController = JoinDisasterEventController();

      await joinController.load(rescueTeamId: teamId);

      if (!context.mounted) {
        joinController.dispose();

        return null;
      }

      // ==================================================
      // Resource Error
      // ==================================================

      final resourceError = joinController.errorMessage;

      if (resourceError != null) {
        _showMessage(context, resourceError);

        joinController.dispose();

        joinController = null;

        return null;
      }

      debugPrint(
        '[JOIN] members='
        '${joinController.members.length}',
      );

      debugPrint(
        '[JOIN] vehicles='
        '${joinController.vehicles.length}',
      );

      // ==================================================
      // Member Validation
      // ==================================================

      if (joinController.members.isEmpty) {
        _showMessage(
          context,
          'ไม่พบข้อมูลสมาชิกกู้ภัย '
          'กรุณาเพิ่มสมาชิกก่อนเข้าร่วมภารกิจ',
        );

        joinController.dispose();

        joinController = null;

        return null;
      }

      // ==================================================
      // Vehicle Validation
      // ==================================================

      if (joinController.vehicles.isEmpty) {
        _showMessage(
          context,
          'ไม่พบข้อมูลยานพาหนะ '
          'กรุณาเพิ่มยานพาหนะก่อนเข้าร่วมภารกิจ',
        );

        joinController.dispose();

        joinController = null;

        return null;
      }

      // ==================================================
      // Join Popup
      // ==================================================

      debugPrint('[JOIN] opening join popup');

      final deployment = await showJoinDisasterEventPopup(
        context: context,
        event: event,
        rescueTeamId: teamId,
        controller: joinController,
      );

      joinController.dispose();

      joinController = null;

      if (!context.mounted || deployment == null) {
        return null;
      }

      // ==================================================
      // Join Success
      // ==================================================

      debugPrint('[JOIN] SUCCESS');

      debugPrint(
        '[JOIN] deployment='
        '${deployment.deploymentId}',
      );

      rescueController.markJoined(eventId: event.id, deployment: deployment);

      await _showJoinSuccessDialog(context);

      return JoinDisasterEventFlowResult(
        event: event,
        deployment: deployment,
        alreadyJoined: false,
      );
    } catch (error, stackTrace) {
      debugPrint('[JOIN] ERROR');

      debugPrint('[JOIN] $error');

      debugPrint('[JOIN] $stackTrace');

      joinController?.dispose();

      joinController = null;

      if (!context.mounted) {
        return null;
      }

      _showMessage(
        context,
        'ไม่สามารถเข้าร่วมเหตุการณ์ได้ '
        'กรุณาลองใหม่อีกครั้ง',
      );

      return null;
    } finally {
      joinController?.dispose();

      debugPrint('[JOIN] HANDLE FINISHED');

      debugPrint('================================');
    }
  }

  // ==================================================
  // Already Joined
  // ==================================================

  static Future<void> _showAlreadyJoinedDialog(BuildContext context) async {
    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return SuccessAlertDialog(
          title: 'เข้าร่วมเหตุการณ์แล้ว',
          message:
              'หน่วยกู้ภัยของคุณได้เข้าร่วม'
              'เหตุการณ์ภัยพิบัตินี้อยู่แล้ว',
          onConfirm: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }

  // ==================================================
  // Success
  // ==================================================

  static Future<void> _showJoinSuccessDialog(BuildContext context) async {
    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return SuccessAlertDialog(
          title: 'เข้าร่วมภารกิจสำเร็จ',
          message:
              'ระบบได้บันทึกชุดปฏิบัติการ '
              'และสถานะการเข้าร่วมเรียบร้อยแล้ว',
          onConfirm: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }

  // ==================================================
  // Message
  // ==================================================

  static void _showMessage(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
