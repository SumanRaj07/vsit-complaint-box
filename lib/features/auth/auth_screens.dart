import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../common/widgets.dart';

/// Shared header used by all auth screens.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.navy,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.inbox_outlined,
              color: Colors.white, size: 34),
        ),
        const SizedBox(height: 16),
        Text(AppConfig.appName,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(AppConfig.tagline,
            style: const TextStyle(
                fontSize: 13,
                color: AppTheme.accent,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(AppConfig.collegeName,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  final Widget child;
  const _AuthScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LocalModeBanner(),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------------ login
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final user =
          await repo.signIn(_email.text.trim(), _password.text.trim());
      if (!mounted || user == null) return;
      ref.read(sessionProvider.notifier).setUser(user);
      if (user.isAdmin) {
        context.go('/admin');
      } else {
        context.go('/home');
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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Welcome back',
              subtitle: 'Log in with your college email to continue.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'College email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required.';
                if (!v.contains('@')) return 'Enter a valid email address.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required.' : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/forgot'),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _busy ? null : _login,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Log in'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/track'),
              child: const Text('Track a complaint (no login)'),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text("Don't have an account? "),
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Register'),
                ),
              ],
            ),
            ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Demo accounts (password: Demo@1234)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                'student@demo.vsit.edu — Student\n'
                'staff@demo.vsit.edu — Teaching Staff\n'
                'officer@demo.vsit.edu — Department Officer\n'
                'admin@demo.vsit.edu — Super Admin / HOD',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------- register
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _collegeId = TextEditingController();
  final _email = TextEditingController();
  final _classYear = TextEditingController();
  final _designation = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _departmentId;
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    _collegeId.dispose();
    _email.dispose();
    _classYear.dispose();
    _designation.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departmentId == null) {
      showSnack(context, 'Please choose your department.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final isStudent = _tabs.index == 0;
      if (isStudent) {
        await repo.signUpStudent(
          fullName: _name.text.trim(),
          collegeId: _collegeId.text.trim(),
          email: _email.text.trim(),
          departmentId: _departmentId!,
          classYear: _classYear.text.trim(),
          password: _password.text.trim(),
        );
        if (!mounted) return;
        showSnack(context, 'Account created. You can now log in.');
        context.go('/login');
      } else {
        await repo.signUpStaff(
          fullName: _name.text.trim(),
          employeeId: _collegeId.text.trim(),
          email: _email.text.trim(),
          departmentId: _departmentId!,
          designation: _designation.text.trim(),
          password: _password.text.trim(),
        );
        if (!mounted) return;
        showSnack(context,
            'Staff registration submitted. An administrator must approve it before you can log in.');
        context.go('/login');
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

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(departmentsProvider);
    final isStudent = _tabs.index == 0;
    return _AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Create your account',
              subtitle:
                  'Students register directly. Staff accounts need admin approval.',
            ),
            const SizedBox(height: 20),
            TabBar(
              controller: _tabs,
              onTap: (_) => setState(() {}),
              labelColor: AppTheme.navy,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.navy,
              tabs: const [
                Tab(text: 'Student'),
                Tab(text: 'Teaching Staff'),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _collegeId,
              decoration: InputDecoration(
                labelText: isStudent ? 'College ID / Roll number' : 'Employee ID',
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'This field is required.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'College email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required.';
                if (!v.contains('@')) return 'Enter a valid email address.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            departments.when(
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _departmentId,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                items: list
                    .map((d) =>
                        DropdownMenuItem(value: d.id, child: Text(d.name)))
                    .toList(),
                onChanged: (v) => setState(() => _departmentId = v),
              ),
              loading: () =>
                  const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load departments: $e'),
            ),
            const SizedBox(height: 14),
            if (isStudent)
              TextFormField(
                controller: _classYear,
                decoration: const InputDecoration(
                  labelText: 'Class / Year (e.g. SYBSc IT)',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Class / Year is required.'
                    : null,
              )
            else
              TextFormField(
                controller: _designation,
                decoration: const InputDecoration(
                  labelText: 'Designation (e.g. Assistant Professor)',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Designation is required.'
                    : null,
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password (min. 6 characters)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? 'Password must be at least 6 characters.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) =>
                  v != _password.text ? 'Passwords do not match.' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ? null : _register,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isStudent ? 'Create student account' : 'Submit staff registration'),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Already have an account? '),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Log in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------- forgot password
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .sendPasswordReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        showSnack(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Reset your password',
              subtitle:
                  'Enter your college email. This app has no email service — if the account exists, the Super Admin can reset it from User Management.',
            ),
            const SizedBox(height: 24),
            if (_sent)
              Card(
                color: const Color(0xFFE8F5EE),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'This app runs fully locally and has no email service, so no reset link can be emailed. Ask the Super Admin to reset your password from User Management.',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
            else ...[
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'College email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email is required.';
                  }
                  if (!v.contains('@')) return 'Enter a valid email address.';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _send,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Send reset link'),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }
}
