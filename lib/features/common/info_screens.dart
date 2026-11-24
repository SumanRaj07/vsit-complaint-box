import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../common/widgets.dart';

/// Frequently asked questions (from the DB / demo seed).
class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Frequently Asked Questions')),
      body: FutureBuilder(
        future: repo.getFaqs(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final faqs = snap.data ?? [];
          if (faqs.isEmpty) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: 'No FAQs yet',
              subtitle: 'Check back later.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: faqs.length,
            itemBuilder: (context, i) {
              final f = faqs[i];
              return Card(
                child: ExpansionTile(
                  title: Text(f.question,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(f.answer),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Suggest an improvement for the campus (not a formal complaint).
class SuggestScreen extends ConsumerStatefulWidget {
  const SuggestScreen({super.key});

  @override
  ConsumerState<SuggestScreen> createState() => _SuggestScreenState();
}

class _SuggestScreenState extends ConsumerState<SuggestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _anonymous = false;
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).addSuggestion(
            title: _title.text,
            description: _description.text,
            isAnonymous: _anonymous,
            userId: ref.read(sessionProvider)?.id,
          );
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggest an Improvement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Have an idea to make the campus better? Share it here. '
                'Suggestions are not formal complaints — they go to the '
                'administration for consideration.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              if (_sent)
                const Card(
                  color: Color(0xFFE8F5EE),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Thank you! Your suggestion has been recorded and will be reviewed by the administration.',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                )
              else ...[
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Suggestion title *',
                    hintText: 'e.g. Add more charging points in the library',
                  ),
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'Give a short title (min. 5 characters).'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Describe your suggestion *',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 20)
                      ? 'Please describe it (min. 20 characters).'
                      : null,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Submit anonymously'),
                  value: _anonymous,
                  onChanged: (v) => setState(() => _anonymous = v),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Send Suggestion'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
