import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../common/widgets.dart';

/// Settings (Super Admin): SLA targets per priority, reopen window,
/// improvement suggestions, and the audit log.
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _controllers = <String, TextEditingController>{};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSla(Map<String, int> current) async {
    final updated = <String, int>{};
    for (final entry in current.entries) {
      final text = _controllers[entry.key]?.text ?? '${entry.value}';
      final v = int.tryParse(text);
      if (v == null || v <= 0) {
        showSnack(context, 'SLA for ${entry.key} must be a positive number of hours.',
            error: true);
        return;
      }
      updated[entry.key] = v;
    }
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).updateSlaHours(updated);
      if (mounted) showSnack(context, 'SLA targets saved.');
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
    final repo = ref.watch(repositoryProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Service-level targets (hours to resolve)',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    'A complaint that crosses its target is flagged as overdue and can be escalated to the HOD.',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<Map<String, int>>(
                    future: repo.getSlaHours(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      final sla = snap.data ?? AppConfig.slaHours;
                      for (final e in sla.entries) {
                        _controllers.putIfAbsent(
                            e.key,
                            () => TextEditingController(
                                text: e.value.toString()));
                      }
                      return Column(
                        children: [
                          ...sla.entries.map((e) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.key[0].toUpperCase() +
                                            e.key.substring(1),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: TextField(
                                        controller: _controllers[e.key],
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            suffixText: 'hours'),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 6),
                          ElevatedButton(
                            onPressed:
                                _busy ? null : () => _saveSla(sla),
                            child: const Text('Save SLA targets'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reopen window: ${AppConfig.reopenWindowDays} days after resolution.',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Improvement suggestions from students'),
          FutureBuilder<List<Suggestion>>(
            future: repo.getSuggestions(),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Text('No suggestions yet.',
                    style: TextStyle(color: AppTheme.textSecondary));
              }
              return Column(
                children: list
                    .map((s) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.lightbulb_outline,
                                color: AppTheme.navy),
                            title: Text(s.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                '${s.description}\n${s.isAnonymous ? 'Anonymous' : 'Verified'} • ${s.status}'),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SectionTitle('Audit log (admin actions)'),
          FutureBuilder<List<AuditLog>>(
            future: repo.getAuditLogs(limit: 50),
            builder: (context, snap) {
              final logs = snap.data ?? [];
              if (logs.isEmpty) {
                return const Text('No admin actions recorded yet.',
                    style: TextStyle(color: AppTheme.textSecondary));
              }
              return Card(
                child: Column(
                  children: logs
                      .map((l) => ListTile(
                            dense: true,
                            title: Text(l.action,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${l.details}${l.complaintId != null ? ' • ${l.complaintId}' : ''}'),
                            trailing: Text(formatDateTime(l.createdAt),
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
