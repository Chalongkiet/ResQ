class SosEmergencyInfoSummary {
  const SosEmergencyInfoSummary({
    required this.fullName,
    required this.phoneNumber,
    required this.bloodGroup,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.medicalCondition,
    this.allergy,
    this.regularMedication,
  });

  final String fullName;
  final String phoneNumber;
  final String bloodGroup;

  final String? medicalCondition;
  final String? allergy;
  final String? regularMedication;

  final String emergencyContactName;
  final String emergencyContactPhone;

  factory SosEmergencyInfoSummary.fromMap(Map<String, dynamic> data) {
    return SosEmergencyInfoSummary(
      fullName: _requiredString(data['fullName']),
      phoneNumber: _requiredString(data['phoneNumber']),
      bloodGroup: _requiredString(data['bloodGroup']),
      medicalCondition: _optionalString(data['medicalCondition']),
      allergy: _optionalString(data['allergy']),
      regularMedication: _optionalString(data['regularMedication']),
      emergencyContactName: _requiredString(data['emergencyContactName']),
      emergencyContactPhone: _requiredString(data['emergencyContactPhone']),
    );
  }

  static String _requiredString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _optionalString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  String displayValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }

    return value;
  }
}
