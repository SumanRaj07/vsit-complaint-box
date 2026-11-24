// Data models for VSIT Complaint Box.
// Every model has fromJson/toJson so the same classes work for the local
// repository (SharedPreferences JSON).

class UserProfile {
  final String id;
  final String fullName;
  final String collegeId;
  final String email;
  final String role; // student | staff | dept_officer | super_admin
  final String? departmentId;
  final String? classYear;
  final String? designation;
  final String accountStatus; // active | pending_approval | deactivated
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.collegeId,
    required this.email,
    required this.role,
    this.departmentId,
    this.classYear,
    this.designation,
    this.accountStatus = 'active',
    required this.createdAt,
  });

  bool get isStudent => role == 'student';
  bool get isStaff => role == 'staff';
  bool get isOfficer => role == 'dept_officer';
  bool get isSuperAdmin => role == 'super_admin';
  bool get isAdmin => isOfficer || isSuperAdmin;

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        fullName: j['full_name'] as String? ?? '',
        collegeId: j['college_id'] as String? ?? '',
        email: j['email'] as String? ?? '',
        role: j['role'] as String? ?? 'student',
        departmentId: j['department_id'] as String?,
        classYear: j['class_year'] as String?,
        designation: j['designation'] as String?,
        accountStatus: j['account_status'] as String? ?? 'active',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'college_id': collegeId,
        'email': email,
        'role': role,
        'department_id': departmentId,
        'class_year': classYear,
        'designation': designation,
        'account_status': accountStatus,
        'created_at': createdAt.toIso8601String(),
      };
}

class Department {
  final String id;
  final String name;
  final String description;
  final String? headOfficerId;
  final bool isActive;

  const Department({
    required this.id,
    required this.name,
    this.description = '',
    this.headOfficerId,
    this.isActive = true,
  });

  factory Department.fromJson(Map<String, dynamic> j) => Department(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        headOfficerId: j['head_officer_id'] as String?,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'head_officer_id': headOfficerId,
        'is_active': isActive,
      };
}

/// The 14 complaint categories from the specification.
const List<String> complaintCategories = [
  'Academic Issues',
  'Faculty-Related Issues',
  'Examination and Results',
  'College Administration',
  'Infrastructure',
  'Computer Laboratory',
  'Library',
  'Canteen',
  'Cleanliness and Hygiene',
  'Wi-Fi and Internet',
  'Fees and Accounts',
  'Harassment or Misconduct',
  'Transportation',
  'Other',
];

const List<String> complaintPriorities = ['low', 'medium', 'high', 'critical'];

class Complaint {
  final String id;
  final String trackingId;
  final String? userId;
  final String title;
  final String description;
  final String category;
  final String? departmentId;
  final String location;
  final String priority;
  final String status;
  final bool isAnonymous;
  final String? assignedOfficerId;
  final bool isEmergency;
  final String? rejectionReason;
  final DateTime? resolvedAt;
  final DateTime? escalatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Complaint({
    required this.id,
    required this.trackingId,
    this.userId,
    required this.title,
    required this.description,
    required this.category,
    this.departmentId,
    this.location = '',
    this.priority = 'medium',
    this.status = 'submitted',
    this.isAnonymous = false,
    this.assignedOfficerId,
    this.isEmergency = false,
    this.rejectionReason,
    this.resolvedAt,
    this.escalatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Complaint copyWith({
    String? status,
    String? priority,
    String? departmentId,
    String? assignedOfficerId,
    String? rejectionReason,
    DateTime? resolvedAt,
    DateTime? escalatedAt,
    DateTime? updatedAt,
  }) =>
      Complaint(
        id: id,
        trackingId: trackingId,
        userId: userId,
        title: title,
        description: description,
        category: category,
        departmentId: departmentId ?? this.departmentId,
        location: location,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        isAnonymous: isAnonymous,
        assignedOfficerId: assignedOfficerId ?? this.assignedOfficerId,
        isEmergency: isEmergency,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        escalatedAt: escalatedAt ?? this.escalatedAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
        id: j['id'] as String,
        trackingId: j['tracking_id'] as String? ?? '',
        userId: j['user_id'] as String?,
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        category: j['category'] as String? ?? 'Other',
        departmentId: j['department_id'] as String?,
        location: j['location'] as String? ?? '',
        priority: j['priority'] as String? ?? 'medium',
        status: j['status'] as String? ?? 'submitted',
        isAnonymous: j['is_anonymous'] as bool? ?? false,
        assignedOfficerId: j['assigned_officer_id'] as String?,
        isEmergency: j['is_emergency'] as bool? ?? false,
        rejectionReason: j['rejection_reason'] as String?,
        resolvedAt: j['resolved_at'] == null
            ? null
            : DateTime.tryParse(j['resolved_at'] as String),
        escalatedAt: j['escalated_at'] == null
            ? null
            : DateTime.tryParse(j['escalated_at'] as String),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tracking_id': trackingId,
        'user_id': userId,
        'title': title,
        'description': description,
        'category': category,
        'department_id': departmentId,
        'location': location,
        'priority': priority,
        'status': status,
        'is_anonymous': isAnonymous,
        'assigned_officer_id': assignedOfficerId,
        'is_emergency': isEmergency,
        'rejection_reason': rejectionReason,
        'resolved_at': resolvedAt?.toIso8601String(),
        'escalated_at': escalatedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class Attachment {
  final String id;
  final String complaintId;
  final String fileName;
  final String filePath;
  final String fileType;
  final int fileSizeBytes;

  const Attachment({
    required this.id,
    required this.complaintId,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    this.fileSizeBytes = 0,
  });

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: j['id'] as String,
        complaintId: j['complaint_id'] as String? ?? '',
        fileName: j['file_name'] as String? ?? '',
        filePath: j['file_path'] as String? ?? '',
        fileType: j['file_type'] as String? ?? '',
        fileSizeBytes: (j['file_size_bytes'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'complaint_id': complaintId,
        'file_name': fileName,
        'file_path': filePath,
        'file_type': fileType,
        'file_size_bytes': fileSizeBytes,
      };
}

class ComplaintUpdate {
  final String id;
  final String complaintId;
  final String? updatedBy;
  final String? oldStatus;
  final String newStatus;
  final String message;
  final String visibility; // public | internal
  final DateTime createdAt;

  const ComplaintUpdate({
    required this.id,
    required this.complaintId,
    this.updatedBy,
    this.oldStatus,
    required this.newStatus,
    this.message = '',
    this.visibility = 'public',
    required this.createdAt,
  });

  factory ComplaintUpdate.fromJson(Map<String, dynamic> j) =>
      ComplaintUpdate(
        id: j['id'] as String,
        complaintId: j['complaint_id'] as String? ?? '',
        updatedBy: j['updated_by'] as String?,
        oldStatus: j['old_status'] as String?,
        newStatus: j['new_status'] as String? ?? '',
        message: j['update_message'] as String? ?? '',
        visibility: j['visibility'] as String? ?? 'public',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'complaint_id': complaintId,
        'updated_by': updatedBy,
        'old_status': oldStatus,
        'new_status': newStatus,
        'update_message': message,
        'visibility': visibility,
        'created_at': createdAt.toIso8601String(),
      };
}

class ComplaintMessage {
  final String id;
  final String complaintId;
  final String? senderId;
  final String senderRole;
  final String message;
  final DateTime createdAt;

  const ComplaintMessage({
    required this.id,
    required this.complaintId,
    this.senderId,
    this.senderRole = 'student',
    required this.message,
    required this.createdAt,
  });

  factory ComplaintMessage.fromJson(Map<String, dynamic> j) =>
      ComplaintMessage(
        id: j['id'] as String,
        complaintId: j['complaint_id'] as String? ?? '',
        senderId: j['sender_id'] as String?,
        senderRole: j['sender_role'] as String? ?? 'student',
        message: j['message'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'complaint_id': complaintId,
        'sender_id': senderId,
        'sender_role': senderRole,
        'message': message,
        'created_at': createdAt.toIso8601String(),
      };
}

class AppNotification {
  final String id;
  final String userId;
  final String? complaintId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    this.complaintId,
    required this.title,
    this.message = '',
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: j['user_id'] as String? ?? '',
        complaintId: j['complaint_id'] as String?,
        title: j['title'] as String? ?? '',
        message: j['message'] as String? ?? '',
        isRead: j['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'complaint_id': complaintId,
        'title': title,
        'message': message,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };
}

class FeedbackItem {
  final String id;
  final String complaintId;
  final String? userId;
  final int rating;
  final bool actuallyResolved;
  final String comments;

  const FeedbackItem({
    required this.id,
    required this.complaintId,
    this.userId,
    required this.rating,
    this.actuallyResolved = true,
    this.comments = '',
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> j) => FeedbackItem(
        id: j['id'] as String,
        complaintId: j['complaint_id'] as String? ?? '',
        userId: j['user_id'] as String?,
        rating: (j['rating'] as num?)?.toInt() ?? 5,
        actuallyResolved: j['actually_resolved'] as bool? ?? true,
        comments: j['comments'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'complaint_id': complaintId,
        'user_id': userId,
        'rating': rating,
        'actually_resolved': actuallyResolved,
        'comments': comments,
      };
}

class AuditLog {
  final String id;
  final String? adminId;
  final String action;
  final String? complaintId;
  final String details;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    this.adminId,
    required this.action,
    this.complaintId,
    this.details = '',
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> j) => AuditLog(
        id: j['id'] as String,
        adminId: j['admin_id'] as String?,
        action: j['action'] as String? ?? '',
        complaintId: j['complaint_id'] as String?,
        details: j['details'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'admin_id': adminId,
        'action': action,
        'complaint_id': complaintId,
        'details': details,
        'created_at': createdAt.toIso8601String(),
      };
}

class Faq {
  final String id;
  final String question;
  final String answer;

  const Faq({required this.id, required this.question, required this.answer});

  factory Faq.fromJson(Map<String, dynamic> j) => Faq(
        id: j['id'] as String,
        question: j['question'] as String? ?? '',
        answer: j['answer'] as String? ?? '',
      );
}

class Suggestion {
  final String id;
  final String? userId;
  final String title;
  final String description;
  final bool isAnonymous;
  final String status;

  const Suggestion({
    required this.id,
    this.userId,
    required this.title,
    required this.description,
    this.isAnonymous = false,
    this.status = 'open',
  });

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
        id: j['id'] as String,
        userId: j['user_id'] as String?,
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        isAnonymous: j['is_anonymous'] as bool? ?? false,
        status: j['status'] as String? ?? 'open',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'is_anonymous': isAnonymous,
        'status': status,
      };
}

/// Aggregated numbers for the admin dashboard.
class ComplaintStats {
  final int total;
  final int newCount;
  final int pending;
  final int underInvestigation;
  final int resolved;
  final int critical;
  final double avgResolutionHours;
  final double resolutionPercent;

  const ComplaintStats({
    this.total = 0,
    this.newCount = 0,
    this.pending = 0,
    this.underInvestigation = 0,
    this.resolved = 0,
    this.critical = 0,
    this.avgResolutionHours = 0,
    this.resolutionPercent = 0,
  });
}
