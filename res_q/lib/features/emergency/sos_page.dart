import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/current_disaster_event_service.dart';
import '../../shared/validators/emergency_request_validator.dart';
import '../../shared/widgets/success_alert_dialog.dart';
import 'controllers/sos_camera_controller.dart';
import 'controllers/sos_emergency_info_controller.dart';
import 'controllers/sos_location_controller.dart';
import 'controllers/sos_submit_controller.dart';
import 'models/emergency_situation.dart';
import 'widgets/sos_emergency_info_card.dart';
import 'widgets/sos_location_preview_card.dart';
import 'widgets/sos_request_form.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  // ==================================================
  // Controllers
  // ==================================================

  late final SosLocationController _locationController;

  late final SosEmergencyInfoController _emergencyInfoController;

  late final SosCameraController _cameraController;

  late final SosSubmitController _submitController;

  late final TextEditingController _detailController;

  late final Listenable _pageListenable;

  // ==================================================
  // Local State
  // ==================================================

  /// true ระหว่างตรวจสอบ Disaster Event ล่าสุด
  /// ก่อนเริ่ม Submit จริง
  bool _isPreparingSubmit = false;

  /// true ระหว่างตรวจ Firestore ว่าผู้ใช้มี WAITING/ACCEPTED เดิมหรือไม่
  bool _isRestoringActiveRequest = true;

  String? _restoreActiveRequestError;

  bool _hasInitializedSosForm = false;

  final Set<EmergencySituation> _selectedSituations = <EmergencySituation>{};

  int _affectedCount = 1;

  // ==================================================
  // Init
  // ==================================================

  @override
  void initState() {
    super.initState();

    _locationController = SosLocationController();

    _emergencyInfoController = SosEmergencyInfoController();

    _cameraController = SosCameraController();

    _submitController = SosSubmitController();

    _detailController = TextEditingController();

    // ==================================================
    // รวม State ทั้งหมดไว้ใน Listenable เดียว
    // ==================================================

    _pageListenable = Listenable.merge([
      _locationController,
      _emergencyInfoController,
      _cameraController,
      _submitController,
      _detailController,
    ]);

    // ตรวจคำร้องเดิมก่อนเริ่ม GPS/Camera/Form
    _restoreActiveEmergencyRequest();
  }

  Future<void> _restoreActiveEmergencyRequest() async {
    if (mounted) {
      setState(() {
        _isRestoringActiveRequest = true;
        _restoreActiveRequestError = null;
      });
    }

    try {
      final activeRequest = await _submitController.findActiveRequest().timeout(
        const Duration(seconds: 6),
      );

      if (!mounted) {
        return;
      }

      if (activeRequest != null) {
        context.goNamed(
          AppRouteNames.emergencyTracking,
          pathParameters: {'requestId': activeRequest.requestId},
        );

        return;
      }

      setState(() {
        _isRestoringActiveRequest = false;
      });

      _initializeSosForm();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRestoringActiveRequest = false;
        _restoreActiveRequestError =
            'ไม่สามารถตรวจสอบคำร้องเดิมได้ กรุณาลองใหม่อีกครั้ง';
      });
    }
  }

  void _initializeSosForm() {
    if (_hasInitializedSosForm) {
      return;
    }

    _hasInitializedSosForm = true;

    // GPS + Disaster Event
    _locationController.initialize();

    // Emergency Info
    _emergencyInfoController.load();

    // Recover Camera Lost Data
    _cameraController.initialize();
  }

  // ==================================================
  // Dispose
  // ==================================================

  @override
  void dispose() {
    _locationController.dispose();

    _emergencyInfoController.dispose();

    _cameraController.dispose();

    _submitController.dispose();

    _detailController.dispose();

    super.dispose();
  }

  // ==================================================
  // Can Submit
  // ==================================================

  bool get _canSubmit {
    final situationValid =
        EmergencyRequestValidator.validateSituationSelection(
          _selectedSituations,
        ) ==
        null;
    final additionalDetailValid =
        EmergencyRequestValidator.validateOtherSituationDetail(
          otherSelected: _selectedSituations.contains(EmergencySituation.other),
          value: _detailController.text,
        ) ==
        null;
    final requestDetailValid = EmergencyRequestValidator.isDetailValid(
      _buildRequestDetail(),
    );
    final affectedCountValid =
        EmergencyRequestValidator.validateAffectedCount(_affectedCount) == null;

    return
    // ต้องตรวจคำร้องเดิมสำเร็จก่อน
    !_isRestoringActiveRequest &&
        _restoreActiveRequestError == null &&
        // ยังไม่อยู่ระหว่าง Fresh Disaster Check
        !_isPreparingSubmit &&
        // Submit ไม่ได้กำลังทำงาน
        !_submitController.isSubmitting &&
        // ยังไม่ได้ Submit สำเร็จ
        !_submitController.isSuccess &&
        // ไม่ได้กำลังเปิด Camera
        !_cameraController.isCapturing &&
        // GPS + Disaster Area พร้อม
        _locationController.canSubmitEmergencyRequest &&
        // Emergency Info พร้อม
        _emergencyInfoController.isReady &&
        // เลือกสถานการณ์และข้อความสรุปผ่าน Validation
        situationValid &&
        additionalDetailValid &&
        requestDetailValid &&
        affectedCountValid;
  }

  List<EmergencySituation> get _orderedSelectedSituations => EmergencySituation
      .values
      .where(_selectedSituations.contains)
      .toList(growable: false);

  String _buildRequestDetail() {
    return EmergencySituationSummary.build(
      situations: _orderedSelectedSituations,
      additionalDetail: _detailController.text,
    );
  }

  void _toggleSituation(EmergencySituation situation) {
    if (_isSubmitBusy) return;

    setState(() {
      if (!_selectedSituations.add(situation)) {
        _selectedSituations.remove(situation);
      }
    });
  }

  void _decreaseAffectedCount() {
    if (_isSubmitBusy || _affectedCount <= 1) return;
    setState(() => _affectedCount--);
  }

  void _increaseAffectedCount() {
    if (_isSubmitBusy ||
        _affectedCount >= EmergencyRequestValidator.maxAffectedCount) {
      return;
    }
    setState(() => _affectedCount++);
  }

  // ==================================================
  // Submit Busy
  // ==================================================

  bool get _isSubmitBusy {
    return _isPreparingSubmit || _submitController.isSubmitting;
  }

  // ==================================================
  // Submit Button Label
  // ==================================================

  String get _submitButtonLabel {
    if (_isPreparingSubmit) {
      return 'กำลังตรวจสอบพื้นที่...';
    }

    if (_submitController.isSavingRequest) {
      return 'กำลังส่งคำร้อง...';
    }

    if (_submitController.isUploadingImage) {
      return 'กำลังอัปโหลดรูปภาพ...';
    }

    if (_submitController.isAttachingImage) {
      return 'กำลังบันทึกรูปภาพ...';
    }

    if (_submitController.isSuccess) {
      return 'ส่งคำร้องแล้ว';
    }

    return 'ส่งคำร้องขอความช่วยเหลือ';
  }

  // ==================================================
  // Build
  // ==================================================

  void _goToHome() {
    if (!mounted) {
      return;
    }

    context.goNamed(AppRouteNames.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final canShowSosForm =
        !_isRestoringActiveRequest && _restoreActiveRequestError == null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goToHome();
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,

        // ==================================================
        // AppBar
        // ==================================================
        appBar: AppBar(
          leading: IconButton(
            onPressed: _goToHome,
            tooltip: 'กลับหน้าหลัก',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('แจ้งเหตุฉุกเฉิน'),
        ),

        // ==================================================
        // Body
        // ==================================================
        body: SafeArea(
          child: canShowSosForm
              ? ListenableBuilder(
                  listenable: _pageListenable,
                  builder: (context, child) {
                    return _buildBody();
                  },
                )
              : _buildActiveRequestRestoreState(),
        ),

        // ==================================================
        // Bottom Submit Button
        // ==================================================
        bottomNavigationBar: canShowSosForm
            ? ListenableBuilder(
                listenable: _pageListenable,
                builder: (context, child) {
                  return _buildSubmitBar();
                },
              )
            : null,
      ),
    );
  }

  Widget _buildActiveRequestRestoreState() {
    final theme = Theme.of(context);
    final error = _restoreActiveRequestError;

    if (_isRestoringActiveRequest) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('กำลังตรวจสอบคำร้องขอความช่วยเหลือเดิม...'),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 58,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              error ?? 'ไม่สามารถตรวจสอบคำร้องเดิมได้',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _restoreActiveEmergencyRequest,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // Body
  // ==================================================

  Widget _buildBody() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // ==================================================
        // Realtime Map
        // ==================================================
        SosLocationPreviewCard(controller: _locationController),

        const SizedBox(height: 14),

        // ==================================================
        // Location Problems
        // ==================================================
        if (_locationController.position == null) ...[
          _buildLocationState(),

          const SizedBox(height: 14),
        ],

        // ==================================================
        // Emergency Info
        // ==================================================
        SosEmergencyInfoCard(controller: _emergencyInfoController),

        const SizedBox(height: 22),

        // ==================================================
        // Form
        // ==================================================
        SosRequestForm(
          locationController: _locationController,
          cameraController: _cameraController,
          detailController: _detailController,
          selectedSituations: _selectedSituations,
          onSituationToggled: _toggleSituation,
          affectedCount: _affectedCount,
          onDecreaseAffectedCount: _decreaseAffectedCount,
          onIncreaseAffectedCount: _increaseAffectedCount,
        ),
      ],
    );
  }

  // ==================================================
  // Location State
  // ==================================================

  Widget _buildLocationState() {
    final theme = Theme.of(context);

    // ==================================================
    // Loading
    // ==================================================

    if (_locationController.isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),

            SizedBox(width: 12),

            Expanded(child: Text('กำลังค้นหาตำแหน่งปัจจุบันของคุณ...')),
          ],
        ),
      );
    }

    // ==================================================
    // GPS Disabled
    // ==================================================

    if (_locationController.isServiceDisabled) {
      return _LocationProblemCard(
        icon: Icons.location_off_outlined,
        title: 'กรุณาเปิดตำแหน่ง',
        message: 'ต้องเปิด GPS เพื่อระบุตำแหน่งที่ต้องการความช่วยเหลือ',
        actionLabel: 'เปิดการตั้งค่าตำแหน่ง',
        onAction: () async {
          await _locationController.openLocationSettings();
        },
        secondaryActionLabel: 'ลองใหม่',
        onSecondaryAction: () async {
          await _locationController.retry();
        },
      );
    }

    // ==================================================
    // Permission Denied Forever
    // ==================================================

    if (_locationController.isPermissionDeniedForever) {
      return _LocationProblemCard(
        icon: Icons.location_disabled_outlined,
        title: 'ไม่ได้รับสิทธิ์ตำแหน่ง',
        message: 'กรุณาอนุญาตให้ ResQ เข้าถึงตำแหน่งจากการตั้งค่าแอป',
        actionLabel: 'เปิดการตั้งค่าแอป',
        onAction: () async {
          await _locationController.openAppSettings();
        },
        secondaryActionLabel: 'ลองใหม่',
        onSecondaryAction: () async {
          await _locationController.retry();
        },
      );
    }

    // ==================================================
    // Permission Denied
    // ==================================================

    if (_locationController.isPermissionDenied) {
      return _LocationProblemCard(
        icon: Icons.location_disabled_outlined,
        title: 'ไม่ได้รับสิทธิ์ตำแหน่ง',
        message: 'ResQ ต้องใช้ตำแหน่งปัจจุบันเพื่อส่งพิกัดให้ทีมกู้ภัย',
        actionLabel: 'ลองขอสิทธิ์อีกครั้ง',
        onAction: () async {
          await _locationController.retry();
        },
      );
    }

    // ==================================================
    // Other Error
    // ==================================================

    return _LocationProblemCard(
      icon: Icons.error_outline,
      title: 'ไม่สามารถระบุตำแหน่งได้',
      message:
          _locationController.errorMessage ?? 'กรุณาลองระบุตำแหน่งใหม่อีกครั้ง',
      actionLabel: 'ลองใหม่',
      onAction: () async {
        await _locationController.retry();
      },
    );
  }

  // ==================================================
  // Submit
  // ==================================================

  Future<void> _submitEmergencyRequest() async {
    // ==================================================
    // Prevent Double Submit
    // ==================================================

    if (!_canSubmit) {
      return;
    }

    // ปิด Keyboard
    FocusScope.of(context).unfocus();

    // ==================================================
    // 1. Validate Situation และข้อความสรุป
    // ==================================================

    final situationError = EmergencyRequestValidator.validateSituationSelection(
      _selectedSituations,
    );

    if (situationError != null) {
      _showErrorSnackBar(situationError);

      return;
    }

    final additionalDetailError =
        EmergencyRequestValidator.validateOtherSituationDetail(
          otherSelected: _selectedSituations.contains(EmergencySituation.other),
          value: _detailController.text,
        );

    if (additionalDetailError != null) {
      _showErrorSnackBar(additionalDetailError);

      return;
    }

    final requestDetail = _buildRequestDetail();
    final detailError = EmergencyRequestValidator.validateDetail(requestDetail);

    if (detailError != null) {
      _showErrorSnackBar(detailError);

      return;
    }

    final affectedCountError = EmergencyRequestValidator.validateAffectedCount(
      _affectedCount,
    );
    if (affectedCountError != null) {
      _showErrorSnackBar(affectedCountError);
      return;
    }

    // ==================================================
    // 2. Emergency Info
    // ==================================================

    if (!_emergencyInfoController.isReady) {
      _showErrorSnackBar('ข้อมูลผู้ประสบภัยยังไม่พร้อม');

      return;
    }

    // ==================================================
    // 3. Current Location
    // ==================================================

    if (_locationController.position == null) {
      _showErrorSnackBar('ไม่พบตำแหน่งปัจจุบัน');

      return;
    }

    setState(() {
      _isPreparingSubmit = true;
    });

    try {
      // ==================================================
      // 4. Fresh Disaster Validation
      //
      // Query Active Disaster Event ใหม่ 1 ครั้ง
      //
      // เพื่อป้องกัน:
      //
      // เปิดหน้า SOS ตอน Event Active
      // แต่ก่อน Submit Event ถูกปิด
      // ==================================================

      final freshDisaster = await _locationController
          .validateCurrentDisasterBeforeSubmit();

      if (!mounted) {
        return;
      }

      if (freshDisaster == null) {
        _showErrorSnackBar(
          'ไม่พบเหตุภัยพิบัติที่กำลังเกิดขึ้นในตำแหน่งปัจจุบัน '
          'กรุณาตรวจสอบตำแหน่งอีกครั้ง',
        );

        return;
      }

      // ==================================================
      // 5. Latest Position
      // ==================================================

      final latestPosition = _locationController.position;

      if (latestPosition == null) {
        _showErrorSnackBar('ไม่สามารถระบุตำแหน่งล่าสุดได้');

        return;
      }

      // ==================================================
      // จบ Preparing
      //
      // หลังจากนี้ Submit Controller
      // จะเป็นคนจัดการ Loading
      // ==================================================

      if (mounted) {
        setState(() {
          _isPreparingSubmit = false;
        });
      }

      // ==================================================
      // 6. Submit
      //
      // Flow:
      //
      // Firestore EmergencyRequest
      //        ↓
      // requestStatus = WAITING
      //        ↓
      // มีรูป?
      //        ↓
      // Cloudinary Upload
      //        ↓
      // Update requestImage
      // ==================================================

      final result = await _submitController.submit(
        disasterEvent: freshDisaster,
        latitude: latestPosition.latitude,
        longitude: latestPosition.longitude,
        requestDetail: requestDetail,
        situationTags: _orderedSelectedSituations
            .map((situation) => situation.code)
            .toList(growable: false),
        affectedCount: _affectedCount,
        image: _cameraController.image,
      );

      if (!mounted) {
        return;
      }

      // ==================================================
      // Request Failed
      // ==================================================

      if (result == null) {
        _showErrorSnackBar(
          _submitController.errorMessage ??
              'ไม่สามารถส่งคำร้องขอความช่วยเหลือได้',
        );

        return;
      }

      // พบคำร้องเดิมระหว่างตรวจซ้ำก่อน create
      // ไม่แสดง popup ว่าสร้างใหม่สำเร็จ แต่กลับไป Tracking เดิมทันที
      if (result.reusedActiveRequest) {
        context.goNamed(
          AppRouteNames.emergencyTracking,
          pathParameters: {'requestId': result.request.requestId},
        );

        return;
      }

      // ==================================================
      // 7. Success Popup
      // ==================================================

      await _showSubmitSuccessDialog(
        requestId: result.request.requestId,
        warningMessage: result.warningMessage,
      );

      if (!mounted) {
        return;
      }

      // ==================================================
      // 8. Monitor Rescue Progress
      // ==================================================

      context.goNamed(
        AppRouteNames.emergencyTracking,
        pathParameters: {'requestId': result.request.requestId},
      );
    } on CurrentDisasterEventException catch (error) {
      if (!mounted) {
        return;
      }

      _showErrorSnackBar(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showErrorSnackBar('เกิดข้อผิดพลาดในการส่งคำร้องขอความช่วยเหลือ');
    } finally {
      if (mounted && _isPreparingSubmit) {
        setState(() {
          _isPreparingSubmit = false;
        });
      }
    }
  }

  // ==================================================
  // Success Dialog
  // ==================================================

  Future<void> _showSubmitSuccessDialog({
    required String requestId,
    String? warningMessage,
  }) async {
    final hasWarning =
        warningMessage != null && warningMessage.trim().isNotEmpty;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return SuccessAlertDialog(
          title: 'ส่งคำร้องสำเร็จ',
          message: hasWarning
              ? 'ระบบได้รับคำร้องขอความช่วยเหลือแล้ว\n\n'
                    '$warningMessage'
              : 'ระบบได้รับคำร้องขอความช่วยเหลือแล้ว '
                    'กรุณารอเจ้าหน้าที่กู้ภัยรับเรื่อง',
          icon: hasWarning
              ? Icons.warning_amber_rounded
              : Icons.check_circle_rounded,
          iconColor: hasWarning ? AppColors.warning : AppColors.success,
          messageColor: hasWarning
              ? AppColors.warningDark
              : AppColors.lightTextPrimary,
          onConfirm: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }

  // ==================================================
  // Error SnackBar
  // ==================================================

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ==================================================
  // Bottom Submit Bar
  // ==================================================

  Widget _buildSubmitBar() {
    final theme = Theme.of(context);

    return Material(
      elevation: 10,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              // ==================================================
              // Action
              // ==================================================
              onPressed: _canSubmit ? _submitEmergencyRequest : null,

              // ==================================================
              // Style
              // ==================================================
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emergency,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              // ==================================================
              // Icon
              // ==================================================
              icon: _isSubmitBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : _submitController.isSuccess
                  ? const Icon(Icons.check_circle_outline)
                  : const Icon(Icons.warning_amber_rounded),

              // ==================================================
              // Label
              // ==================================================
              label: Text(
                _submitButtonLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================
// Location Problem Card
// ====================================================

class _LocationProblemCard extends StatelessWidget {
  const _LocationProblemCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;

  final String title;

  final String message;

  final String actionLabel;

  final VoidCallback onAction;

  final String? secondaryActionLabel;

  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // ==================================================
          // Icon
          // ==================================================
          Icon(icon, size: 30, color: theme.colorScheme.onErrorContainer),

          const SizedBox(height: 8),

          // ==================================================
          // Title
          // ==================================================
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),

          const SizedBox(height: 5),

          // ==================================================
          // Message
          // ==================================================
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),

          const SizedBox(height: 12),

          // ==================================================
          // Buttons
          // ==================================================
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: onAction, child: Text(actionLabel)),

              if (secondaryActionLabel != null)
                OutlinedButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
