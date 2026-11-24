import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../common/widgets.dart';

/// User management (Super Admin): search, approve pending staff,
/// activate / deactivate accounts. Nobody can assign themselves an admin
/// role — roles are set only here.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _query = '';
  String? _roleFilter;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final me = ref.watch(sessionProvider);
    final departments = ref.watch(departmentsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User Management',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name, email or college ID',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: _roleFilter,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All roles')),
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(
                        value: 'dept_officer', child: Text('Dept Officer')),
                    DropdownMenuItem(
                        value: 'super_admin', child: Text('Super Admin')),
                  ],
                  onChanged: (v) => setState(() => _roleFilter = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<UserProfile>>(
            future: repo.getUsers(role: _roleFilter, query: _query),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No users found',
                  subtitle: 'Try a different search.',
                );
              }
              final deptNames = departments.maybeWhen(
                data: (ds) => {for (final d in ds) d.id: d.name},
                orElse: () => <String, String>{},
              );
              return Column(
                children: list
                    .map((u) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.navy,
                              child: Text(
                                u.fullName.isNotEmpty
                                    ? u.fullName[0].toUpperCase()
                                    : '?',
                                style:
                                    const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(u.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${u.email} • ${u.collegeId}'),
                                Text(
                                    '${_roleLabel(u.role)} • ${deptNames[u.departmentId] ?? '—'} • ${u.accountStatus}'),
                              ],
                            ),
                            trailing: u.id == me?.id
                                ? const Text('(you)',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary))
                                : PopupMenuButton<String>(
                                    onSelected: (action) async {
                                      if (action == 'approve') {
                                        await repo.approveStaff(u.id);
                                        await repo.addAuditLog(
                                          adminId: me!.id,
                                          action: 'approve_staff',
                                          details: u.email,
                                        );
                                        setState(() {});
                                        if (context.mounted) {
                                          showSnack(context,
                                              '${u.fullName} approved.');
                                        }
                                      } else if (action == 'deactivate') {
                                        final ok = await confirmDialog(
                                          context,
                                          title: 'Deactivate account?',
                                          message:
                                              '${u.fullName} will not be able to log in.',
                                          confirmLabel: 'Deactivate',
                                        );
                                        if (!ok) return;
                                        await repo.updateUserStatus(
                                            u.id, 'deactivated');
                                        setState(() {});
                                      } else if (action == 'activate') {
                                        await repo.updateUserStatus(
                                            u.id, 'active');
                                        setState(() {});
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (u.accountStatus ==
                                          'pending_approval')
                                        const PopupMenuItem(
                                          value: 'approve',
                                          child: Text('Approve staff account'),
                                        ),
                                      if (u.accountStatus == 'active')
                                        const PopupMenuItem(
                                          value: 'deactivate',
                                          child: Text('Deactivate account'),
                                        ),
                                      if (u.accountStatus == 'deactivated')
                                        const PopupMenuItem(
                                          value: 'activate',
                                          child: Text('Activate account'),
                                        ),
                                    ],
                                  ),
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

String _roleLabel(String role) => switch (role) {
      'student' => 'Student',
      'staff' => 'Teaching Staff',
      'dept_officer' => 'Dept Officer',
      'super_admin' => 'Super Admin',
      _ => role,
    };
