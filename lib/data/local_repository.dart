import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../core/models.dart';
import '../core/utils.dart';
import 'file_store.dart';
import 'repository.dart';

/// On-device local repository — the app's only backend.
///
/// Everything runs locally: all data lives in SharedPreferences as JSON.
/// Passwords are stored as salted SHA-256 hashes (never plain text).
/// A "Local mode" banner is shown in the UI, and nothing leaves the device.
///
/// Demo accounts (password `Demo@1234` for all):
/// student@demo.vsit.edu / staff@demo.vsit.edu / officer@demo.vsit.edu /
/// admin@demo.vsit.edu
class LocalRepository implements ComplaintRepository {
  static const _prefix = 'vsit_demo_';
  final StreamController<UserProfile?> _authController =
      StreamController<UserProfile?>.broadcast();

  UserProfile? _currentUser;
  bool _seeded = false;

  @override
  Stream<UserProfile?> get authChanges => _authController.stream;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  String _hashPassword(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();

  Future<void> _ensureSeeded() async {
    if (_seeded) return;
    final prefs = await _prefs;
    if (prefs.getBool('${_prefix}seeded') == true) {
      _seeded = true;
      return;
    }
    final now = DateTime.now();
    final rng = Random(42);
    String uid() =>
        '${rng.nextInt(1 << 32).toRadixString(16)}${now.microsecondsSinceEpoch}';

    // ---- departments
    final departments = <Department>[
      Department(id: 'dept-it', name: 'Information Technology',
          description: 'BSc IT programmes, IT labs and IT faculty matters'),
      Department(id: 'dept-cs', name: 'Computer Science',
          description: 'BSc Computer Science programmes and CS labs'),
      Department(id: 'dept-admin', name: 'Administration',
          description: 'General administration, admissions and student services'),
      Department(id: 'dept-exam', name: 'Examination Cell',
          description: 'Examinations, results, hall tickets and revaluation'),
      Department(id: 'dept-lib', name: 'Library',
          description: 'Central library, reading room and book bank'),
      Department(id: 'dept-accts', name: 'Accounts',
          description: 'Fees, receipts, scholarships and refunds'),
      Department(id: 'dept-infra', name: 'Infrastructure and Maintenance',
          description: 'Classrooms, washrooms, electricity, water and repairs'),
      Department(id: 'dept-welfare', name: 'Student Welfare',
          description: 'Student support, counselling, anti-ragging and grievances'),
    ];
    await _saveList('departments', departments.map((d) => d.toJson()).toList());

    // ---- demo users
    final users = <Map<String, dynamic>>[];
    void addUser(String id, String name, String collegeId, String email,
        String role, String dept, String? classYear, String status) {
      final salt = uid();
      users.add({
        'profile': UserProfile(
          id: id,
          fullName: name,
          collegeId: collegeId,
          email: email,
          role: role,
          departmentId: dept,
          classYear: classYear,
          accountStatus: status,
          createdAt: now,
        ).toJson(),
        'salt': salt,
        'password_hash': _hashPassword('Demo@1234', salt),
      });
    }

    addUser('demo-student', 'Aarav Sharma', 'VSIT2026001',
        'student@demo.vsit.edu', 'student', 'dept-it', 'SYBSc IT', 'active');
    addUser('demo-staff', 'Prof. Meera Nair', 'EMP1001',
        'staff@demo.vsit.edu', 'staff', 'dept-it', null, 'active');
    addUser('demo-officer', 'Mr. Rajesh Patil', 'EMP2001',
        'officer@demo.vsit.edu', 'dept_officer', 'dept-infra', null, 'active');
    addUser('demo-admin', 'Dr. S. Kulkarni', 'EMP9001',
        'admin@demo.vsit.edu', 'super_admin', 'dept-admin', null, 'active');
    await _saveList('users', users);

    // ---- sample complaints
    final complaints = <Complaint>[
      Complaint(
        id: 'c1',
        trackingId: 'VSIT-${now.year}-0001',
        userId: 'demo-student',
        title: 'Projector not working in Lab 3',
        description:
            'The projector in Computer Lab 3 has not worked for two weeks. Lectures are delayed every day.',
        category: 'Computer Laboratory',
        departmentId: 'dept-it',
        location: 'Computer Lab 3, 2nd floor',
        priority: 'high',
        status: 'under_review',
        assignedOfficerId: 'demo-officer',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Complaint(
        id: 'c2',
        trackingId: 'VSIT-${now.year}-0002',
        userId: 'demo-student',
        title: 'Wi-Fi disconnects frequently in library',
        description:
            'The library Wi-Fi disconnects every 10–15 minutes, making it impossible to study online.',
        category: 'Wi-Fi and Internet',
        departmentId: 'dept-lib',
        location: 'Central Library',
        priority: 'medium',
        status: 'submitted',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Complaint(
        id: 'c3',
        trackingId: 'VSIT-${now.year}-0003',
        userId: null,
        title: 'Unhygienic washrooms on 3rd floor',
        description:
            'The washrooms on the 3rd floor are not cleaned regularly and there is no water supply in the afternoon.',
        category: 'Cleanliness and Hygiene',
        departmentId: 'dept-infra',
        location: '3rd floor washrooms',
        priority: 'high',
        status: 'acknowledged',
        isAnonymous: true,
        assignedOfficerId: 'demo-officer',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      Complaint(
        id: 'c4',
        trackingId: 'VSIT-${now.year}-0004',
        userId: 'demo-student',
        title: 'Canteen food quality has dropped',
        description:
            'The food served in the canteen this month is stale and overpriced. Many students have complained informally.',
        category: 'Canteen',
        departmentId: 'dept-admin',
        location: 'College canteen',
        priority: 'low',
        status: 'resolved',
        resolvedAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 9)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
    await _saveList('complaints', complaints.map((c) => c.toJson()).toList());
    // store the anonymous PIN hash for the sample anonymous complaint (PIN 123456)
    await _saveList('pin_hashes', [
      {'tracking_id': 'VSIT-${now.year}-0003', 'hash': hashPin('123456')},
    ]);

    // ---- timeline entries for the samples
    final updates = <ComplaintUpdate>[
      ComplaintUpdate(
          id: 'u1', complaintId: 'c1', updatedBy: 'demo-officer',
          oldStatus: 'submitted', newStatus: 'acknowledged',
          message: 'Complaint received. The lab in-charge has been informed.',
          createdAt: now.subtract(const Duration(days: 3))),
      ComplaintUpdate(
          id: 'u2', complaintId: 'c1', updatedBy: 'demo-officer',
          oldStatus: 'acknowledged', newStatus: 'under_review',
          message: 'Technician visited Lab 3. A replacement lamp has been ordered.',
          createdAt: now.subtract(const Duration(days: 1))),
      ComplaintUpdate(
          id: 'u3', complaintId: 'c3', updatedBy: 'demo-officer',
          oldStatus: 'submitted', newStatus: 'acknowledged',
          message: 'Housekeeping supervisor has been asked to inspect the washrooms.',
          createdAt: now.subtract(const Duration(days: 2))),
      ComplaintUpdate(
          id: 'u4', complaintId: 'c4', updatedBy: 'demo-admin',
          oldStatus: 'action_taken', newStatus: 'resolved',
          message: 'Canteen vendor warned and menu revised. Quality check every Monday.',
          createdAt: now.subtract(const Duration(days: 1))),
    ];
    await _saveList('updates', updates.map((u) => u.toJson()).toList());

    await _saveList('messages', <Map<String, dynamic>>[]);
    await _saveList('attachments', <Map<String, dynamic>>[]);
    await _saveList('feedback', <Map<String, dynamic>>[]);
    await _saveList('audit_logs', <Map<String, dynamic>>[]);
    await _saveList('suggestions', <Map<String, dynamic>>[]);
    await _saveList('notifications', [
      AppNotification(
        id: 'n1',
        userId: 'demo-student',
        complaintId: 'c1',
        title: 'Complaint under review',
        message: 'Your complaint VSIT-${now.year}-0001 is now Under Review.',
        createdAt: now.subtract(const Duration(days: 1)),
      ).toJson(),
      AppNotification(
        id: 'n2',
        userId: 'demo-student',
        complaintId: 'c4',
        title: 'Complaint resolved',
        message: 'Your complaint VSIT-${now.year}-0004 has been resolved. Please rate it.',
        createdAt: now.subtract(const Duration(days: 1)),
      ).toJson(),
    ]);
    await _saveList('faqs', [
      {'id': 'f1', 'question': 'How do I track my complaint?',
       'answer': 'Open My Complaints and tap your complaint to see its full timeline. Anonymous complaints can be tracked from the Track Complaint screen using the tracking ID and the 6-digit PIN you chose while submitting.'},
      {'id': 'f2', 'question': 'Is my identity safe if I submit anonymously?',
       'answer': 'Yes. Anonymous complaints hide your name, email and roll number from department officers. Do not put your name inside the complaint text or inside attached files if you want to stay anonymous.'},
      {'id': 'f3', 'question': 'How long does a complaint take to resolve?',
       'answer': 'Target times are: Critical — 24 hours, High — 3 days, Medium — 5 days, Low — 10 days. If a complaint crosses its target time it is automatically escalated to the HOD.'},
      {'id': 'f4', 'question': 'Can I reopen a resolved complaint?',
       'answer': 'Yes, within 7 days of resolution, if the issue is not actually resolved. Open the complaint and tap Reopen, then explain what is still pending.'},
      {'id': 'f5', 'question': 'Is this an emergency service?',
       'answer': 'No. The Complaint Box is for college grievances. For fire, medical or safety emergencies, contact college security and the local emergency services immediately.'},
    ]);
    await prefs.setBool('${_prefix}seeded', true);
    _seeded = true;
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> items) async {
    final prefs = await _prefs;
    await prefs.setString('$_prefix$key', jsonEncode(items));
  }

  Future<List<Map<String, dynamic>>> _loadList(String key) async {
    await _ensureSeeded();
    final prefs = await _prefs;
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(9999)}';

  // ------------------------------------------------------------ auth
  @override
  Future<UserProfile?> signIn(String email, String password) async {
    final users = await _loadList('users');
    final match = users.where(
        (u) => (u['profile']['email'] as String).toLowerCase() ==
            email.trim().toLowerCase());
    if (match.isEmpty) throw Exception('No account found for this email.');
    final record = match.first;
    if (_hashPassword(password, record['salt'] as String) !=
        record['password_hash']) {
      throw Exception('Incorrect password.');
    }
    final profile = UserProfile.fromJson(record['profile']);
    if (profile.accountStatus == 'deactivated') {
      throw Exception('This account has been deactivated. Contact the admin.');
    }
    if (profile.accountStatus == 'pending_approval') {
      throw Exception(
          'Your staff registration is awaiting admin approval.');
    }
    _currentUser = profile;
    _authController.add(profile);
    return profile;
  }

  @override
  Future<UserProfile> signUpStudent({
    required String fullName,
    required String collegeId,
    required String email,
    required String departmentId,
    required String classYear,
    required String password,
  }) async {
    return _register(
      fullName: fullName,
      collegeId: collegeId,
      email: email,
      departmentId: departmentId,
      classYear: classYear,
      role: 'student',
      status: 'active',
      password: password,
    );
  }

  @override
  Future<UserProfile> signUpStaff({
    required String fullName,
    required String employeeId,
    required String email,
    required String departmentId,
    required String designation,
    required String password,
  }) async {
    final profile = await _register(
      fullName: fullName,
      collegeId: employeeId,
      email: email,
      departmentId: departmentId,
      role: 'staff',
      status: 'pending_approval',
      password: password,
      designation: designation,
    );
    return profile;
  }

  Future<UserProfile> _register({
    required String fullName,
    required String collegeId,
    required String email,
    required String departmentId,
    String? classYear,
    String? designation,
    required String role,
    required String status,
    required String password,
  }) async {
    final users = await _loadList('users');
    if (users.any((u) =>
        (u['profile']['email'] as String).toLowerCase() ==
        email.trim().toLowerCase())) {
      throw Exception('An account with this email already exists.');
    }
    if (users.any((u) =>
        (u['profile']['college_id'] as String).toLowerCase() ==
        collegeId.trim().toLowerCase())) {
      throw Exception('An account with this college ID already exists.');
    }
    final salt = _newId();
    final profile = UserProfile(
      id: _newId(),
      fullName: fullName,
      collegeId: collegeId,
      email: email,
      role: role,
      departmentId: departmentId,
      classYear: classYear,
      designation: designation,
      accountStatus: status,
      createdAt: DateTime.now(),
    );
    users.add({
      'profile': profile.toJson(),
      'salt': salt,
      'password_hash': _hashPassword(password, salt),
    });
    await _saveList('users', users);
    return profile;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authController.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final users = await _loadList('users');
    final exists = users.any((u) =>
        (u['profile']['email'] as String).toLowerCase() ==
        email.trim().toLowerCase());
    if (!exists) throw Exception('No account found for this email.');
    // Local-only app: there is no email service, so a reset link cannot
    // be sent. The Super Admin resets passwords from User Management.
    return;
  }

  @override
  Future<UserProfile?> currentUser() async {
    await _ensureSeeded();
    return _currentUser;
  }

  // ------------------------------------------------------------ lookups
  @override
  Future<List<Department>> getDepartments() async {
    final items = await _loadList('departments');
    return items.map(Department.fromJson).toList();
  }

  @override
  Future<List<UserProfile>> getUsers({String? role, String? query}) async {
    final users = await _loadList('users');
    var list = users.map((u) => UserProfile.fromJson(u['profile'])).toList();
    if (role != null) list = list.where((u) => u.role == role).toList();
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      list = list
          .where((u) =>
              u.fullName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              u.collegeId.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Future<List<Faq>> getFaqs() async {
    final items = await _loadList('faqs');
    return items.map(Faq.fromJson).toList();
  }

  @override
  Future<Map<String, int>> getSlaHours() async =>
      Map<String, int>.from(AppConfig.slaHours);

  // ------------------------------------------------------------ complaints
  Future<List<Complaint>> _allComplaints() async {
    final items = await _loadList('complaints');
    final list = items.map(Complaint.fromJson).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _saveComplaints(List<Complaint> list) =>
      _saveList('complaints', list.map((c) => c.toJson()).toList());

  Future<void> _addUpdate(ComplaintUpdate update) async {
    final items = await _loadList('updates');
    items.add(update.toJson());
    await _saveList('updates', items);
  }

  Future<void> _notify(String userId, String title, String message,
      {String? complaintId}) async {
    final items = await _loadList('notifications');
    items.add(AppNotification(
      id: _newId(),
      userId: userId,
      complaintId: complaintId,
      title: title,
      message: message,
      createdAt: DateTime.now(),
    ).toJson());
    await _saveList('notifications', items);
  }

  @override
  Future<List<Complaint>> getComplaints({
    String? userId,
    String? departmentId,
    String? status,
    String? category,
    String? priority,
    String? query,
    bool? anonymousOnly,
    DateTime? from,
    DateTime? to,
  }) async {
    var list = await _allComplaints();
    if (userId != null) list = list.where((c) => c.userId == userId).toList();
    if (departmentId != null) {
      list = list.where((c) => c.departmentId == departmentId).toList();
    }
    if (status != null) list = list.where((c) => c.status == status).toList();
    if (category != null) {
      list = list.where((c) => c.category == category).toList();
    }
    if (priority != null) {
      list = list.where((c) => c.priority == priority).toList();
    }
    if (anonymousOnly == true) {
      list = list.where((c) => c.isAnonymous).toList();
    }
    if (from != null) {
      list = list.where((c) => c.createdAt.isAfter(from)).toList();
    }
    if (to != null) list = list.where((c) => c.createdAt.isBefore(to)).toList();
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      list = list
          .where((c) =>
              c.trackingId.toLowerCase().contains(q) ||
              c.title.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Future<Complaint?> getComplaintById(String id) async {
    final list = await _allComplaints();
    try {
      return list.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Complaint> submitComplaint({
    required String title,
    required String description,
    required String category,
    required String departmentId,
    required String location,
    required String priority,
    required bool isAnonymous,
    required bool isEmergency,
    String? userId,
    String? pinHash,
    List<PickedFile> attachments = const [],
  }) async {
    final list = await _allComplaints();
    final trackingId = nextTrackingId(
        DateTime.now().year, list.map((c) => c.trackingId).toList());
    final now = DateTime.now();
    final complaint = Complaint(
      id: _newId(),
      trackingId: trackingId,
      userId: isAnonymous ? null : userId,
      title: title.trim(),
      description: description.trim(),
      category: category,
      departmentId: departmentId,
      location: location.trim(),
      priority: priority,
      status: 'submitted',
      isAnonymous: isAnonymous,
      isEmergency: isEmergency,
      createdAt: now,
      updatedAt: now,
    );
    list.add(complaint);
    await _saveComplaints(list);
    if (isAnonymous && pinHash != null) {
      final pins = await _loadList('pin_hashes');
      pins.add({'tracking_id': trackingId, 'hash': pinHash});
      await _saveList('pin_hashes', pins);
    }
    final atts = await _loadList('attachments');
    for (final f in attachments) {
      // Copy into the app's own folder so the evidence survives the
      // system picker's cache being cleared.
      final storedPath = await persistEvidenceFile(f.path, f.name);
      atts.add(Attachment(
        id: _newId(),
        complaintId: complaint.id,
        fileName: f.name,
        filePath: storedPath,
        fileType: f.fileType,
        fileSizeBytes: f.sizeBytes,
      ).toJson());
    }
    await _saveList('attachments', atts);
    await _addUpdate(ComplaintUpdate(
      id: _newId(),
      complaintId: complaint.id,
      newStatus: 'submitted',
      message: 'Complaint submitted.',
      createdAt: now,
    ));
    if (userId != null && !isAnonymous) {
      await _notify(userId, 'Complaint submitted',
          'Your complaint $trackingId was submitted successfully.',
          complaintId: complaint.id);
    }
    return complaint;
  }

  @override
  Future<Complaint> updateComplaintStatus({
    required String complaintId,
    required String newStatus,
    required String updatedBy,
    String message = '',
    bool internal = false,
    String? rejectionReason,
  }) async {
    final list = await _allComplaints();
    final idx = list.indexWhere((c) => c.id == complaintId);
    if (idx == -1) throw Exception('Complaint not found.');
    final old = list[idx];
    if (!canTransition(old.status, newStatus)) {
      throw Exception(
          'Cannot move a complaint from ${old.status} to $newStatus.');
    }
    if (newStatus == 'rejected' &&
        (rejectionReason == null || rejectionReason.trim().isEmpty)) {
      throw Exception('A reason is mandatory when rejecting a complaint.');
    }
    final updated = old.copyWith(
      status: newStatus,
      rejectionReason: newStatus == 'rejected' ? rejectionReason : null,
      resolvedAt: newStatus == 'resolved' ? DateTime.now() : old.resolvedAt,
    );
    list[idx] = updated;
    await _saveComplaints(list);
    await _addUpdate(ComplaintUpdate(
      id: _newId(),
      complaintId: complaintId,
      updatedBy: updatedBy,
      oldStatus: old.status,
      newStatus: newStatus,
      message: message.isEmpty
          ? 'Status changed to ${statusLabels[newStatus] ?? newStatus}.'
          : message,
      visibility: internal ? 'internal' : 'public',
      createdAt: DateTime.now(),
    ));
    if (updated.userId != null && !internal) {
      await _notify(
          updated.userId!,
          'Complaint ${statusLabels[newStatus] ?? newStatus}',
          '${updated.trackingId}: ${message.isEmpty ? 'Status updated.' : message}',
          complaintId: complaintId);
    }
    return updated;
  }

  @override
  Future<Complaint> updateComplaintPriority({
    required String complaintId,
    required String priority,
    required String updatedBy,
  }) async {
    final list = await _allComplaints();
    final idx = list.indexWhere((c) => c.id == complaintId);
    if (idx == -1) throw Exception('Complaint not found.');
    final updated = list[idx].copyWith(priority: priority);
    list[idx] = updated;
    await _saveComplaints(list);
    await _addUpdate(ComplaintUpdate(
      id: _newId(),
      complaintId: complaintId,
      updatedBy: updatedBy,
      oldStatus: list[idx].status,
      newStatus: list[idx].status,
      message: 'Priority changed to ${priority.toUpperCase()}.',
      visibility: 'internal',
      createdAt: DateTime.now(),
    ));
    return updated;
  }

  @override
  Future<Complaint> assignComplaint({
    required String complaintId,
    required String officerId,
    required String updatedBy,
  }) async {
    final list = await _allComplaints();
    final idx = list.indexWhere((c) => c.id == complaintId);
    if (idx == -1) throw Exception('Complaint not found.');
    final updated = list[idx].copyWith(assignedOfficerId: officerId);
    list[idx] = updated;
    await _saveComplaints(list);
    await _addUpdate(ComplaintUpdate(
      id: _newId(),
      complaintId: complaintId,
      updatedBy: updatedBy,
      oldStatus: list[idx].status,
      newStatus: list[idx].status,
      message: 'Complaint assigned to an officer.',
      visibility: 'internal',
      createdAt: DateTime.now(),
    ));
    await _notify(officerId, 'Complaint assigned',
        '${updated.trackingId} has been assigned to you.',
        complaintId: complaintId);
    return updated;
  }

  @override
  Future<Complaint> assignDepartment({
    required String complaintId,
    required String departmentId,
    required String updatedBy,
  }) async {
    final list = await _allComplaints();
    final idx = list.indexWhere((c) => c.id == complaintId);
    if (idx == -1) throw Exception('Complaint not found.');
    final updated = list[idx].copyWith(departmentId: departmentId);
    list[idx] = updated;
    await _saveComplaints(list);
    await _addUpdate(ComplaintUpdate(
      id: _newId(),
      complaintId: complaintId,
      updatedBy: updatedBy,
      oldStatus: list[idx].status,
      newStatus: list[idx].status,
      message: 'Complaint moved to another department.',
      visibility: 'internal',
      createdAt: DateTime.now(),
    ));
    return updated;
  }

  @override
  Future<Complaint> reopenComplaint({
    required String complaintId,
    required String userId,
    required String reason,
  }) async {
    final list = await _allComplaints();
    final idx = list.indexWhere((c) => c.id == complaintId);
    if (idx == -1) throw Exception('Complaint not found.');
    final old = list[idx];
    if (!canReopen(old.status, old.resolvedAt)) {
      throw Exception(
          'This complaint can no longer be reopened (only within 7 days of resolution).');
    }
    final updated = old.copyWith(status: 'reopened');
    list[idx] = updated;
    await _saveComplaints(list);
    await _addUpdate(ComplaintUpdate(
      id: _newId(),
      complaintId: complaintId,
      updatedBy: userId,
      oldStatus: 'resolved',
      newStatus: 'reopened',
      message: 'Reopened by student: $reason',
      createdAt: DateTime.now(),
    ));
    return updated;
  }

  @override
  Future<void> addInternalNote({
    required String complaintId,
    required String updatedBy,
    required String note,
  }) async {
    final complaint = await getComplaintById(complaintId);
    if (complaint == null) throw Exception('Complaint not found.');
    await _addUpdate(ComplaintUpdate(
      id: _newId(),
      complaintId: complaintId,
      updatedBy: updatedBy,
      oldStatus: complaint.status,
      newStatus: complaint.status,
      message: note.trim(),
      visibility: 'internal',
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<Complaint?> trackAnonymous(String trackingId, String pinHash) async {
    final pins = await _loadList('pin_hashes');
    final ok = pins.any((p) =>
        p['tracking_id'] == trackingId.trim().toUpperCase() &&
        p['hash'] == pinHash);
    if (!ok) return null;
    final list = await _allComplaints();
    try {
      return list.firstWhere(
          (c) => c.trackingId == trackingId.trim().toUpperCase());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Complaint>> findPotentialDuplicates({
    required String title,
    required String description,
    required String category,
    required String departmentId,
  }) async {
    final list = await _allComplaints();
    return list
        .where((c) => isPotentialDuplicate(
              title: title,
              description: description,
              category: category,
              departmentId: departmentId,
              other: c.toJson(),
            ))
        .toList();
  }

  // ------------------------------------------------------------ timeline / chat
  @override
  Future<List<ComplaintUpdate>> getUpdates(String complaintId,
      {bool includeInternal = false}) async {
    final items = await _loadList('updates');
    var list = items
        .map(ComplaintUpdate.fromJson)
        .where((u) => u.complaintId == complaintId)
        .toList();
    if (!includeInternal) {
      list = list.where((u) => u.visibility == 'public').toList();
    }
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<List<ComplaintMessage>> getMessages(String complaintId) async {
    final items = await _loadList('messages');
    final list = items
        .map(ComplaintMessage.fromJson)
        .where((m) => m.complaintId == complaintId)
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<ComplaintMessage> sendMessage({
    required String complaintId,
    required String senderId,
    required String senderRole,
    required String message,
  }) async {
    final msg = ComplaintMessage(
      id: _newId(),
      complaintId: complaintId,
      senderId: senderId,
      senderRole: senderRole,
      message: message.trim(),
      createdAt: DateTime.now(),
    );
    final items = await _loadList('messages');
    items.add(msg.toJson());
    await _saveList('messages', items);
    final complaint = await getComplaintById(complaintId);
    if (complaint != null) {
      if (senderRole == 'student' && complaint.assignedOfficerId != null) {
        await _notify(complaint.assignedOfficerId!, 'New message',
            'A student replied on ${complaint.trackingId}.',
            complaintId: complaintId);
      } else if (senderRole != 'student' && complaint.userId != null) {
        await _notify(complaint.userId!, 'New message from admin',
            'An officer replied on ${complaint.trackingId}.',
            complaintId: complaintId);
      }
    }
    return msg;
  }

  // ------------------------------------------------------------ attachments
  @override
  Future<List<Attachment>> getAttachments(String complaintId) async {
    final items = await _loadList('attachments');
    return items
        .map(Attachment.fromJson)
        .where((a) => a.complaintId == complaintId)
        .toList();
  }

  // ------------------------------------------------------------ notifications
  @override
  Future<List<AppNotification>> getNotifications(String userId) async {
    final items = await _loadList('notifications');
    final list = items
        .map(AppNotification.fromJson)
        .where((n) => n.userId == userId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    final items = await _loadList('notifications');
    final idx = items.indexWhere((n) => n['id'] == notificationId);
    if (idx != -1) {
      items[idx]['is_read'] = true;
      await _saveList('notifications', items);
    }
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    final items = await _loadList('notifications');
    var changed = false;
    for (final n in items) {
      if (n['user_id'] == userId && n['is_read'] == false) {
        n['is_read'] = true;
        changed = true;
      }
    }
    if (changed) await _saveList('notifications', items);
  }

  // ------------------------------------------------------------ feedback
  @override
  Future<FeedbackItem?> getFeedback(String complaintId) async {
    final items = await _loadList('feedback');
    try {
      return items
          .map(FeedbackItem.fromJson)
          .firstWhere((f) => f.complaintId == complaintId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FeedbackItem> submitFeedback({
    required String complaintId,
    required String userId,
    required int rating,
    required bool actuallyResolved,
    required String comments,
  }) async {
    final items = await _loadList('feedback');
    items.removeWhere((f) => f['complaint_id'] == complaintId);
    final fb = FeedbackItem(
      id: _newId(),
      complaintId: complaintId,
      userId: userId,
      rating: rating,
      actuallyResolved: actuallyResolved,
      comments: comments.trim(),
    );
    items.add(fb.toJson());
    await _saveList('feedback', items);
    return fb;
  }

  // ------------------------------------------------------------ admin
  @override
  Future<ComplaintStats> getStats({String? departmentId}) async {
    var list = await _allComplaints();
    if (departmentId != null) {
      list = list.where((c) => c.departmentId == departmentId).toList();
    }
    int count(String s) => list.where((c) => c.status == s).length;
    final resolved =
        list.where((c) => c.status == 'resolved' || c.status == 'closed');
    double avgHours = 0;
    if (resolved.isNotEmpty) {
      var total = 0.0;
      var n = 0;
      for (final c in resolved) {
        if (c.resolvedAt != null) {
          total +=
              c.resolvedAt!.difference(c.createdAt).inMinutes / 60.0;
          n++;
        }
      }
      if (n > 0) avgHours = total / n;
    }
    final closed = list
        .where((c) =>
            ['resolved', 'closed'].contains(c.status) ||
            c.status == 'rejected')
        .length;
    return ComplaintStats(
      total: list.length,
      newCount: count('submitted'),
      pending: list
          .where((c) => !['resolved', 'closed', 'rejected'].contains(c.status))
          .length,
      underInvestigation:
          count('investigation') + count('under_review'),
      resolved: count('resolved') + count('closed'),
      critical: list.where((c) => c.priority == 'critical').length,
      avgResolutionHours: avgHours,
      resolutionPercent:
          list.isEmpty ? 0 : (closed / list.length) * 100,
    );
  }

  @override
  Future<Map<String, int>> getComplaintsByCategory(
      {String? departmentId}) async {
    var list = await _allComplaints();
    if (departmentId != null) {
      list = list.where((c) => c.departmentId == departmentId).toList();
    }
    final map = <String, int>{};
    for (final c in list) {
      map[c.category] = (map[c.category] ?? 0) + 1;
    }
    return map;
  }

  @override
  Future<Map<String, int>> getComplaintsByDepartment() async {
    final list = await _allComplaints();
    final depts = await getDepartments();
    final names = {for (final d in depts) d.id: d.name};
    final map = <String, int>{};
    for (final c in list) {
      final name = names[c.departmentId] ?? 'Unassigned';
      map[name] = (map[name] ?? 0) + 1;
    }
    return map;
  }

  @override
  Future<Map<String, int>> getComplaintsByMonth({int months = 6}) async {
    final list = await _allComplaints();
    final map = <String, int>{};
    final now = DateTime.now();
    for (var i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      map[key] = 0;
    }
    for (final c in list) {
      final key =
          '${c.createdAt.year}-${c.createdAt.month.toString().padLeft(2, '0')}';
      if (map.containsKey(key)) map[key] = map[key]! + 1;
    }
    return map;
  }

  @override
  Future<Map<String, int>> getComplaintsByPriority() async {
    final list = await _allComplaints();
    final map = <String, int>{};
    for (final c in list) {
      map[c.priority] = (map[c.priority] ?? 0) + 1;
    }
    return map;
  }

  @override
  Future<Map<String, double>> getDepartmentResolutionRates() async {
    final list = await _allComplaints();
    final depts = await getDepartments();
    final names = {for (final d in depts) d.id: d.name};
    final totals = <String, int>{};
    final done = <String, int>{};
    for (final c in list) {
      final name = names[c.departmentId] ?? 'Unassigned';
      totals[name] = (totals[name] ?? 0) + 1;
      if (['resolved', 'closed'].contains(c.status)) {
        done[name] = (done[name] ?? 0) + 1;
      }
    }
    return {
      for (final name in totals.keys)
        name: totals[name] == 0
            ? 0
            : (done[name] ?? 0) / totals[name]! * 100,
    };
  }

  @override
  Future<List<Complaint>> getOverdueComplaints() async {
    final list = await _allComplaints();
    return list
        .where((c) =>
            !['resolved', 'closed', 'rejected'].contains(c.status) &&
            isSlaBreached(
              createdAt: c.createdAt,
              priority: c.priority,
              slaHours: AppConfig.slaHours,
            ))
        .toList();
  }

  @override
  Future<void> escalateComplaint(String complaintId, String byUserId) async {
    final list = await _allComplaints();
    final idx = list.indexWhere((c) => c.id == complaintId);
    if (idx == -1) return;
    final updated = list[idx].copyWith(escalatedAt: DateTime.now());
    list[idx] = updated;
    await _saveComplaints(list);
    await _addUpdate(ComplaintUpdate(
      id: _newId(),
      complaintId: complaintId,
      updatedBy: byUserId,
      oldStatus: updated.status,
      newStatus: updated.status,
      message: 'Escalated to HOD: SLA target breached.',
      visibility: 'internal',
      createdAt: DateTime.now(),
    ));
    final admins = await getUsers(role: 'super_admin');
    for (final a in admins) {
      await _notify(a.id, 'Complaint escalated',
          '${updated.trackingId} breached its SLA and was escalated.',
          complaintId: complaintId);
    }
  }

  @override
  Future<void> updateUserStatus(String userId, String status) async {
    final users = await _loadList('users');
    final idx =
        users.indexWhere((u) => u['profile']['id'] == userId);
    if (idx == -1) return;
    users[idx]['profile']['account_status'] = status;
    await _saveList('users', users);
    if (_currentUser?.id == userId) {
      _currentUser = UserProfile.fromJson(users[idx]['profile']);
      _authController.add(_currentUser);
    }
  }

  @override
  Future<void> approveStaff(String userId) =>
      updateUserStatus(userId, 'active');

  @override
  Future<void> updateDepartment(Department department) async {
    final items = await _loadList('departments');
    final idx = items.indexWhere((d) => d['id'] == department.id);
    if (idx == -1) return;
    items[idx] = department.toJson();
    await _saveList('departments', items);
  }

  @override
  Future<Department> addDepartment(String name, String description) async {
    final dept = Department(
      id: _newId(),
      name: name.trim(),
      description: description.trim(),
    );
    final items = await _loadList('departments');
    if (items.any((d) =>
        (d['name'] as String).toLowerCase() == name.trim().toLowerCase())) {
      throw Exception('A department with this name already exists.');
    }
    items.add(dept.toJson());
    await _saveList('departments', items);
    return dept;
  }

  @override
  Future<void> setDepartmentActive(String departmentId, bool active) async {
    final items = await _loadList('departments');
    final idx = items.indexWhere((d) => d['id'] == departmentId);
    if (idx == -1) return;
    items[idx]['is_active'] = active;
    await _saveList('departments', items);
  }

  @override
  Future<List<AuditLog>> getAuditLogs({int limit = 100}) async {
    final items = await _loadList('audit_logs');
    final list = items.map(AuditLog.fromJson).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  @override
  Future<void> addAuditLog({
    required String adminId,
    required String action,
    String? complaintId,
    String details = '',
  }) async {
    final items = await _loadList('audit_logs');
    items.add(AuditLog(
      id: _newId(),
      adminId: adminId,
      action: action,
      complaintId: complaintId,
      details: details,
      createdAt: DateTime.now(),
    ).toJson());
    await _saveList('audit_logs', items);
  }

  @override
  Future<void> updateSlaHours(Map<String, int> slaHours) async {
    // Local-only app: SLA hours are fixed in AppConfig.
    return;
  }

  // ------------------------------------------------------------ suggestions
  @override
  Future<List<Suggestion>> getSuggestions() async {
    final items = await _loadList('suggestions');
    return items.map(Suggestion.fromJson).toList();
  }

  @override
  Future<Suggestion> addSuggestion({
    required String title,
    required String description,
    required bool isAnonymous,
    String? userId,
  }) async {
    final s = Suggestion(
      id: _newId(),
      userId: isAnonymous ? null : userId,
      title: title.trim(),
      description: description.trim(),
      isAnonymous: isAnonymous,
    );
    final items = await _loadList('suggestions');
    items.add(s.toJson());
    await _saveList('suggestions', items);
    return s;
  }
}
