import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../common/widgets.dart';

/// Admin overview: key numbers, SLA-breach alerts, recent complaints.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

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
          Text('Overview',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            user?.isSuperAdmin == true
                ? 'All complaints across VSIT'
                : 'Complaints for your department',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FutureBuilder<ComplaintStats>(
            future: repo.getStats(departmentId: deptId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final s = snap.data ?? const ComplaintStats();
              final cards = [
                _Stat('Total complaints', s.total, Icons.inbox, AppTheme.navy),
                _Stat('New', s.newCount, Icons.fiber_new, AppTheme.accent),
                _Stat('Pending', s.pending, Icons.hourglass_empty,
                    AppTheme.warning),
                _Stat('Under investigation', s.underInvestigation, Icons.search,
                    const Color(0xFF8E6CC8)),
                _Stat('Resolved', s.resolved, Icons.check_circle_outline,
                    AppTheme.success),
                _Stat('Critical', s.critical, Icons.warning_amber_rounded,
                    AppTheme.danger),
                _Stat('Avg resolution',
                    '${s.avgResolutionHours.toStringAsFixed(1)} h', Icons.timer,
                    AppTheme.navy),
                _Stat('Resolution rate',
                    '${s.resolutionPercent.toStringAsFixed(0)}%', Icons.percent,
                    AppTheme.success),
              ];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.1,
                ),
                itemCount: cards.length,
                itemBuilder: (context, i) => cards[i],
              );
            },
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Complaint>>(
            future: repo.getOverdueComplaints(),
            builder: (context, snap) {
              final overdue = (snap.data ?? [])
                  .where((c) => deptId == null || c.departmentId == deptId)
                  .toList();
              if (overdue.isEmpty) return const SizedBox.shrink();
              return Card(
                color: const Color(0xFFFDECEA),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppTheme.danger),
                          const SizedBox(width: 8),
                          Text(
                            '${overdue.length} complaint(s) breached their SLA target',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.danger),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...overdue.take(5).map((c) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: InkWell(
                              onTap: () => context
                                  .push('/admin/complaint/${c.id}'),
                              child: Text(
                                '• ${c.trackingId} — ${c.title} (${c.priority.toUpperCase()}, ${timeAgo(c.createdAt)})',
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            ),
                          )),
                      if (overdue.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextButton(
                            onPressed: () => context.go('/admin/complaints'),
                            child: Text(
                                'View all ${overdue.length} overdue'),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          SectionTitle('Recent complaints',
              actionLabel: 'View all',
              onAction: () => context.go('/admin/complaints')),
          FutureBuilder<List<Complaint>>(
            future: repo.getComplaints(departmentId: deptId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No complaints yet',
                  subtitle: 'Complaints will appear here as students submit them.',
                );
              }
              return Column(
                children: list
                    .take(8)
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ComplaintCard(
                            complaint: c,
                            onTap: () =>
                                context.push('/admin/complaint/${c.id}'),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final Object value;
  final IconData icon;
  final Color color;

  const _Stat(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$value',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(label,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
