import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../common/widgets.dart';

/// Profile: account details, help links, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final departments = ref.watch(departmentsProvider);
    final deptName = departments.maybeWhen(
      data: (ds) {
        try {
          return ds.firstWhere((d) => d.id == user.departmentId).name;
        } catch (_) {
          return '—';
        }
      },
      orElse: () => '—',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LocalModeBanner(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.navy,
                      child: Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(user.email,
                              style: Theme.of(context).textTheme.bodySmall),
                          Text(
                              '${user.role == 'staff' ? 'Teaching Staff' : 'Student'} • $deptName',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Account'),
            _InfoTile(
                'College ID / Roll number', user.collegeId),
            _InfoTile('Department', deptName),
            _InfoTile('Class / Year',
                user.classYear ?? user.designation ?? '—'),
            _InfoTile('Account status',
                user.accountStatus == 'active' ? 'Active' : user.accountStatus),
            const SectionTitle('Help & feedback'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading:
                        const Icon(Icons.help_outline, color: AppTheme.navy),
                    title: const Text('Frequently Asked Questions'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/faq'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lightbulb_outline,
                        color: AppTheme.navy),
                    title: const Text('Suggest an improvement'),
                    subtitle: const Text(
                        'Ideas for the campus — not a formal complaint'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/suggest'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.track_changes_outlined,
                        color: AppTheme.navy),
                    title: const Text('Track anonymous complaint'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/track'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Log out?',
                  message: 'You will need to log in again to continue.',
                  confirmLabel: 'Log out',
                );
                if (!ok) return;
                await ref.read(repositoryProvider).signOut();
                ref.read(sessionProvider.notifier).clear();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '${AppConfig.appName} v1.0.0\n${AppConfig.collegeName}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        subtitle: Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15)),
      ),
    );
  }
}
