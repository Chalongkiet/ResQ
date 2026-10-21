import 'package:flutter/foundation.dart';

import '../../../../data/models/rescue_mission_history_item.dart';
import '../../../../data/services/rescue_mission_history_service.dart';

class RescueMissionHistoryController extends ChangeNotifier {
  RescueMissionHistoryController({
    RescueMissionHistoryService? historyService,
    DateTime? referenceDate,
  }) : _historyService = historyService ?? RescueMissionHistoryService(),
       _referenceDate = (referenceDate ?? DateTime.now()).toLocal();

  final RescueMissionHistoryService _historyService;
  final DateTime _referenceDate;

  List<RescueMissionHistoryItem> _items = const <RescueMissionHistoryItem>[];
  RescueMissionHistoryFilter _selectedFilter = RescueMissionHistoryFilter.all;
  int? _selectedYear;
  int? _selectedMonth;
  String? _selectedDisasterEventId;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  List<RescueMissionHistoryItem> get items => List.unmodifiable(_items);
  RescueMissionHistoryFilter get selectedFilter => _selectedFilter;
  int? get selectedYear => _selectedYear;
  int? get selectedMonth => _selectedMonth;
  String? get selectedDisasterEventId => _selectedDisasterEventId;
  bool get hasSelectedMonth => _selectedMonth != null;
  bool get hasSelectedYear => _selectedYear != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  List<RescueMissionHistoryItem> get periodAndDisasterFilteredItems {
    if (_selectedYear == null || _selectedMonth == null) {
      return const <RescueMissionHistoryItem>[];
    }

    return RescueMissionHistoryService.filterByPeriodAndDisaster(
      _items,
      year: _selectedYear,
      month: _selectedMonth == 0 ? null : _selectedMonth,
      disasterEventId: _selectedDisasterEventId,
    );
  }

  List<RescueMissionHistoryItem> get filteredItems =>
      RescueMissionHistoryService.filter(
        periodAndDisasterFilteredItems,
        _selectedFilter,
      );

  int get totalSafetyConfirmedAffected =>
      RescueMissionHistoryService.totalSafetyConfirmedAffected(
        periodAndDisasterFilteredItems,
      );

  List<int> get availableYears {
    return List<int>.unmodifiable(
      List<int>.generate(3, (index) => _referenceDate.year - index),
    );
  }

  List<int> get availableMonths {
    if (_selectedYear == null) return const <int>[];
    return List<int>.unmodifiable(
      List<int>.generate(DateTime.monthsPerYear, (index) => index + 1),
    );
  }

  String get selectedDisasterLabel {
    if (_selectedYear == null || _selectedMonth == null) {
      return 'ยังไม่ได้เลือกเหตุการณ์';
    }

    final eventId = _selectedDisasterEventId;
    if (eventId == null || eventId.isEmpty) {
      return 'ทุกเหตุการณ์ภัยพิบัติ';
    }

    for (final option in availableDisasters) {
      if (option.eventId == eventId) {
        return option.displayLabel;
      }
    }

    return 'เหตุการณ์ที่เลือก';
  }

  List<RescueMissionHistoryDisasterOption> get availableDisasters {
    if (_selectedYear == null || _selectedMonth == null) {
      return const <RescueMissionHistoryDisasterOption>[];
    }

    final itemsInPeriod = RescueMissionHistoryService.filterByPeriodAndDisaster(
      _items,
      year: _selectedYear,
      month: _selectedMonth == 0 ? null : _selectedMonth,
    );
    final optionsById = <String, RescueMissionHistoryDisasterOption>{};

    for (final item in itemsInPeriod) {
      final eventId = item.request.disasterEventId.trim();
      if (eventId.isEmpty) continue;
      optionsById[eventId] = RescueMissionHistoryDisasterOption(
        eventId: eventId,
        eventName: item.displayDisasterEventName,
        disasterType: item.request.requestType,
      );
    }

    final options = optionsById.values.toList();
    options.sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
    return List.unmodifiable(options);
  }

  Future<void> load(String rescueTeamId) async {
    if (_disposed || _isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      _items = await _historyService.loadCompletedForRescueTeam(rescueTeamId);
      _selectLatestAvailablePeriod();
    } on RescueMissionHistoryException catch (error) {
      _errorMessage = error.message;
    } catch (error, stackTrace) {
      debugPrint('Load rescue mission history failed: $error');
      debugPrint('$stackTrace');
      _errorMessage = 'ไม่สามารถโหลดประวัติภารกิจได้';
    } finally {
      if (!_disposed) {
        _isLoading = false;
        _notify();
      }
    }
  }

  void selectFilter(RescueMissionHistoryFilter filter) {
    if (_disposed || _selectedFilter == filter) return;
    _selectedFilter = filter;
    _notify();
  }

  void selectYear(int? year) {
    if (_disposed || _selectedYear == year) return;
    _selectedYear = year;
    _selectedMonth = null;
    _selectedDisasterEventId = null;
    _notify();
  }

  void selectMonth(int? month) {
    if (_disposed || _selectedYear == null || _selectedMonth == month) return;
    _selectedMonth = month;
    _selectedDisasterEventId = null;
    _notify();
  }

  void selectDisasterEvent(String? eventId) {
    if (_selectedYear == null || _selectedMonth == null) return;

    final normalized = eventId?.trim();
    final value = normalized == null || normalized.isEmpty ? null : normalized;
    if (_disposed || _selectedDisasterEventId == value) return;
    _selectedDisasterEventId = value;
    _notify();
  }

  void _selectLatestAvailablePeriod() {
    final supportedYears = availableYears.toSet();
    final completedDates =
        _items
            .map((item) => item.completedAt?.toLocal())
            .whereType<DateTime>()
            .where((date) => supportedYears.contains(date.year))
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final latestDate = completedDates.isEmpty
        ? _referenceDate
        : completedDates.first;

    _selectedYear = latestDate.year;
    _selectedMonth = latestDate.month;
    _selectedDisasterEventId = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
