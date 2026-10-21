import 'package:flutter/foundation.dart';

import '../models/rescue_deployment.dart';
import '../models/rescue_member.dart';
import '../models/rescue_vehicle.dart';
import '../services/exceptions/join_disaster_event_exception.dart';
import '../services/exceptions/rescue_location_exception.dart';
import '../services/join_disaster_event_service.dart';
import '../services/rescue_location_service.dart';
import '../services/rescue_resource_service.dart';

class JoinDisasterEventController extends ChangeNotifier {
  JoinDisasterEventController({
    RescueResourceService? resourceService,
    JoinDisasterEventService? joinService,
    RescueLocationService? locationService,
  }) : _resourceService = resourceService ?? RescueResourceService(),
       _joinService = joinService ?? JoinDisasterEventService(),
       _locationService = locationService ?? const RescueLocationService();

  final RescueResourceService _resourceService;

  final JoinDisasterEventService _joinService;

  final RescueLocationService _locationService;

  // ==================================================
  // Resource loading
  // ==================================================

  bool _isLoading = false;

  String? _errorMessage;

  List<RescueMember> _members = [];

  List<RescueVehicle> _vehicles = [];

  // ==================================================
  // Selection
  // ==================================================

  final List<RescueMember> _selectedMembers = [];

  final List<RescueVehicle> _selectedVehicles = [];

  // ==================================================
  // Submit
  // ==================================================

  bool _isSubmitting = false;

  String? _submitErrorMessage;

  RescueDeployment? _deployment;

  // ==================================================
  // Getters
  // ==================================================

  bool get isLoading => _isLoading;

  bool get isSubmitting => _isSubmitting;

  String? get errorMessage => _errorMessage;

  String? get submitErrorMessage => _submitErrorMessage;

  RescueDeployment? get deployment => _deployment;

  List<RescueMember> get members => List.unmodifiable(_members);

  List<RescueVehicle> get vehicles => List.unmodifiable(_vehicles);

  List<RescueMember> get selectedMembers => List.unmodifiable(_selectedMembers);

  List<RescueVehicle> get selectedVehicles =>
      List.unmodifiable(_selectedVehicles);

  bool get hasSelectedMembers => _selectedMembers.isNotEmpty;

  bool get hasSelectedVehicles => _selectedVehicles.isNotEmpty;

  // ==================================================
  // Load resources
  // ==================================================

  Future<void> load({required String rescueTeamId}) async {
    if (_isLoading) {
      debugPrint(
        '[JOIN CONTROLLER] load blocked: '
        'already loading',
      );

      return;
    }

    final teamId = rescueTeamId.trim();

    debugPrint('================================');

    debugPrint('[JOIN CONTROLLER] LOAD START');

    debugPrint('[JOIN CONTROLLER] teamId=$teamId');

    if (teamId.isEmpty) {
      _errorMessage = 'ไม่พบข้อมูลหน่วยกู้ภัย';

      notifyListeners();

      return;
    }

    _isLoading = true;

    _errorMessage = null;

    notifyListeners();

    try {
      debugPrint(
        '[JOIN CONTROLLER] '
        'requesting resources...',
      );

      final resources = await _resourceService.getResources(
        rescueTeamId: teamId,
      );

      debugPrint(
        '[JOIN CONTROLLER] '
        'resources received',
      );

      _members = resources.members;

      _vehicles = resources.vehicles;

      debugPrint(
        '[JOIN CONTROLLER] '
        'members=${_members.length}',
      );

      debugPrint(
        '[JOIN CONTROLLER] '
        'vehicles=${_vehicles.length}',
      );
    } catch (error, stackTrace) {
      debugPrint('[JOIN CONTROLLER] LOAD ERROR');

      debugPrint('[JOIN CONTROLLER] $error');

      debugPrint('[JOIN CONTROLLER] $stackTrace');

      _errorMessage =
          'ไม่สามารถโหลดข้อมูลสมาชิก'
          'และยานพาหนะได้';
    } finally {
      _isLoading = false;

      debugPrint('[JOIN CONTROLLER] LOAD FINISHED');

      debugPrint('================================');

      notifyListeners();
    }
  }

  // ==================================================
  // Vehicle
  // ==================================================

  void addVehicle(RescueVehicle vehicle) {
    if (_isSubmitting) {
      return;
    }

    final exists = _selectedVehicles.any(
      (item) => item.vehicleId == vehicle.vehicleId,
    );

    if (exists) {
      return;
    }

    _selectedVehicles.add(vehicle);

    notifyListeners();
  }

  void removeVehicle(String vehicleId) {
    if (_isSubmitting) {
      return;
    }

    _selectedVehicles.removeWhere((vehicle) => vehicle.vehicleId == vehicleId);

    notifyListeners();
  }

  // ==================================================
  // Member
  // ==================================================

  void addMember(RescueMember member) {
    if (_isSubmitting) {
      return;
    }

    final exists = _selectedMembers.any(
      (item) => item.memberId == member.memberId,
    );

    if (exists) {
      return;
    }

    _selectedMembers.add(member);

    notifyListeners();
  }

  void removeMember(String memberId) {
    if (_isSubmitting) {
      return;
    }

    _selectedMembers.removeWhere((member) => member.memberId == memberId);

    notifyListeners();
  }

  // ==================================================
  // Validation
  // ==================================================

  String? validateSelection() {
    if (_selectedVehicles.isEmpty) {
      return 'กรุณาเลือกยานพาหนะอย่างน้อย 1 คัน';
    }

    if (_selectedMembers.isEmpty) {
      return 'กรุณาเลือกสมาชิกกู้ภัยอย่างน้อย 1 คน';
    }

    return null;
  }

  // ==================================================
  // Submit Join
  // ==================================================

  Future<RescueDeployment?> submit({
    required String eventId,
    required String rescueTeamId,
  }) async {
    if (_isSubmitting) {
      return null;
    }

    final validationMessage = validateSelection();

    if (validationMessage != null) {
      _submitErrorMessage = validationMessage;

      notifyListeners();

      return null;
    }

    _isSubmitting = true;
    _submitErrorMessage = null;
    _deployment = null;

    notifyListeners();

    try {
      // ==============================================
      // GPS
      // ==============================================

      final position = await _locationService.getCurrentPosition();

      // ==============================================
      // Join
      // ==============================================

      final result = await _joinService.join(
        eventId: eventId,
        rescueTeamId: rescueTeamId,

        memberIds: _selectedMembers.map((member) => member.memberId).toList(),

        vehicleIds: _selectedVehicles
            .map((vehicle) => vehicle.vehicleId)
            .toList(),

        latitude: position.latitude,

        longitude: position.longitude,
      );

      _deployment = result;

      return result;
    } on RescueLocationException catch (error) {
      _submitErrorMessage = error.message;

      return null;
    } on AlreadyJoinedDisasterEventException catch (error) {
      _submitErrorMessage = error.message;

      return null;
    } on JoinDisasterEventException catch (error) {
      _submitErrorMessage = error.message;

      return null;
    } catch (_) {
      _submitErrorMessage = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';

      return null;
    } finally {
      _isSubmitting = false;

      notifyListeners();
    }
  }

  // ==================================================
  // Clear
  // ==================================================

  void clearSelections() {
    if (_isSubmitting) {
      return;
    }

    _selectedMembers.clear();
    _selectedVehicles.clear();

    notifyListeners();
  }
}
