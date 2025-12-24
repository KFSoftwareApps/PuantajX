import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/daily_report_model.dart';
import '../providers/report_providers.dart';

class ReportFilterState {
  final String searchQuery;
  final DateTimeRange? dateRange;
  final Set<ReportStatus>? selectedStatuses;

  const ReportFilterState({
    this.searchQuery = '',
    this.dateRange,
    this.selectedStatuses,
  });

  ReportFilterState copyWith({
    String? searchQuery,
    DateTimeRange? dateRange,
    Set<ReportStatus>? selectedStatuses,
  }) {
    return ReportFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      dateRange: dateRange ?? this.dateRange,
      selectedStatuses: selectedStatuses ?? this.selectedStatuses,
    );
  }
  
  bool get hasFilters => searchQuery.isNotEmpty || dateRange != null || (selectedStatuses != null && selectedStatuses!.isNotEmpty);
}

final reportFilterProvider = StateProvider<ReportFilterState>((ref) => const ReportFilterState());

final filteredReportsProvider = Provider.family<List<DailyReport>, int>((ref, projectId) {
  final allReportsAsync = ref.watch(projectReportsProvider(projectId));
  final filter = ref.watch(reportFilterProvider);

  return allReportsAsync.when(
    data: (reports) {
      return reports.where((report) {
        // 1. Text Search
        if (filter.searchQuery.isNotEmpty) {
          final query = filter.searchQuery.toLowerCase();
          final matchesId = report.id.toString().contains(query);
          final matchesNote = report.generalNote?.toLowerCase().contains(query) ?? false;
          // You could also search item descriptions if needed
          if (!matchesId && !matchesNote) return false;
        }

        // 2. Date Range
        if (filter.dateRange != null) {
          if (report.date.isBefore(filter.dateRange!.start) || report.date.isAfter(filter.dateRange!.end.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)))) {
             // Basic day check, ensure coverage of the full 'end' day
             return false;
          }
        }

        // 3. Status
        if (filter.selectedStatuses != null && filter.selectedStatuses!.isNotEmpty) {
          if (!filter.selectedStatuses!.contains(report.status)) return false;
        }

        return true;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
