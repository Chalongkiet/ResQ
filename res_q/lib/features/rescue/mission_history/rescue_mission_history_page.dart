import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/rescue_mission_history_item.dart';
import 'controllers/rescue_mission_history_controller.dart';

const List<String> _thaiMonthNames = <String>[
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

class RescueMissionHistoryPage extends StatefulWidget {
  const RescueMissionHistoryPage({super.key, required this.rescueTeamId});

  final String rescueTeamId;

  @override
  State<RescueMissionHistoryPage> createState() =>
      _RescueMissionHistoryPageState();
}

class _RescueMissionHistoryPageState extends State<RescueMissionHistoryPage> {
  late final RescueMissionHistoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RescueMissionHistoryController();
    _controller.load(widget.rescueTeamId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการช่วยเหลือผู้ประสบภัย')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading && _controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.hasError && _controller.items.isEmpty) {
      return _HistoryProblemState(
        message: _controller.errorMessage!,
        onRetry: () => _controller.load(widget.rescueTeamId),
      );
    }

    final items = _controller.filteredItems;
    return RefreshIndicator(
      onRefresh: () => _controller.load(widget.rescueTeamId),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _HistoryFilters(
            selected: _controller.selectedFilter,
            onSelected: _controller.selectFilter,
          ),
          const SizedBox(height: 14),
          _HistoryDropdownFilters(controller: _controller),
          const SizedBox(height: 12),
          _SafetyTotalCard(
            totalAffected: _controller.totalSafetyConfirmedAffected,
            selectedYear: _controller.selectedYear,
            selectedMonth: _controller.selectedMonth,
            selectedDisasterLabel: _controller.selectedDisasterLabel,
          ),
          const SizedBox(height: 18),
          if (_controller.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _controller.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 72),
              child: _EmptyHistoryState(),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryCard(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryDropdownFilters extends StatelessWidget {
  const _HistoryDropdownFilters({required this.controller});

  final RescueMissionHistoryController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 21,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'กรองประวัติการช่วยเหลือ',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('history-year-${controller.selectedYear}'),
                  initialValue: controller.selectedYear,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'ปี',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  hint: const Text('เลือกปี'),
                  items: controller.availableYears
                      .map(
                        (year) => DropdownMenuItem(
                          value: year,
                          child: Text('${year + 543}'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: controller.availableYears.isEmpty
                      ? null
                      : controller.selectYear,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey(
                    'history-month-${controller.selectedYear}-'
                    '${controller.selectedMonth}',
                  ),
                  initialValue: controller.selectedMonth,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'เดือน',
                    prefixIcon: Icon(Icons.date_range_outlined),
                  ),
                  hint: const Text('เลือกเดือน'),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('รวมทั้งปี')),
                    for (final month in controller.availableMonths)
                      DropdownMenuItem(
                        value: month,
                        child: Text(
                          _thaiMonthNames[month - 1],
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: controller.hasSelectedYear
                      ? controller.selectMonth
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey(
              'history-disaster-${controller.selectedYear}-'
              '${controller.selectedMonth}-'
              '${controller.selectedDisasterEventId}',
            ),
            initialValue: controller.selectedDisasterEventId ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'เหตุการณ์ภัยพิบัติ',
              prefixIcon: Icon(Icons.warning_amber_rounded),
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('ทุกเหตุการณ์ภัยพิบัติ'),
              ),
              ...controller.availableDisasters.map(
                (option) => DropdownMenuItem(
                  value: option.eventId,
                  child: Text(
                    option.displayLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: controller.hasSelectedMonth
                ? controller.selectDisasterEvent
                : null,
          ),
        ],
      ),
    );
  }
}

class _SafetyTotalCard extends StatelessWidget {
  const _SafetyTotalCard({
    required this.totalAffected,
    required this.selectedYear,
    required this.selectedMonth,
    required this.selectedDisasterLabel,
  });

  final int totalAffected;
  final int? selectedYear;
  final int? selectedMonth;
  final String selectedDisasterLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final yearLabel = selectedYear == null
        ? 'ยังไม่ได้เลือก'
        : '${selectedYear! + 543}';
    final monthLabel = switch (selectedMonth) {
      null => 'ยังไม่ได้เลือก',
      0 => 'รวมทั้งปี',
      final month when month >= 1 && month <= DateTime.monthsPerYear =>
        _thaiMonthNames[month - 1],
      _ => 'ไม่ทราบเดือน',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.success.withValues(alpha: 0.14)
            : AppColors.lightSuccessContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withValues(alpha: isDark ? 0.65 : 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.success,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ผู้ประสบภัยที่ช่วยเหลือปลอดภัยแล้ว',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$totalAffected คน',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'ปี: $yearLabel  •  เดือน: $monthLabel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'เหตุการณ์: $selectedDisasterLabel',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({required this.selected, required this.onSelected});

  final RescueMissionHistoryFilter selected;
  final ValueChanged<RescueMissionHistoryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'ทั้งหมด',
            selected: selected == RescueMissionHistoryFilter.all,
            onSelected: () => onSelected(RescueMissionHistoryFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'ปลอดภัยแล้ว',
            selected: selected == RescueMissionHistoryFilter.safetyConfirmed,
            onSelected: () =>
                onSelected(RescueMissionHistoryFilter.safetyConfirmed),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'รอยืนยันความปลอดภัย',
            selected: selected == RescueMissionHistoryFilter.awaitingSafety,
            onSelected: () =>
                onSelected(RescueMissionHistoryFilter.awaitingSafety),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFFDCFCE7),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF166534) : null,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final RescueMissionHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSafe = item.isSafetyConfirmed;
    final statusColor = isSafe
        ? const Color(0xFF16A34A)
        : const Color(0xFFEA580C);
    final totalAffected = item.mission.totalAffected;

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.mission.missionName.isEmpty
                        ? item.request.requestType
                        : item.mission.missionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDate(item.completedAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'ผู้ประสบภัย: ${item.displayVictimName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'ประเภทคำร้อง: ${item.request.requestType}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'ภัยพิบัติ: ${item.displayDisasterEventName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (totalAffected != null) ...[
              const SizedBox(height: 3),
              Text(
                'ช่วยเหลือผู้ประสบภัย $totalAffected คน',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                const Text(
                  'สถานะ:',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Icon(
                  isSafe
                      ? Icons.verified_user_rounded
                      : Icons.hourglass_top_rounded,
                  size: 18,
                  color: statusColor,
                ),
                const SizedBox(width: 5),
                Text(
                  isSafe ? 'ปลอดภัยแล้ว' : 'รอยืนยันความปลอดภัย',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return 'ไม่ระบุวันที่';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year + 543}';
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text('ยังไม่มีประวัติภารกิจในประเภทนี้'),
        ],
      ),
    );
  }
}

class _HistoryProblemState extends StatelessWidget {
  const _HistoryProblemState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
          ],
        ),
      ),
    );
  }
}
