import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../common/widgets.dart';

/// In-app notification centre: unread count, mark-as-read, tap to open.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final repo = ref.watch(repositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await repo.markAllNotificationsRead(user.id);
              ref.invalidate(unreadCountProvider(user.id));
              setState(() {});
            },
            child: const Text('Mark all read',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: FutureBuilder(
        future: repo.getNotifications(user.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'No notifications',
              subtitle:
                  'You will be notified when a complaint is acknowledged, updated or resolved.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(unreadCountProvider(user.id));
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final n = list[i];
                return Card(
                  color: n.isRead ? Colors.white : const Color(0xFFEFF4FF),
                  child: ListTile(
                    leading: Icon(
                      n.isRead
                          ? Icons.notifications_outlined
                          : Icons.notifications,
                      color: AppTheme.navy,
                    ),
                    title: Text(n.title,
                        style: TextStyle(
                            fontWeight: n.isRead
                                ? FontWeight.w500
                                : FontWeight.w700)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (n.message.isNotEmpty) Text(n.message),
                        Text(timeAgo(n.createdAt),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    onTap: () async {
                      if (!n.isRead) {
                        await repo.markNotificationRead(n.id);
                        ref.invalidate(unreadCountProvider(user.id));
                        setState(() {});
                      }
                      if (n.complaintId != null && context.mounted) {
                        context.push('/complaint/${n.complaintId}');
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
