import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../common/widgets.dart';

/// Admin view of one complaint: full detail + every management action.
/// Anonymous complainants are never identified here: for anonymous
/// complaints the reporter section shows only "Anonymous".
class AdminComplaintDetailScreen extends ConsumerStatefulWidget {
  final String complaintId;
  const AdminComplaintDetailScreen({super.key, required this.complaintId});

  @override
  ConsumerState<AdminComplaintDetailScreen> createState() =>
      _AdminComplaintDetailScreenState();
}

class _AdminComplaintDetailScreenState
    extends ConsumerState<AdminComplaintDetailScreen> {
  final _updateMessage = TextEditingController();
  final _noteMessage = TextEditingController();
  final _chatMessage = TextEditingController();
  final _rejectReason = TextEditingController();
  String? _newStatus;
  String? _newPriority;
  String? _newDepartmentId;
  String? _newOfficerId;
  bool _busy = false;

  @override
  void dispose() {
    _updateMessage.dispose();
    _noteMessage.dispose();
    _chatMessage.dispose();
    _rejectReason.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn, String okMsg) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (mounted) {
        showSnack(context, okMsg);
        setState(() {});
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
    final repo = ref.watch(repositoryProvider);
    final user = ref.watch(sessionProvider);
    final departments = ref.watch(departmentsProvider);
    final officers = ref.watch(_officersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Complaint Details')),
      body: FutureBuilder<Complaint?>(
        future: repo.getComplaintById(widget.complaintId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = snap.data;
          if (c == null || user == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Complaint not found',
              subtitle: 'It may have been removed.',
            );
          }
          final deptName = departments.maybeWhen(
            data: (ds) {
              try {
                return ds.firstWhere((d) => d.id == c.departmentId).name;
              } catch (_) {
                return 'Unassigned';
              }
            },
            orElse: () => '…',
          );
          final nextStatuses = allowedTransitions[c.status] ?? [];
          final canMessage = !c.isAnonymous &&
              !['closed', 'rejected'].contains(c.status);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(c.trackingId,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                            fontSize: 15)),
                    StatusBadge(c.status),
                    PriorityBadge(c.priority),
                    if (c.isAnonymous)
                      const Chip(
                        label: Text('Anonymous'),
                        avatar: Icon(Icons.visibility_off, size: 16),
                      ),
                    if (c.isEmergency)
                      const Chip(
                        label: Text('Emergency'),
                        avatar:
                            Icon(Icons.warning_amber_rounded, size: 16),
                      ),
                    if (c.escalatedAt != null)
                      const Chip(
                        label: Text('Escalated to HOD'),
                        avatar: Icon(Icons.trending_up, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _Row('Category', c.category),
                _Row('Department', deptName),
                if (c.location.isNotEmpty) _Row('Location', c.location),
                _Row('Submitted', formatDateTime(c.createdAt)),
                _Row('Last updated', formatDateTime(c.updatedAt)),
                if (c.resolvedAt != null)
                  _Row('Resolved', formatDateTime(c.resolvedAt!)),
                _Row('Reporter',
                    c.isAnonymous ? 'Anonymous (identity hidden)' : 'Verified user'),
                if (c.status == 'rejected' && c.rejectionReason != null)
                  Card(
                    color: const Color(0xFFFDECEA),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child:
                          Text('Rejected: ${c.rejectionReason}'),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(c.description,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SectionTitle('Status timeline'),
                FutureBuilder<List<ComplaintUpdate>>(
                  future: repo.getUpdates(c.id, includeInternal: true),
                  builder: (context, uSnap) {
                    final updates = uSnap.data ?? [];
                    if (updates.isEmpty) {
                      return const Text('No updates yet.');
                    }
                    return Column(
                      children: updates
                          .map((u) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 6,
                                  backgroundColor: Color(
                                      statusColors[u.newStatus] ??
                                          0xFF5B6B8C),
                                ),
                                title: Text(
                                    '${statusLabels[u.newStatus] ?? u.newStatus}'
                                    '${u.visibility == 'internal' ? '  •  internal note' : ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (u.message.isNotEmpty)
                                      Text(u.message),
                                    Text(formatDateTime(u.createdAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SectionTitle('Attachments'),
                FutureBuilder<List<Attachment>>(
                  future: repo.getAttachments(c.id),
                  builder: (context, aSnap) {
                    final atts = aSnap.data ?? [];
                    if (atts.isEmpty) return const Text('No attachments.');
                    return Column(
                      children: atts
                          .map((a) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                    a.fileType == 'pdf'
                                        ? Icons.picture_as_pdf
                                        : a.fileType == 'video'
                                            ? Icons.videocam
                                            : Icons.image,
                                    color: AppTheme.navy),
                                title: Text(a.fileName),
                                subtitle: Text(
                                    '${(a.fileSizeBytes / 1024).toStringAsFixed(0)} KB'),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SectionTitle('Update status'),
                if (nextStatuses.isEmpty)
                  const Text(
                      'This complaint is in a final state and cannot be moved.',
                      style: TextStyle(color: AppTheme.textSecondary))
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _newStatus,
                        decoration: const InputDecoration(
                            labelText: 'New status'),
                        items: nextStatuses
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(statusLabels[s] ?? s)))
                            .toList(),
                        onChanged: (v) => setState(() => _newStatus = v),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _updateMessage,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Public update message',
                          hintText:
                              'Shown to the complainant on their timeline.',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _busy || _newStatus == null
                            ? null
                            : () => _run(() async {
                                  await repo.updateComplaintStatus(
                                    complaintId: c.id,
                                    newStatus: _newStatus!,
                                    updatedBy: user.id,
                                    message: _updateMessage.text,
                                    rejectionReason: _newStatus == 'rejected'
                                        ? _rejectReason.text
                                        : null,
                                  );
                                  await repo.addAuditLog(
                                    adminId: user.id,
                                    action: 'status_change',
                                    complaintId: c.id,
                                    details:
                                        '${c.status} -> $_newStatus',
                                  );
                                  _newStatus = null;
                                  _updateMessage.clear();
                                }, 'Status updated.'),
                        child: const Text('Update status'),
                      ),
                      if (_newStatus == 'info_required')
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'The complainant will be asked for more information and can reply in the Messages section.',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textSecondary),
                          ),
                        ),
                      if (_newStatus == 'rejected') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _rejectReason,
                          decoration: const InputDecoration(
                            labelText: 'Rejection reason (mandatory) *',
                          ),
                        ),
                      ],
                    ],
                  ),
                const SectionTitle('Internal investigation note'),
                const Text(
                  'Internal notes are never shown to students.',
                  style:
                      TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _noteMessage,
                        decoration: const InputDecoration(
                            hintText: 'e.g. Called the lab in-charge…'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _busy || _noteMessage.text.isEmpty
                          ? null
                          : () => _run(() async {
                                await repo.addInternalNote(
                                  complaintId: c.id,
                                  updatedBy: user.id,
                                  note: _noteMessage.text,
                                );
                                _noteMessage.clear();
                              }, 'Internal note added.'),
                      child: const Text('Add note'),
                    ),
                  ],
                ),
                const SectionTitle('Assignment'),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _newPriority ?? c.priority,
                        decoration:
                            const InputDecoration(labelText: 'Priority'),
                        items: complaintPriorities
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(p.toUpperCase())))
                            .toList(),
                        onChanged: (v) => setState(() => _newPriority = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                await repo.updateComplaintPriority(
                                  complaintId: c.id,
                                  priority: _newPriority ?? c.priority,
                                  updatedBy: user.id,
                                );
                              }, 'Priority updated.'),
                      child: const Text('Save priority'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                departments.when(
                  data: (list) => DropdownButtonFormField<String>(
                    initialValue: _newDepartmentId ?? c.departmentId,
                    decoration:
                        const InputDecoration(labelText: 'Department'),
                    items: list
                        .map((d) => DropdownMenuItem(
                            value: d.id, child: Text(d.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _newDepartmentId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 10),
                officers.when(
                  data: (list) => DropdownButtonFormField<String>(
                    initialValue: _newOfficerId ?? c.assignedOfficerId,
                    decoration: const InputDecoration(
                        labelText: 'Assigned officer'),
                    items: list
                        .map((o) => DropdownMenuItem(
                            value: o.id,
                            child: Text('${o.fullName} (${o.collegeId})')))
                        .toList(),
                    onChanged: (v) => setState(() => _newOfficerId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy || _newDepartmentId == null
                            ? null
                            : () => _run(() async {
                                  await repo.assignDepartment(
                                    complaintId: c.id,
                                    departmentId: _newDepartmentId!,
                                    updatedBy: user.id,
                                  );
                                }, 'Department updated.'),
                        child: const Text('Assign department'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy || _newOfficerId == null
                            ? null
                            : () => _run(() async {
                                  await repo.assignComplaint(
                                    complaintId: c.id,
                                    officerId: _newOfficerId!,
                                    updatedBy: user.id,
                                  );
                                }, 'Officer assigned.'),
                        child: const Text('Assign officer'),
                      ),
                    ),
                  ],
                ),
                if (user.isSuperAdmin) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => repo.escalateComplaint(c.id, user.id),
                            'Complaint escalated to HOD.'),
                    icon: const Icon(Icons.trending_up),
                    label: const Text('Escalate to HOD'),
                  ),
                ],
                const SectionTitle('Messages with complainant'),
                if (c.isAnonymous)
                  const Text(
                    'Anonymous complaint — messaging is disabled to protect the complainant’s identity. Use public updates on the timeline instead.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  )
                else ...[
                  FutureBuilder<List<ComplaintMessage>>(
                    future: repo.getMessages(c.id),
                    builder: (context, mSnap) {
                      final messages = mSnap.data ?? [];
                      if (messages.isEmpty) {
                        return const Text('No messages yet.');
                      }
                      return Column(
                        children: messages
                            .map((m) => Align(
                                  alignment: m.senderId == user.id
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: m.senderId == user.id
                                          ? AppTheme.navy
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: AppTheme.divider),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(m.message,
                                            style: TextStyle(
                                                color:
                                                    m.senderId == user.id
                                                        ? Colors.white
                                                        : AppTheme
                                                            .textPrimary)),
                                        Text(timeAgo(m.createdAt),
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: m.senderId == user.id
                                                    ? Colors.white60
                                                    : AppTheme
                                                        .textSecondary)),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                      );
                    },
                  ),
                  if (canMessage) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatMessage,
                            decoration: const InputDecoration(
                                hintText: 'Reply to the complainant…'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                    await repo.sendMessage(
                                      complaintId: c.id,
                                      senderId: user.id,
                                      senderRole: user.role,
                                      message: _chatMessage.text,
                                    );
                                    _chatMessage.clear();
                                  }, 'Message sent.'),
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ],
                const SectionTitle('Feedback from student'),
                FutureBuilder<FeedbackItem?>(
                  future: repo.getFeedback(c.id),
                  builder: (context, fSnap) {
                    final fb = fSnap.data;
                    if (fb == null) {
                      return const Text(
                          'No feedback yet. Students can rate the resolution after it is resolved.',
                          style: TextStyle(color: AppTheme.textSecondary));
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(
                                  5,
                                  (i) => Icon(
                                        i < fb.rating
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: Colors.amber,
                                        size: 20,
                                      )),
                            ),
                            const SizedBox(height: 6),
                            Text(fb.actuallyResolved
                                ? 'Issue actually resolved: Yes'
                                : 'Issue actually resolved: No',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (fb.comments.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(fb.comments),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

final _officersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final officers = await repo.getUsers(role: 'dept_officer');
  final admins = await repo.getUsers(role: 'super_admin');
  return [...officers, ...admins];
});

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
