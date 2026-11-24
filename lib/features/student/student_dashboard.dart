import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../common/widgets.dart';

/// Student / staff home: greeting, complaint counts, recent activity.
class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final repo = ref.watch(repositoryProvider);
    final departments = ref.watch(departmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VSIT Complaint Box'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go('/notifications'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LocalModeBanner(),
            Text(
              'Namaste, ${user.fullName.split(' ').first} 👋',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${user.collegeId} • ${user.classYear ?? user.designation ?? ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Complaint>>(
              future: repo.getComplaints(userId: user.id),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Text('Could not load complaints: ${snap.error}');
                }
                final list = snap.data ?? [];
                final total = list.length;
                final pending = list
                    .where((c) => !['resolved', 'closed', 'rejected']
                        .contains(c.status))
                    .length;
                final underReview = list
                    .where((c) => ['under_review', 'investigation']
                        .contains(c.status))
                    .length;
                final resolved = list
                    .where((c) => ['resolved', 'closed'].contains(c.status))
                    .length;
                return Column(
                  children: [
                    Row(
                      children: [
                        _StatCard(
                            label: 'Total', value: total, icon: Icons.inbox),
                        const SizedBox(width: 10),
                        _StatCard(
                            label: 'Pending',
                            value: pending,
                            icon: Icons.hourglass_empty,
                            color: AppTheme.warning),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StatCard(
                            label: 'Under Review',
                            value: underReview,
                            icon: Icons.search,
                            color: AppTheme.accent),
                        const SizedBox(width: 10),
                        _StatCard(
                            label: 'Resolved',
                            value: resolved,
                            icon: Icons.check_circle_outline,
                            color: AppTheme.success),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/submit'),
                        icon: const Icon(Icons.add),
                        label: const Text('Submit New Complaint'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/track'),
                        icon: const Icon(Icons.track_changes_outlined),
                        label: const Text('Track an anonymous complaint'),
                      ),
                    ),
                    SectionTitle('Recent activity',
                        actionLabel: 'View all',
                        onAction: () => context.go('/complaints')),
                    if (list.isEmpty)
                      const EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'No complaints yet',
                        subtitle:
                            'Submit your first complaint and track it here.',
                      )
                    else
                      ...list.take(4).map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ComplaintCard(
                              complaint: c,
                              departmentName: departments.maybeWhen(
                                data: (ds) {
                                  try {
                                    return ds
                                        .firstWhere(
                                            (d) => d.id == c.departmentId)
                                        .name;
                                  } catch (_) {
                                    return null;
                                  }
                                },
                                orElse: () => null,
                              ),
                              onTap: () => context.push('/complaint/${c.id}'),
                            ),
                          )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppTheme.navy,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  Text(label,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
