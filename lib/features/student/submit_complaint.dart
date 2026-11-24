import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/repository.dart';
import '../common/widgets.dart';

/// Complaint submission form (9 fields from the spec).
/// After submission shows the tracking ID and, for anonymous complaints,
/// the one-time 6-digit PIN the user must save.
class SubmitComplaintScreen extends ConsumerStatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  ConsumerState<SubmitComplaintScreen> createState() =>
      _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState
    extends ConsumerState<SubmitComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  String? _category;
  String? _departmentId;
  String _priority = 'medium';
  bool _anonymous = false;
  bool _emergency = false;
  bool _declared = false;
  bool _busy = false;
  List<PickedFile> _files = [];
  List<Complaint> _duplicates = [];
  bool _checkingDuplicates = false;

  // Result shown on the success screen.
  Complaint? _submitted;
  String? _submittedPin;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: AppConfig.allowedExtensions,
        withData: false,
      );
      if (result == null) return;
      final picked = <PickedFile>[];
      for (final f in result.files) {
        if (f.path == null) continue;
        if (f.size > AppConfig.maxAttachmentMb * 1024 * 1024) {
          if (!mounted) continue;
          showSnack(
              context,
              '${f.name} is larger than ${AppConfig.maxAttachmentMb} MB and was skipped.',
              error: true);
          continue;
        }
        picked.add(PickedFile(
          name: f.name,
          path: f.path!,
          extension: f.extension ?? '',
          sizeBytes: f.size,
        ));
      }
      setState(() => _files = [..._files, ...picked]);
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Could not pick files: $e', error: true);
      }
    }
  }

  Future<void> _checkDuplicates() async {
    if (_title.text.trim().length < 5 ||
        _description.text.trim().length < 10 ||
        _category == null ||
        _departmentId == null) {
      return;
    }
    setState(() => _checkingDuplicates = true);
    try {
      final dups = await ref.read(repositoryProvider).findPotentialDuplicates(
            title: _title.text.trim(),
            description: _description.text.trim(),
            category: _category!,
            departmentId: _departmentId!,
          );
      if (mounted) setState(() => _duplicates = dups);
    } finally {
      if (mounted) setState(() => _checkingDuplicates = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _departmentId == null) {
      showSnack(context, 'Please choose a category and a department.',
          error: true);
      return;
    }
    if (!_declared) {
      showSnack(context, 'Please accept the declaration to submit.',
          error: true);
      return;
    }
    final user = ref.read(sessionProvider);
    if (user == null) {
      showSnack(context, 'Please log in to submit a complaint.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final pin = _anonymous ? generatePin() : null;
      final complaint = await ref.read(repositoryProvider).submitComplaint(
            title: _title.text,
            description: _description.text,
            category: _category!,
            departmentId: _departmentId!,
            location: _location.text,
            priority: _priority,
            isAnonymous: _anonymous,
            isEmergency: _emergency,
            userId: user.id,
            pinHash: pin == null ? null : hashPin(pin),
            attachments: _files,
          );
      if (mounted) {
        setState(() {
          _submitted = complaint;
          _submittedPin = pin;
        });
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
    if (_submitted != null) return _buildSuccess(context);
    final departments = ref.watch(departmentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Submit a Complaint')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LocalModeBanner(),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Complaint title *',
                  hintText: 'e.g. Projector not working in Lab 3',
                ),
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Give a short, clear title (min. 5 characters).'
                    : null,
                onChanged: (_) => _checkDuplicates(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText:
                      'Describe the problem in detail: what happened, when, and how it affects you.',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().length < 20)
                    ? 'Please describe the problem (min. 20 characters).'
                    : null,
                onChanged: (_) => _checkDuplicates(),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration:
                    const InputDecoration(labelText: 'Category *'),
                items: complaintCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _category = v);
                  _checkDuplicates();
                },
              ),
              const SizedBox(height: 14),
              departments.when(
                data: (list) => DropdownButtonFormField<String>(
                  initialValue: _departmentId,
                  decoration:
                      const InputDecoration(labelText: 'Department *'),
                  items: list
                      .map((d) =>
                          DropdownMenuItem(value: d.id, child: Text(d.name)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _departmentId = v);
                    _checkDuplicates();
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Could not load departments: $e'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Computer Lab 3, 2nd floor',
                ),
              ),
              const SizedBox(height: 14),
              const Text('Priority *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: complaintPriorities.map((p) {
                  final selected = _priority == p;
                  return ChoiceChip(
                    label: Text(p.toUpperCase()),
                    selected: selected,
                    selectedColor:
                        Color(priorityColors[p] ?? 0xFF2F80ED)
                            .withValues(alpha: 0.18),
                    onSelected: (_) => setState(() => _priority = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Supporting evidence',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text(
                        'Photos (JPG/PNG), PDF documents or short videos (MP4), up to 25 MB per file.',
                        style: TextStyle(
                            fontSize: 12.5, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Attach files'),
                      ),
                      if (_files.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ..._files.map((f) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                  f.fileType == 'pdf'
                                      ? Icons.picture_as_pdf
                                      : f.fileType == 'video'
                                          ? Icons.videocam
                                          : Icons.image,
                                  color: AppTheme.navy),
                              title: Text(f.name,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: Text(
                                  '${(f.sizeBytes / 1024).toStringAsFixed(0)} KB'),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(
                                    () => _files.remove(f)),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                title: const Text('Submit anonymously'),
                subtitle: const Text(
                    'Your name, email and roll number will be hidden from department officers.'),
                value: _anonymous,
                onChanged: (v) => setState(() => _anonymous = v),
              ),
              if (_anonymous)
                const Card(
                  color: Color(0xFFFFF3CD),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Limits of anonymity: officers cannot see who you are, but do not write your name inside the complaint text or inside attached files. You will track this complaint using its tracking ID and a 6-digit PIN shown after submission — save both, they cannot be recovered.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              SwitchListTile(
                title: const Text('This is an emergency / safety issue'),
                subtitle: const Text(
                    'Critical infrastructure or safety problem. Note: this app is not an emergency-response service — for immediate danger, contact college security first.'),
                value: _emergency,
                onChanged: (v) => setState(() {
                  _emergency = v;
                  if (v) _priority = 'critical';
                }),
              ),
              if (_checkingDuplicates)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              if (_duplicates.isNotEmpty)
                Card(
                  color: const Color(0xFFFFF3CD),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Color(0xFF856404)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Similar complaints already exist',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF856404)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'You can still submit — this is only a warning, not a rejection.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        ..._duplicates.take(3).map((c) => Padding(
                              padding:
                                  const EdgeInsets.only(top: 4),
                              child: Text(
                                  '• ${c.trackingId} — ${c.title} (${statusLabels[c.status] ?? c.status})',
                                  style: const TextStyle(fontSize: 13)),
                            )),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text(
                    'I declare that the information given above is true to the best of my knowledge.'),
                value: _declared,
                onChanged: (v) => setState(() => _declared = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Complaint'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final c = _submitted!;
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint Submitted')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle,
                color: AppTheme.success, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Your complaint has been submitted successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text('Your Complaint ID',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    SelectableText(
                      c.trackingId,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent),
                    ),
                    const SizedBox(height: 8),
                    Text('Status: ${statusLabels[c.status] ?? c.status}'),
                  ],
                ),
              ),
            ),
            if (_submittedPin != null) ...[
              const SizedBox(height: 14),
              Card(
                color: const Color(0xFFFFF3CD),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Text(
                        'Your anonymous tracking PIN — save it now',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        _submittedPin!,
                        style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'You need the Complaint ID + this PIN to track your complaint. The PIN is shown only once and cannot be recovered.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (c.isAnonymous) {
                  context.go('/track');
                } else {
                  context.go('/complaints');
                }
              },
              child: Text(c.isAnonymous
                  ? 'Track my complaint'
                  : 'View my complaints'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
