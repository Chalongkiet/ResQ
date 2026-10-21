import 'package:flutter/foundation.dart';

import '../../data/services/emergency_info_service.dart';

enum EmergencyInfoSetupStatus { checking, required, completed, error }

class EmergencyInfoSetupController extends ChangeNotifier {
  EmergencyInfoSetupController({EmergencyInfoService? service})
    : _service = service ?? EmergencyInfoService();

  final EmergencyInfoService _service;

  EmergencyInfoSetupStatus _status = EmergencyInfoSetupStatus.checking;

  EmergencyInfoSetupStatus get status => _status;

  bool get isChecking => _status == EmergencyInfoSetupStatus.checking;

  bool get isRequired => _status == EmergencyInfoSetupStatus.required;

  bool get isCompleted => _status == EmergencyInfoSetupStatus.completed;

  bool get hasError => _status == EmergencyInfoSetupStatus.error;

  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    _setStatus(EmergencyInfoSetupStatus.checking);

    try {
      final exists = await _service.exists();

      _setStatus(
        exists
            ? EmergencyInfoSetupStatus.completed
            : EmergencyInfoSetupStatus.required,
      );
    } catch (error) {
      debugPrint('Emergency info setup check failed: $error');

      _setStatus(EmergencyInfoSetupStatus.error);
    }
  }

  void markCompleted() {
    _setStatus(EmergencyInfoSetupStatus.completed);
  }

  void _setStatus(EmergencyInfoSetupStatus status) {
    if (_status == status) {
      return;
    }

    _status = status;
    notifyListeners();
  }
}
