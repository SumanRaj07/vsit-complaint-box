import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../common/widgets.dart';

/// Complaint management table with filters (status, category, priority,
/// department, date range, anonymous/verified) and search by ID / title.
/// On narrow screens the table becomes a card list.
class AdminComplaintsScreen extends ConsumerStatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  ConsumerState<AdminComplaintsScreen> createState() =>
      _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState
    extends ConsumerState<AdminComplaintsScreen> {
  String? _status;
  String? _category;
  String? _priority;
  String? _departmentId;
  String? _anonFilter; // 'all' | 'anonymous' | 'verified'
  String _query = '';
  DateTime? _from;
  DateTime? _to;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final repo = ref.watch(repositoryProvider);
    final departments = ref.watch(departmentsProvider);
    final deptId = user?.isSuperAdmin == true ? null : user?.departmentId;
    final isWide = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All Complaints',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search ID or title',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              _Dropdown<String>(
                label: 'Status',
                value: _status,
                items: {
                  for (final s in statusLabels.keys) s: statusLabels[s]!
                },
                onChanged: (v) => setState(() => _status = v),
              ),
              _Dropdown<String>(
                label: 'Category',
                value: _category,
                items: {for (final c in complaintCategories) c: c},
                onChanged: (v) => setState(() => _category = v),
              ),
              _Dropdown<String>(
                label: 'Priority',
                value: _priority,
                items: {
                  'low': 'Low',
                  'medium': 'Medium',
                  'high': 'High',
                  'critical': 'Critical'
                },
                onChanged: (v) => setState(() => _priority = v),
              ),
              if (user?.isSuperAdmin == true)
                departments.when(
                  data: (list) => _Dropdown<String>(
                    label: 'Department',
                    value: _departmentId,
                    items: {for (final d in list) d.id: d.name},
                    onChanged: (v) => setState(() => _departmentId = v),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              _Dropdown<String>(
                label: 'Type',
                value: _anonFilter,
                items: const {
                  'anonymous': 'Anonymous',
                  'verified': 'Verified',
                },
                onChanged: (v) => setState(() => _anonFilter = v),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2025),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setState(() {
                      _from = picked.start;
                      _to = picked.end.add(const Duration(days: 1));
                    });
                  }
                },
                icon: const Icon(Icons.date_range),
                label: Text(_from == null
                    ? 'Date range'
                    : '${formatDate(_from!)} – ${formatDate(_to!)}'),
              ),
              if (_status != null ||
                  _category != null ||
                  _priority != null ||
                  _departmentId != null ||
                  _anonFilter != null ||
                  _from != null ||
                  _query.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    _status = null;
                    _category = null;
                    _priority = null;
                    _departmentId = null;
                    _anonFilter = null;
                    _from = null;
                    _to = null;
                    _query = '';
                  }),
                  child: const Text('Clear filters'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Complaint>>(
            future: repo.getComplaints(
              departmentId: deptId ?? _departmentId,
              status: _status,
              category: _category,
              priority: _priority,
              query: _query.isEmpty ? null : _query,
              anonymousOnly: _anonFilter == 'anonymous' ? true : null,
              from: _from,
              to: _to,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Text('Error: ${snap.error}');
              }
              var list = snap.data ?? [];
              if (_anonFilter == 'verified') {
                list = list.where((c) => !c.isAnonymous).toList();
              }
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_off,
                  title: 'No complaints match',
                  subtitle: 'Try widening the filters.',
                );
              }
              final deptNames = departments.maybeWhen(
                data: (ds) => {for (final d in ds) d.id: d.name},
                orElse: () => <String, String>{},
              );
              if (isWide) {
                return Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Complaint ID')),
                        DataColumn(label: Text('Title')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Department')),
                        DataColumn(label: Text('Priority')),
                        DataColumn(label: Text('Submitted')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('')),
                      ],
                      rows: list
                          .map((c) => DataRow(
                                cells: [
                                  DataCell(Text(c.trackingId,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.accent))),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 260),
                                      child: Text(c.title,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                  DataCell(Text(c.category)),
                                  DataCell(Text(
                                      deptNames[c.departmentId] ?? '—')),
                                  DataCell(PriorityBadge(c.priority)),
                                  DataCell(Text(formatDate(c.createdAt))),
                                  DataCell(StatusBadge(c.status)),
                                  DataCell(
                                    TextButton(
                                      onPressed: () => context.push(
                                          '/admin/complaint/${c.id}'),
                                      child: const Text('Open'),
                                    ),
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
                  ),
                );
              }
              return Column(
                children: list
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ComplaintCard(
                            complaint: c,
                            departmentName: deptNames[c.departmentId],
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

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem<T>(value: null, child: Text('All')),
          ...items.entries.map(
              (e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
