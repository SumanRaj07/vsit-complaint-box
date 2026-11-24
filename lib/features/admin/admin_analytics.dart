import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';

/// Analytics: complaints by category, by department, monthly trend,
/// priority distribution, department-wise resolution rates.
class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    final repo = ref.watch(repositoryProvider);
    final deptId = user?.isSuperAdmin == true ? null : user?.departmentId;
    final isWide = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analytics',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text(
            'Where complaints come from, how fast they close, and who is falling behind.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: Future.wait([
              repo.getComplaintsByCategory(departmentId: deptId),
              repo.getComplaintsByDepartment(),
              repo.getComplaintsByMonth(months: 6),
              repo.getComplaintsByPriority(),
              repo.getDepartmentResolutionRates(),
            ]),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Text('Error: ${snap.error}');
              }
              final data = snap.data as List;
              final byCategory = data[0] as Map<String, int>;
              final byDepartment = data[1] as Map<String, int>;
              final byMonth = data[2] as Map<String, int>;
              final byPriority = data[3] as Map<String, int>;
              final resolution = data[4] as Map<String, double>;
              final charts = [
                _ChartCard(
                  title: 'Complaints by category',
                  child: _BarChart(
                    entries: _topEntries(byCategory, 8),
                    color: AppTheme.navy,
                  ),
                ),
                _ChartCard(
                  title: 'Complaints by department',
                  child: _BarChart(
                    entries: _topEntries(byDepartment, 8),
                    color: AppTheme.accent,
                  ),
                ),
                _ChartCard(
                  title: 'Monthly trend (last 6 months)',
                  child: _BarChart(
                    entries: byMonth.entries
                        .map((e) => MapEntry(_monthLabel(e.key), e.value))
                        .toList(),
                    color: const Color(0xFF8E6CC8),
                  ),
                ),
                _ChartCard(
                  title: 'Priority distribution',
                  child: _PieChart(entries: byPriority),
                ),
                _ChartCard(
                  title: 'Department resolution rate (%)',
                  child: _BarChart(
                    entries: resolution.entries
                        .map((e) =>
                            MapEntry(e.key, e.value.round()))
                        .toList(),
                    color: AppTheme.success,
                    suffix: '%',
                  ),
                ),
              ];
              if (isWide) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: charts
                      .map((c) => SizedBox(
                          width: (MediaQuery.of(context).size.width - 260 - 60) / 2,
                          child: c))
                      .toList(),
                );
              }
              return Column(
                children: charts
                    .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: c))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

List<MapEntry<String, int>> _topEntries(Map<String, int> map, int n) {
  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(n).toList();
}

String _monthLabel(String key) {
  final parts = key.split('-');
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final m = int.tryParse(parts[1]) ?? 1;
  return months[(m - 1).clamp(0, 11)];
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            SizedBox(height: 220, child: child),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final Color color;
  final String suffix;
  const _BarChart({
    required this.entries,
    required this.color,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
          child: Text('No data yet.',
              style: TextStyle(color: AppTheme.textSecondary)));
    }
    final maxY =
        entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();
    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 1 : maxY * 1.2,
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.toDouble(),
                  color: color,
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                final label = entries[i].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label.length > 10
                        ? '${label.substring(0, 10)}…'
                        : label,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}$suffix',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  final Map<String, int> entries;
  const _PieChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
          child: Text('No data yet.',
              style: TextStyle(color: AppTheme.textSecondary)));
    }
    final total = entries.values.fold<int>(0, (a, b) => a + b);
    return PieChart(
      PieChartData(
        sections: entries.entries.map((e) {
          final color = Color(priorityColors[e.key] ?? 0xFF2F80ED);
          return PieChartSectionData(
            value: e.value.toDouble(),
            color: color,
            title: total == 0
                ? ''
                : '${e.key}\n${(e.value / total * 100).toStringAsFixed(0)}%',
            titleStyle: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            radius: 70,
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 30,
      ),
    );
  }
}
