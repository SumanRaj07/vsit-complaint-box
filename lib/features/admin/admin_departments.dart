import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../common/widgets.dart';

/// Department management (Super Admin only): add, edit, deactivate,
/// assign a head officer, view per-department complaint counts.
class AdminDepartmentsScreen extends ConsumerStatefulWidget {
  const AdminDepartmentsScreen({super.key});

  @override
  ConsumerState<AdminDepartmentsScreen> createState() =>
      _AdminDepartmentsScreenState();
}

class _AdminDepartmentsScreenState
    extends ConsumerState<AdminDepartmentsScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty) {
      showSnack(context, 'Department name is required.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).addDepartment(
            _name.text,
            _description.text,
          );
      _name.clear();
      _description.clear();
      ref.invalidate(departmentsProvider);
      if (mounted) {
        showSnack(context, 'Department added.');
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleActive(Department d) async {
    await ref
        .read(repositoryProvider)
        .setDepartmentActive(d.id, !d.isActive);
    ref.invalidate(departmentsProvider);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final user = ref.watch(sessionProvider);
    final canManage = user?.isSuperAdmin == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Department Management',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text(
            'Departments receive complaints and own their resolution.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          if (canManage)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Add department',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: 'Department name *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _description,
                      decoration: const InputDecoration(
                          labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _busy ? null : _add,
                      child: const Text('Add department'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FutureBuilder<List<Department>>(
            future: repo.getDepartments(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data ?? [];
              return FutureBuilder<Map<String, int>>(
                future: repo.getComplaintsByDepartment(),
                builder: (context, cSnap) {
                  final counts = cSnap.data ?? {};
                  return Column(
                    children: list
                        .map((d) => Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.navy,
                                  child: Text(
                                    d.name.isNotEmpty
                                        ? d.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Colors.white),
                                  ),
                                ),
                                title: Text(d.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (d.description.isNotEmpty)
                                      Text(d.description),
                                    Text(
                                        '${counts[d.name] ?? 0} complaint(s) • ${d.isActive ? 'Active' : 'Inactive'}'),
                                  ],
                                ),
                                trailing: canManage
                                    ? Switch(
                                        value: d.isActive,
                                        onChanged: (_) => _toggleActive(d),
                                      )
                                    : null,
                              ),
                            ))
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
