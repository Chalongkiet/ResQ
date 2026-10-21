enum EmergencySituation {
  trapped('TRAPPED', 'ติดอยู่ในพื้นที่'),
  injured('INJURED_OR_ILL', 'มีผู้บาดเจ็บหรือเจ็บป่วย'),
  child('HAS_CHILD', 'มีเด็กเล็ก'),
  elderly('HAS_ELDERLY', 'มีผู้สูงอายุ'),
  worsening('SITUATION_WORSENING', 'สถานการณ์กำลังรุนแรงขึ้น'),
  urgentEvacuation('URGENT_EVACUATION', 'ต้องการอพยพเร่งด่วน'),
  other('OTHER', 'อื่น ๆ');

  const EmergencySituation(this.code, this.label);

  final String code;
  final String label;
}

abstract final class EmergencySituationSummary {
  static String build({
    required Iterable<EmergencySituation> situations,
    String? additionalDetail,
  }) {
    final labels = situations.map((situation) => situation.label).toList();
    final detail = additionalDetail?.trim() ?? '';

    final sections = <String>[
      if (labels.isNotEmpty) labels.join(' • '),
      if (detail.isNotEmpty) 'รายละเอียด: $detail',
    ];

    return sections.join('\n');
  }

  EmergencySituationSummary._();
}
