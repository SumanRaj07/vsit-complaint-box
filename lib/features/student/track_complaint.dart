import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../common/widgets.dart';

/// Public anonymous tracking: tracking ID + 6-digit PIN.
/// Shows only the public timeline — never any identity.
class TrackComplaintScreen extends ConsumerStatefulWidget {
  const TrackComplaintScreen({super.key});

  @override
  ConsumerState<TrackComplaintScreen> createState() =>
      _TrackComplaintScreenState();
}

class _TrackComplaintScreenState extends ConsumerState<TrackComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _trackingId = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  bool _searched = false;
  bool _found = false;
  String? _title;
  String? _category;
  String? _priority;
  String? _status;
  DateTime? _createdAt;
  DateTime? _updatedAt;
  DateTime? _resolvedAt;

  @override
  void dispose() {
    _trackingId.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final complaint = await ref.read(repositoryProvider).trackAnonymous(
            _trackingId.text.trim().toUpperCase(),
            hashPin(_pin.text.trim()),
          );
      if (!mounted) return;
      setState(() {
        _searched = true;
        _found = complaint != null;
        if (complaint != null) {
          _title = complaint.title;
          _category = complaint.category;
          _priority = complaint.priority;
          _status = complaint.status;
          _createdAt = complaint.createdAt;
          _updatedAt = complaint.updatedAt;
          _resolvedAt = complaint.resolvedAt;
        }
      });
      if (complaint == null) {
        showSnack(context,
            'No anonymous complaint matches this ID and PIN. Check both and try again.',
            error: true);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track a Complaint'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LocalModeBanner(),
              const Text(
                'Anonymous tracking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter the tracking ID (for example VSIT-2026-0001) and the 6-digit PIN you chose when submitting. Only the complaint status is shown — no identity is ever displayed.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _trackingId,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Tracking ID *',
                  hintText: 'VSIT-2026-0001',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Tracking ID is required.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pin,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '6-digit PIN *',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().length != 6)
                    ? 'Enter the 6-digit PIN.'
                    : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : _track,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Track Complaint'),
              ),
              if (_searched && _found) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_title ?? '',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            StatusBadge(_status ?? ''),
                            const SizedBox(width: 8),
                            PriorityBadge(_priority ?? 'medium'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _Row('Category', _category ?? ''),
                        _Row('Submitted',
                            _createdAt == null ? '—' : formatDateTime(_createdAt!)),
                        _Row('Last updated',
                            _updatedAt == null ? '—' : formatDateTime(_updatedAt!)),
                        if (_resolvedAt != null)
                          _Row('Resolved', formatDateTime(_resolvedAt!)),
                        const SizedBox(height: 8),
                        const Text(
                          'For follow-up questions on an anonymous complaint, submit a new complaint referencing this tracking ID.',
                          style: TextStyle(
                              fontSize: 12.5, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
