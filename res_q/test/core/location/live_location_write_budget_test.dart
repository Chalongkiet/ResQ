import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/core/location/live_location_write_budget.dart';

void main() {
  group('LiveLocationWriteBudget', () {
    test('stops reservations at the configured 24-hour cap', () async {
      final store = _MemoryBudgetStore();
      final now = DateTime(2026, 8, 26, 9);
      final budget = LiveLocationWriteBudget(
        store: store,
        maximumWritesPerWindow: 3,
        clock: () => now,
      );

      expect(await budget.tryReserve(deploymentId: 'deployment-1'), isTrue);
      expect(await budget.tryReserve(deploymentId: 'deployment-1'), isTrue);
      expect(await budget.tryReserve(deploymentId: 'deployment-1'), isTrue);
      expect(await budget.tryReserve(deploymentId: 'deployment-1'), isFalse);
    });

    test('starts a new budget after 24 hours', () async {
      final store = _MemoryBudgetStore();
      var now = DateTime(2026, 8, 26, 9);
      final budget = LiveLocationWriteBudget(
        store: store,
        maximumWritesPerWindow: 1,
        clock: () => now,
      );

      expect(await budget.tryReserve(deploymentId: 'deployment-1'), isTrue);
      expect(await budget.tryReserve(deploymentId: 'deployment-1'), isFalse);

      now = now.add(const Duration(hours: 24));

      expect(await budget.tryReserve(deploymentId: 'deployment-1'), isTrue);
    });

    test('keeps independent budgets for different deployments', () async {
      final budget = LiveLocationWriteBudget(
        store: _MemoryBudgetStore(),
        maximumWritesPerWindow: 1,
      );

      expect(await budget.tryReserve(deploymentId: 'deployment-1'), isTrue);
      expect(await budget.tryReserve(deploymentId: 'deployment-1'), isFalse);
      expect(await budget.tryReserve(deploymentId: 'deployment-2'), isTrue);
    });
  });
}

class _MemoryBudgetStore implements LiveLocationBudgetStore {
  final Map<String, int> _values = <String, int>{};

  @override
  Future<int?> getInt(String key) async => _values[key];

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }
}
