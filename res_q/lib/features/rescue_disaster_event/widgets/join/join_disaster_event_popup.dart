import 'package:flutter/material.dart';

import '../../../../data/models/disaster_event_model.dart';
import '../../controllers/join_disaster_event_controller.dart';
import '../../models/rescue_deployment.dart';
import '../../models/rescue_member.dart';
import '../../models/rescue_vehicle.dart';

import 'join_resource_picker.dart';

// ==================================================
// Open Join Disaster Event Popup
// ==================================================

Future<RescueDeployment?> showJoinDisasterEventPopup({
  required BuildContext context,
  required DisasterEvent event,
  required String rescueTeamId,
  required JoinDisasterEventController controller,
}) async {
  debugPrint('================================');
  debugPrint('[JOIN POPUP] OPEN');
  debugPrint('[JOIN POPUP] event=${event.id}');
  debugPrint('[JOIN POPUP] team=$rescueTeamId');
  debugPrint('[JOIN POPUP] members=${controller.members.length}');
  debugPrint('[JOIN POPUP] vehicles=${controller.vehicles.length}');

  // เปิด popup ใหม่ = เริ่มจากยังไม่ได้เลือก resource
  controller.clearSelections();

  return showDialog<RescueDeployment>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      debugPrint('[JOIN POPUP] builder entered');

      return _JoinDisasterEventPopupContent(
        event: event,
        rescueTeamId: rescueTeamId,
        controller: controller,
      );
    },
  );
}

// ==================================================
// Popup Content
// ==================================================

class _JoinDisasterEventPopupContent extends StatefulWidget {
  const _JoinDisasterEventPopupContent({
    required this.event,
    required this.rescueTeamId,
    required this.controller,
  });

  final DisasterEvent event;
  final String rescueTeamId;
  final JoinDisasterEventController controller;

  @override
  State<_JoinDisasterEventPopupContent> createState() =>
      _JoinDisasterEventPopupContentState();
}

// ==================================================
// Popup State
// ==================================================

class _JoinDisasterEventPopupContentState
    extends State<_JoinDisasterEventPopupContent> {
  bool _isSubmitting = false;

  String? _errorMessage;

  JoinDisasterEventController get _controller => widget.controller;

  // ==================================================
  // Lifecycle
  // ==================================================

  @override
  void initState() {
    super.initState();

    debugPrint('[JOIN POPUP] StatefulWidget initState');
  }

  @override
  void dispose() {
    debugPrint('[JOIN POPUP] StatefulWidget dispose');

    // สำคัญ:
    // ห้าม dispose controller ที่นี่
    // เพราะ RescueDisasterEventPage เป็นเจ้าของ controller ตัวนี้

    super.dispose();
  }

  // ==================================================
  // Select Vehicle
  // ==================================================

  Future<void> _selectVehicle() async {
    if (_isSubmitting) {
      return;
    }

    debugPrint('[JOIN POPUP] opening vehicle picker');

    final RescueVehicle? selectedVehicle = await showJoinVehiclePicker(
      context: context,
      vehicles: _controller.vehicles,
      selectedVehicleIds: _controller.selectedVehicles
          .map((vehicle) => vehicle.vehicleId)
          .toSet(),
    );

    if (!mounted || selectedVehicle == null) {
      return;
    }

    debugPrint(
      '[JOIN POPUP] vehicle selected='
      '${selectedVehicle.vehicleId}',
    );

    _controller.addVehicle(selectedVehicle);

    setState(() {
      _errorMessage = null;
    });
  }

  // ==================================================
  // Select Member
  // ==================================================

  Future<void> _selectMember() async {
    if (_isSubmitting) {
      return;
    }

    debugPrint('[JOIN POPUP] opening member picker');

    final RescueMember? selectedMember = await showJoinMemberPicker(
      context: context,
      members: _controller.members,
      selectedMemberIds: _controller.selectedMembers
          .map((member) => member.memberId)
          .toSet(),
    );

    if (!mounted || selectedMember == null) {
      return;
    }

    debugPrint(
      '[JOIN POPUP] member selected='
      '${selectedMember.memberId}',
    );

    _controller.addMember(selectedMember);

    setState(() {
      _errorMessage = null;
    });
  }

  // ==================================================
  // Remove Vehicle
  // ==================================================

  void _removeVehicle(String vehicleId) {
    if (_isSubmitting) {
      return;
    }

    _controller.removeVehicle(vehicleId);

    setState(() {
      _errorMessage = null;
    });
  }

  // ==================================================
  // Remove Member
  // ==================================================

  void _removeMember(String memberId) {
    if (_isSubmitting) {
      return;
    }

    _controller.removeMember(memberId);

    setState(() {
      _errorMessage = null;
    });
  }

  // ==================================================
  // Confirm Join
  // ==================================================

  Future<void> _confirm() async {
    if (_isSubmitting) {
      return;
    }

    // ==================================================
    // Validate Resource
    // ==================================================

    final validationMessage = _controller.validateSelection();

    if (validationMessage != null) {
      setState(() {
        _errorMessage = validationMessage;
      });

      return;
    }

    debugPrint('================================');
    debugPrint('[JOIN POPUP] CONFIRM');

    debugPrint(
      '[JOIN POPUP] vehicles='
      '${_controller.selectedVehicles.length}',
    );

    debugPrint(
      '[JOIN POPUP] members='
      '${_controller.selectedMembers.length}',
    );

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    // ==================================================
    // GPS + Firestore
    // ==================================================

    final RescueDeployment? deployment = await _controller.submit(
      eventId: widget.event.id,
      rescueTeamId: widget.rescueTeamId,
    );

    if (!mounted) {
      return;
    }

    // ==================================================
    // Failed
    // ==================================================

    if (deployment == null) {
      debugPrint('[JOIN POPUP] SUBMIT FAILED');

      debugPrint(
        '[JOIN POPUP] error='
        '${_controller.submitErrorMessage}',
      );

      setState(() {
        _isSubmitting = false;

        _errorMessage =
            _controller.submitErrorMessage ??
            'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
      });

      return;
    }

    // ==================================================
    // Success
    // ==================================================

    debugPrint('[JOIN POPUP] SUBMIT SUCCESS');

    debugPrint(
      '[JOIN POPUP] deployment='
      '${deployment.deploymentId}',
    );

    Navigator.of(context).pop(deployment);
  }

  // ==================================================
  // Close
  // ==================================================

  void _close() {
    if (_isSubmitting) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    debugPrint('[JOIN POPUP] StatefulWidget build');

    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);

    final popupWidth = (screenSize.width - 48).clamp(280.0, 420.0).toDouble();

    final popupHeight = (screenSize.height * 0.78)
        .clamp(460.0, 700.0)
        .toDouble();

    debugPrint('[JOIN POPUP] building Dialog');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: popupWidth,
        height: popupHeight,
        child: Column(
          children: [
            // ==================================================
            // Header
            // ==================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const SizedBox(width: 40),

                  Expanded(
                    child: Text(
                      'ยืนยันการเข้าร่วมภารกิจ',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'ปิด',
                    onPressed: _isSubmitting ? null : _close,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ==================================================
            // Scroll Content
            // ==================================================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==================================================
                    // Vehicle
                    // ==================================================
                    _buildSectionHeader(
                      title: 'ข้อมูลยานพาหนะ',
                      buttonText: 'เลือกยานพาหนะ',
                      onPressed: _isSubmitting ? null : _selectVehicle,
                    ),

                    const SizedBox(height: 12),

                    if (_controller.selectedVehicles.isEmpty)
                      const _EmptyResourceBox(
                        icon: Icons.local_shipping_outlined,
                        message: 'ยังไม่ได้เลือกยานพาหนะ',
                      )
                    else
                      ..._buildSelectedVehicles(),

                    const SizedBox(height: 28),

                    // ==================================================
                    // Member
                    // ==================================================
                    _buildSectionHeader(
                      title: 'รายชื่อผู้ปฏิบัติงาน',
                      buttonText: 'เลือกสมาชิก',
                      onPressed: _isSubmitting ? null : _selectMember,
                    ),

                    const SizedBox(height: 12),

                    if (_controller.selectedMembers.isEmpty)
                      const _EmptyResourceBox(
                        icon: Icons.groups_2_outlined,
                        message: 'ยังไม่ได้เลือกสมาชิก',
                      )
                    else
                      ..._buildSelectedMembers(),

                    // ==================================================
                    // Error
                    // ==================================================
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 18),

                      _ErrorBox(message: _errorMessage!),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // ==================================================
            // Confirm
            // ==================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _confirm,
                  child: _isSubmitting
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),

                            SizedBox(width: 10),

                            Text('กำลังเข้าร่วม...'),
                          ],
                        )
                      : const Text(
                          'ยืนยัน',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // Section Header
  // ==================================================

  Widget _buildSectionHeader({
    required String title,
    required String buttonText,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // ไม่ใช้ FilledButton ตรงนี้
        // เพราะ Button Theme ของแอปมีโอกาสบังคับ width = infinity
        Material(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Text(
                buttonText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: onPressed == null
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                      : theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================================================
  // Selected Vehicles
  // ==================================================

  List<Widget> _buildSelectedVehicles() {
    final vehicles = _controller.selectedVehicles;

    return List<Widget>.generate(vehicles.length, (index) {
      final vehicle = vehicles[index];

      return Padding(
        padding: EdgeInsets.only(bottom: index == vehicles.length - 1 ? 0 : 10),
        child: _SelectedVehicleCard(
          vehicle: vehicle,
          enabled: !_isSubmitting,
          onRemove: () {
            _removeVehicle(vehicle.vehicleId);
          },
        ),
      );
    });
  }

  // ==================================================
  // Selected Members
  // ==================================================

  List<Widget> _buildSelectedMembers() {
    final members = _controller.selectedMembers;

    return List<Widget>.generate(members.length, (index) {
      final member = members[index];

      return Padding(
        padding: EdgeInsets.only(bottom: index == members.length - 1 ? 0 : 10),
        child: _SelectedMemberCard(
          number: index + 1,
          member: member,
          enabled: !_isSubmitting,
          onRemove: () {
            _removeMember(member.memberId);
          },
        ),
      );
    });
  }
}

// ==================================================
// Empty Resource
// ==================================================

class _EmptyResourceBox extends StatelessWidget {
  const _EmptyResourceBox({required this.icon, required this.message});

  final IconData icon;

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// Selected Vehicle Card
// ==================================================

class _SelectedVehicleCard extends StatelessWidget {
  const _SelectedVehicleCard({
    required this.vehicle,
    required this.enabled,
    required this.onRemove,
  });

  final RescueVehicle vehicle;

  final bool enabled;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ประเภทยานพาหนะ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),

              IconButton(
                tooltip: 'ลบ',
                visualDensity: VisualDensity.compact,
                onPressed: enabled ? onRemove : null,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),

          _ValueBox(
            value: vehicle.vehicleType.trim().isEmpty
                ? '-'
                : vehicle.vehicleType,
          ),

          const SizedBox(height: 10),

          const Text(
            'ป้ายทะเบียน (ถ้ามี)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 5),

          _ValueBox(
            value: vehicle.vehiclePlate.trim().isEmpty
                ? '-'
                : vehicle.vehiclePlate,
          ),
        ],
      ),
    );
  }
}

// ==================================================
// Selected Member Card
// ==================================================

class _SelectedMemberCard extends StatelessWidget {
  const _SelectedMemberCard({
    required this.number,
    required this.member,
    required this.enabled,
    required this.onRemove,
  });

  final int number;

  final RescueMember member;

  final bool enabled;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            child: Text(
              '$number',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ชื่อ-นามสกุล',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 5),

                _ValueBox(
                  value: member.fullName.trim().isEmpty ? '-' : member.fullName,
                ),

                const SizedBox(height: 10),

                const Text(
                  'เบอร์โทร',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 5),

                _ValueBox(
                  value: member.phoneNumber.trim().isEmpty
                      ? '-'
                      : member.phoneNumber,
                ),

                const SizedBox(height: 10),

                const Text(
                  'ตำแหน่ง',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 5),

                _ValueBox(
                  value: member.position.trim().isEmpty ? '-' : member.position,
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'ลบ',
            visualDensity: VisualDensity.compact,
            onPressed: enabled ? onRemove : null,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// Value Box
// ==================================================

class _ValueBox extends StatelessWidget {
  const _ValueBox({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 38),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(value),
    );
  }
}

// ==================================================
// Error Box
// ==================================================

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: theme.colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
