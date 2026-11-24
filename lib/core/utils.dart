import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

/// ---------------------------------------------------------------------------
/// Complaint tracking IDs: VSIT-2026-0001
/// ---------------------------------------------------------------------------
String nextTrackingId(int year, List<String> existingIds) {
  var maxN = 0;
  final re = RegExp('^VSIT-$year-(\\d+)\$');
  for (final id in existingIds) {
    final m = re.firstMatch(id);
    if (m != null) {
      maxN = max(maxN, int.tryParse(m.group(1)!) ?? 0);
    }
  }
  return 'VSIT-$year-${(maxN + 1).toString().padLeft(4, '0')}';
}

/// ---------------------------------------------------------------------------
/// Anonymous tracking PIN: a 6-digit PIN, stored only as a SHA-256 hash.
/// The plain PIN is shown to the user once and never stored.
/// ---------------------------------------------------------------------------
String generatePin({Random? random}) {
  final r = random ?? Random.secure();
  return (100000 + r.nextInt(900000)).toString();
}

String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

bool verifyPin(String pin, String hash) => hashPin(pin) == hash;

/// ---------------------------------------------------------------------------
/// Duplicate detection: word-overlap (Jaccard) similarity between two texts.
/// Returns 0.0–1.0. A complaint is "potentially duplicate" when the score is
/// >= [threshold] AND category + department match.
/// ---------------------------------------------------------------------------
double textSimilarity(String a, String b) {
  Set<String> words(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2)
      .toSet();
  final wa = words(a);
  final wb = words(b);
  if (wa.isEmpty || wb.isEmpty) return 0.0;
  final inter = wa.intersection(wb).length;
  final union = wa.union(wb).length;
  return inter / union;
}

bool isPotentialDuplicate({
  required String title,
  required String description,
  required String category,
  required String departmentId,
  required Map<String, dynamic> other,
  double threshold = 0.35,
}) {
  if (other['category'] != category) return false;
  if (other['department_id'] != departmentId) return false;
  final score = textSimilarity(
    '$title $description',
    '${other['title']} ${other['description']}',
  );
  return score >= threshold;
}

/// ---------------------------------------------------------------------------
/// SLA / escalation
/// ---------------------------------------------------------------------------
/// Hours left before a complaint breaches its SLA target. Negative = overdue.
double slaHoursLeft({
  required DateTime createdAt,
  required String priority,
  required Map<String, int> slaHours,
  DateTime? now,
}) {
  final target = slaHours[priority.toLowerCase()] ?? slaHours['medium']!;
  final deadline = createdAt.add(Duration(hours: target));
  return deadline.difference(now ?? DateTime.now()).inMinutes / 60.0;
}

bool isSlaBreached({
  required DateTime createdAt,
  required String priority,
  required Map<String, int> slaHours,
  DateTime? now,
}) =>
    slaHoursLeft(
      createdAt: createdAt,
      priority: priority,
      slaHours: slaHours,
      now: now,
    ) <
    0;

/// ---------------------------------------------------------------------------
/// Complaint status machine
/// ---------------------------------------------------------------------------
/// Legal next statuses for each status. Officers/admins may move a complaint
/// along this graph; students may only reopen a resolved complaint.
const Map<String, List<String>> allowedTransitions = {
  'submitted': ['acknowledged', 'rejected'],
  'acknowledged': ['under_review', 'info_required', 'rejected'],
  'under_review': ['investigation', 'info_required', 'action_taken', 'rejected'],
  'investigation': ['action_taken', 'info_required'],
  'info_required': ['under_review', 'investigation'],
  'action_taken': ['resolved', 'reopened'],
  'resolved': ['reopened', 'closed'],
  'reopened': ['under_review', 'investigation'],
  'closed': [],
  'rejected': [],
};

bool canTransition(String from, String to) =>
    allowedTransitions[from]?.contains(to) ?? false;

/// Statuses in which a student may reopen the complaint.
bool canReopen(String status, DateTime? resolvedAt, {DateTime? now}) {
  if (status != 'resolved' || resolvedAt == null) return false;
  final days = (now ?? DateTime.now()).difference(resolvedAt).inDays;
  return days <= 7;
}

/// ---------------------------------------------------------------------------
/// Labels, colours (as hex) and formatting
/// ---------------------------------------------------------------------------
const Map<String, String> statusLabels = {
  'submitted': 'Submitted',
  'acknowledged': 'Acknowledged',
  'under_review': 'Under Review',
  'investigation': 'Investigation',
  'info_required': 'Info Required',
  'action_taken': 'Action Taken',
  'resolved': 'Resolved',
  'reopened': 'Reopened',
  'closed': 'Closed',
  'rejected': 'Rejected',
};

const Map<String, int> statusColors = {
  'submitted': 0xFF5B6B8C,
  'acknowledged': 0xFF2E7D9E,
  'under_review': 0xFF8E6CC8,
  'investigation': 0xFFD97706,
  'info_required': 0xFFDC6B2F,
  'action_taken': 0xFF2F80ED,
  'resolved': 0xFF1E8E5A,
  'reopened': 0xFFB3261E,
  'closed': 0xFF6B7280,
  'rejected': 0xFF9E2B25,
};

const Map<String, int> priorityColors = {
  'low': 0xFF1E8E5A,
  'medium': 0xFF2F80ED,
  'high': 0xFFD97706,
  'critical': 0xFFB3261E,
};

String formatDateTime(DateTime d) =>
    DateFormat('dd MMM yyyy, hh:mm a').format(d);
String formatDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

String timeAgo(DateTime d, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDate(d);
}
