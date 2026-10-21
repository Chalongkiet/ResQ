import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/core/constants/mission_result.dart';

void main() {
  test('mission result exposes only pending and success values', () {
    expect(MissionResult.values, <String>[
      MissionResult.pending,
      MissionResult.success,
    ]);
    expect(MissionResult.isValid('PENDING'), isTrue);
    expect(MissionResult.isValid('SUCCESS'), isTrue);
    expect(MissionResult.isValid('COMPLETED'), isFalse);
  });
}
