import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import 'models.dart';

/// The active data layer. Overridden in main() with either the Supabase
/// repository (when credentials are configured) or the local demo repository.
final repositoryProvider = Provider<ComplaintRepository>((ref) {
  throw UnimplementedError('repositoryProvider must be overridden in main()');
});

/// Current signed-in user (null = signed out).
class SessionNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() => null;

  void setUser(UserProfile? user) => state = user;
  void clear() => state = null;
}

final sessionProvider =
    NotifierProvider<SessionNotifier, UserProfile?>(SessionNotifier.new);

/// Departments (cached per app run; refresh after admin edits).
final departmentsProvider = FutureProvider<List<Department>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getDepartments();
});

/// Unread notification count for the current user.
final unreadCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  final repo = ref.watch(repositoryProvider);
  final list = await repo.getNotifications(userId);
  return list.where((n) => !n.isRead).length;
});
