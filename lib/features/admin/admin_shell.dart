import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import 'admin_analytics.dart';
import 'admin_complaints.dart';
import 'admin_dashboard.dart';
import 'admin_departments.dart';
import 'admin_reports.dart';
import 'admin_settings.dart';
import 'admin_users.dart';

enum AdminTab {
  dashboard,
  complaints,
  departments,
  users,
  analytics,
  reports,
  settings,
}

extension on AdminTab {
  String get label => switch (this) {
        AdminTab.dashboard => 'Dashboard',
        AdminTab.complaints => 'All Complaints',
        AdminTab.departments => 'Departments',
        AdminTab.users => 'User Management',
        AdminTab.analytics => 'Analytics',
        AdminTab.reports => 'Reports',
        AdminTab.settings => 'Settings',
      };

  IconData get icon => switch (this) {
        AdminTab.dashboard => Icons.dashboard_outlined,
        AdminTab.complaints => Icons.list_alt_outlined,
        AdminTab.departments => Icons.apartment_outlined,
        AdminTab.users => Icons.people_outline,
        AdminTab.analytics => Icons.bar_chart_outlined,
        AdminTab.reports => Icons.description_outlined,
        AdminTab.settings => Icons.settings_outlined,
      };

  String get route => switch (this) {
        AdminTab.dashboard => '/admin',
        AdminTab.complaints => '/admin/complaints',
        AdminTab.departments => '/admin/departments',
        AdminTab.users => '/admin/users',
        AdminTab.analytics => '/admin/analytics',
        AdminTab.reports => '/admin/reports',
        AdminTab.settings => '/admin/settings',
      };
}

/// Responsive admin shell: sidebar on desktop (width >= 900), bottom
/// navigation on mobile. Dept officers see the same shell but only their
/// department's complaints (enforced by the repository / RLS).
class AdminShell extends ConsumerWidget {
  final AdminTab tab;
  const AdminShell({super.key, required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    final isWide = MediaQuery.of(context).size.width >= 900;
    final body = switch (tab) {
      AdminTab.dashboard => const AdminDashboard(),
      AdminTab.complaints => const AdminComplaintsScreen(),
      AdminTab.departments => const AdminDepartmentsScreen(),
      AdminTab.users => const AdminUsersScreen(),
      AdminTab.analytics => const AdminAnalyticsScreen(),
      AdminTab.reports => const AdminReportsScreen(),
      AdminTab.settings => const AdminSettingsScreen(),
    };

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 260,
              color: AppTheme.navy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.inbox_outlined,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('VSIT Complaint Box',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                              Text('Admin Dashboard',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...AdminTab.values.map((t) => _SideItem(
                        tab: t,
                        selected: t == tab,
                        onTap: () => context.go(t.route),
                      )),
                  const Spacer(),
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            child: Text(
                              user.fullName.isNotEmpty
                                  ? user.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.fullName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                    user.role == 'super_admin'
                                        ? 'Super Admin'
                                        : 'Dept Officer',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout,
                                color: Colors.white70, size: 20),
                            tooltip: 'Log out',
                            onPressed: () async {
                              await ref
                                  .read(repositoryProvider)
                                  .signOut();
                              ref.read(sessionProvider.notifier).clear();
                              if (context.mounted) context.go('/login');
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    color: const Color(0xFFFFF3CD),
                    child: const Text(
                      'Local mode — all data is stored on this device only. No internet or account needed.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF856404)),
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tab.label)),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab.index,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => context.go(AdminTab.values[i].route),
        items: AdminTab.values
            .map((t) =>
                BottomNavigationBarItem(icon: Icon(t.icon), label: t.label))
            .toList(),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final AdminTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _SideItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(tab.icon,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(tab.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
