import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/utils.dart';
import '../common/widgets.dart';

/// The student's own complaints, with status / category filters and search.
class MyComplaintsScreen extends ConsumerStatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  ConsumerState<MyComplaintsScreen> createState() =>
      _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends ConsumerState<MyComplaintsScreen> {
  String? _statusFilter;
  String? _categoryFilter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final repo = ref.watch(repositoryProvider);
    final departments = ref.watch(departmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Complaints')),
      body: Column(
        children: [
          const LocalModeBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by complaint ID or title',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                ...['submitted', 'under_review', 'investigation', 'resolved',
                        'closed', 'rejected']
                    .map((s) => _FilterChip(
                          label: statusLabels[s] ?? s,
                          selected: _statusFilter == s,
                          onTap: () => setState(() => _statusFilter = s),
                        )),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _categoryFilter,
                  hint: const Text('Category'),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All categories')),
                    ...complaintCategories.map((c) =>
                        DropdownMenuItem(value: c, child: Text(c))),
                  ],
                  onChanged: (v) => setState(() => _categoryFilter = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Complaint>>(
              future: repo.getComplaints(
                userId: user.id,
                status: _statusFilter,
                category: _categoryFilter,
                query: _query.isEmpty ? null : _query,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No complaints found',
                    subtitle:
                        'Try a different filter, or submit a new complaint.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ComplaintCard(
                          complaint: c,
                          departmentName: departments.maybeWhen(
                            data: (ds) {
                              try {
                                return ds
                                    .firstWhere((d) => d.id == c.departmentId)
                                    .name;
                              } catch (_) {
                                return null;
                              }
                            },
                            orElse: () => null,
                          ),
                          onTap: () => context.push('/complaint/${c.id}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
