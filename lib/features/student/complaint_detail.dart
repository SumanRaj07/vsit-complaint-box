import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../common/widgets.dart';

/// Full detail of one complaint for the complainant:
/// header, timeline, messages with the admin, attachments,
/// feedback (after resolution) and reopen (within 7 days).
class ComplaintDetailScreen extends ConsumerStatefulWidget {
  final String complaintId;
  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  ConsumerState<ComplaintDetailScreen> createState() =>
      _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState
    extends ConsumerState<ComplaintDetailScreen> {
  final _messageController = TextEditingController();
  final _reopenReason = TextEditingController();
  int _rating = 0;
  final _feedbackComments = TextEditingController();
  bool _actuallyResolved = true;
  bool _busy = false;

  @override
  void dispose() {
    _messageController.dispose();
    _reopenReason.dispose();
    _feedbackComments.dispose();
    super.dispose();
  }

  Future<void> _refresh() async => setState(() {});

  Future<void> _sendMessage(Complaint c) async {
    final user = ref.read(sessionProvider);
    final text = _messageController.text.trim();
    if (user == null || text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).sendMessage(
            complaintId: c.id,
            senderId: user.id,
            senderRole: user.role,
            message: text,
          );
      _messageController.clear();
      await _refresh();
    } catch (e) {
      if (mounted) {
        showSnack(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitFeedback(Complaint c) async {
    final user = ref.read(sessionProvider);
    if (user == null || _rating == 0) {
      showSnack(context, 'Please choose a star rating.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).submitFeedback(
            complaintId: c.id,
            userId: user.id,
            rating: _rating,
            actuallyResolved: _actuallyResolved,
            comments: _feedbackComments.text,
          );
      if (mounted) {
        showSnack(context, 'Thank you for your feedback.');
        await _refresh();
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

  Future<void> _reopen(Complaint c) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Reopen complaint?',
      message:
          'The complaint will go back to Under Review. Only reopen if the issue is genuinely not resolved.',
      confirmLabel: 'Reopen',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).reopenComplaint(
            complaintId: c.id,
            userId: user.id,
            reason: _reopenReason.text.trim().isEmpty
                ? 'Issue not actually resolved.'
                : _reopenReason.text.trim(),
          );
      if (mounted) {
        showSnack(context, 'Complaint reopened.');
        await _refresh();
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

    return Scaffold(
      appBar: AppBar(title: const Text('Complaint Details')),
      body: FutureBuilder<Complaint?>(
        future: repo.getComplaintById(widget.complaintId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = snap.data;
          if (c == null) {
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
          final canMessage = !['closed', 'rejected'].contains(c.status);
          final showFeedback = (c.status == 'resolved' ||
                  c.status == 'closed') &&
              user != null;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(c.trackingId,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent)),
                      const SizedBox(width: 10),
                      StatusBadge(c.status),
                      const SizedBox(width: 8),
                      PriorityBadge(c.priority),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoRow('Category', c.category),
                  _InfoRow('Department', deptName),
                  if (c.location.isNotEmpty) _InfoRow('Location', c.location),
                  _InfoRow('Submitted', formatDateTime(c.createdAt)),
                  _InfoRow('Last updated', formatDateTime(c.updatedAt)),
                  if (c.resolvedAt != null)
                    _InfoRow('Resolved', formatDateTime(c.resolvedAt!)),
                  if (c.status == 'rejected' && c.rejectionReason != null)
                    Card(
                      color: const Color(0xFFFDECEA),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                            'Rejected: ${c.rejectionReason}',
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(c.description,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SectionTitle('Status timeline'),
                  FutureBuilder<List<ComplaintUpdate>>(
                    future: repo.getUpdates(c.id),
                    builder: (context, uSnap) {
                      final updates = uSnap.data ?? [];
                      if (updates.isEmpty) {
                        return const Text('No updates yet.',
                            style: TextStyle(color: AppTheme.textSecondary));
                      }
                      return Column(
                        children: updates
                            .map((u) => _TimelineTile(update: u))
                            .toList(),
                      );
                    },
                  ),
                  const SectionTitle('Attachments'),
                  FutureBuilder<List<Attachment>>(
                    future: repo.getAttachments(c.id),
                    builder: (context, aSnap) {
                      final atts = aSnap.data ?? [];
                      if (atts.isEmpty) {
                        return const Text('No attachments.',
                            style: TextStyle(color: AppTheme.textSecondary));
                      }
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
                  const SectionTitle('Messages'),
                  FutureBuilder<List<ComplaintMessage>>(
                    future: repo.getMessages(c.id),
                    builder: (context, mSnap) {
                      final messages = mSnap.data ?? [];
                      if (messages.isEmpty) {
                        return const Text(
                            'No messages yet. You can write to the assigned officer here.',
                            style: TextStyle(color: AppTheme.textSecondary));
                      }
                      return Column(
                        children: messages
                            .map((m) => _MessageBubble(
                                  message: m,
                                  isMine: m.senderId == user?.id,
                                ))
                            .toList(),
                      );
                    },
                  ),
                  if (canMessage) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                                hintText: 'Write a message to the officer…'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _busy ? null : () => _sendMessage(c),
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                  if (showFeedback) ...[
                    const SectionTitle('Your feedback'),
                    FutureBuilder<FeedbackItem?>(
                      future: repo.getFeedback(c.id),
                      builder: (context, fSnap) {
                        final existing = fSnap.data;
                        if (existing != null) {
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
                                              i < existing.rating
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.amber,
                                              size: 20,
                                            )),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                      existing.actuallyResolved
                                          ? 'Issue actually resolved: Yes'
                                          : 'Issue actually resolved: No',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  if (existing.comments.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(existing.comments),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('How satisfied are you?',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Row(
                                  children: List.generate(
                                      5,
                                      (i) => IconButton(
                                            onPressed: () => setState(
                                                () => _rating = i + 1),
                                            icon: Icon(
                                              i < _rating
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.amber,
                                              size: 30,
                                            ),
                                          )),
                                ),
                                SwitchListTile(
                                  title: const Text(
                                      'The issue was actually resolved'),
                                  value: _actuallyResolved,
                                  onChanged: (v) => setState(
                                      () => _actuallyResolved = v),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                TextField(
                                  controller: _feedbackComments,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Comments / suggestions',
                                    alignLabelWithHint: true,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed:
                                      _busy ? null : () => _submitFeedback(c),
                                  child: const Text('Submit feedback'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if (canReopen(c.status, c.resolvedAt)) ...[
                    const SizedBox(height: 20),
                    const Text('Issue not actually resolved?',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reopenReason,
                      decoration: const InputDecoration(
                        labelText: 'What is still pending?',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _reopen(c),
                      icon: const Icon(Icons.replay),
                      label: const Text('Request reopening'),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

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

class _TimelineTile extends StatelessWidget {
  final ComplaintUpdate update;
  const _TimelineTile({required this.update});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Color(
                    statusColors[update.newStatus] ?? 0xFF5B6B8C),
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 28, color: AppTheme.divider),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusLabels[update.newStatus] ?? update.newStatus,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (update.message.isNotEmpty)
                  Text(update.message,
                      style: Theme.of(context).textTheme.bodyMedium),
                Text(formatDateTime(update.createdAt),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ComplaintMessage message;
  final bool isMine;
  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.navy : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isMine ? null : Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMine
                  ? 'You'
                  : message.senderRole == 'super_admin'
                      ? 'Super Admin'
                      : 'Department Officer',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isMine ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.message,
              style: TextStyle(
                  color: isMine ? Colors.white : AppTheme.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              timeAgo(message.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: isMine ? Colors.white60 : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
