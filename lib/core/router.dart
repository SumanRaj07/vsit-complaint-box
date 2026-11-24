import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_shell.dart';
import '../features/admin/admin_complaint_detail.dart';
import '../features/auth/auth_screens.dart';
import '../features/common/info_screens.dart';
import '../features/student/complaint_detail.dart';
import '../features/student/my_complaints.dart';
import '../features/student/notifications_screen.dart';
import '../features/student/profile_screen.dart';
import '../features/student/student_dashboard.dart';
import '../features/student/submit_complaint.dart';
import '../features/student/track_complaint.dart';
import 'providers.dart';

const _publicRoutes = ['/login', '/register', '/forgot', '/track'];

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final user = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      final isPublic =
          _publicRoutes.any((p) => loc == p || loc.startsWith('$p/'));
      if (user == null) return isPublic ? null : '/login';
      if (isPublic && loc != '/track') {
        return user.isAdmin ? '/admin' : '/home';
      }
      final isAdminRoute = loc == '/admin' || loc.startsWith('/admin/');
      if (user.isAdmin && !isAdminRoute) return '/admin';
      if (!user.isAdmin && isAdminRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
          path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/track', builder: (_, _) => const TrackComplaintScreen()),
      GoRoute(
        path: '/faq',
        builder: (_, _) => const FaqScreen(),
      ),
      GoRoute(
        path: '/suggest',
        builder: (_, _) => const SuggestScreen(),
      ),
      // ------------------------------------------------ student shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            StudentShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/home',
                  builder: (_, _) => const StudentDashboard()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/complaints',
                  builder: (_, _) => const MyComplaintsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/submit',
                  builder: (_, _) => const SubmitComplaintScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/notifications',
                  builder: (_, _) => const NotificationsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/profile',
                  builder: (_, _) => const ProfileScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/complaint/:id',
        builder: (_, state) =>
            ComplaintDetailScreen(complaintId: state.pathParameters['id']!),
      ),
      // ------------------------------------------------ admin shell
      GoRoute(
        path: '/admin',
        builder: (_, _) => const AdminShell(tab: AdminTab.dashboard),
      ),
      GoRoute(
        path: '/admin/complaints',
        builder: (_, _) => const AdminShell(tab: AdminTab.complaints),
      ),
      GoRoute(
        path: '/admin/departments',
        builder: (_, _) => const AdminShell(tab: AdminTab.departments),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (_, _) => const AdminShell(tab: AdminTab.users),
      ),
      GoRoute(
        path: '/admin/analytics',
        builder: (_, _) => const AdminShell(tab: AdminTab.analytics),
      ),
      GoRoute(
        path: '/admin/reports',
        builder: (_, _) => const AdminShell(tab: AdminTab.reports),
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (_, _) => const AdminShell(tab: AdminTab.settings),
      ),
      GoRoute(
        path: '/admin/complaint/:id',
        builder: (_, state) => AdminComplaintDetailScreen(
            complaintId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Bottom-navigation shell for students / staff.
class StudentShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const StudentShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    final unread = user == null
        ? 0
        : ref.watch(unreadCountProvider(user.id)).value ?? 0;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(i),
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'My Complaints'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Submit'),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications),
            ),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
