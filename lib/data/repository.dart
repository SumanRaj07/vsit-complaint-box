import '../core/models.dart';

/// The data layer contract. Two implementations exist:
/// * [SupabaseRepository] — real backend (PostgreSQL + Auth + Storage).
/// * [LocalRepository] — on-device storage (SharedPreferences JSON),
///   the only backend: everything runs locally, no cloud needed.
/// Screens only ever talk to this interface, so the app works identically
/// in both modes.
abstract class ComplaintRepository {
  // ------------------------------------------------------------ auth
  Future<UserProfile?> signIn(String email, String password);
  Future<UserProfile> signUpStudent({
    required String fullName,
    required String collegeId,
    required String email,
    required String departmentId,
    required String classYear,
    required String password,
  });
  Future<UserProfile> signUpStaff({
    required String fullName,
    required String employeeId,
    required String email,
    required String departmentId,
    required String designation,
    required String password,
  });
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
  Future<UserProfile?> currentUser();
  Stream<UserProfile?> get authChanges;

  // ------------------------------------------------------------ lookups
  Future<List<Department>> getDepartments();
  Future<List<UserProfile>> getUsers({String? role, String? query});
  Future<List<Faq>> getFaqs();
  Future<Map<String, int>> getSlaHours();

  // ------------------------------------------------------------ complaints
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
  });
  Future<Complaint?> getComplaintById(String id);
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
  });
  Future<Complaint> updateComplaintStatus({
    required String complaintId,
    required String newStatus,
    required String updatedBy,
    String message = '',
    bool internal = false,
    String? rejectionReason,
  });
  Future<Complaint> updateComplaintPriority({
    required String complaintId,
    required String priority,
    required String updatedBy,
  });
  Future<Complaint> assignComplaint({
    required String complaintId,
    required String officerId,
    required String updatedBy,
  });
  Future<Complaint> assignDepartment({
    required String complaintId,
    required String departmentId,
    required String updatedBy,
  });
  Future<Complaint> reopenComplaint({
    required String complaintId,
    required String userId,
    required String reason,
  });

  /// Adds an internal investigation note (never visible to students).
  /// Does not change the complaint status.
  Future<void> addInternalNote({
    required String complaintId,
    required String updatedBy,
    required String note,
  });

  /// Anonymous status check: returns the complaint only when the tracking
  /// id AND the PIN hash match. Never returns identity fields.
  Future<Complaint?> trackAnonymous(String trackingId, String pinHash);

  /// Complaints that may duplicate this one (same category + department,
  /// similar title/description). Shown as a warning, never an auto-reject.
  Future<List<Complaint>> findPotentialDuplicates({
    required String title,
    required String description,
    required String category,
    required String departmentId,
  });

  // ------------------------------------------------------------ timeline / chat
  Future<List<ComplaintUpdate>> getUpdates(String complaintId,
      {bool includeInternal = false});
  Future<List<ComplaintMessage>> getMessages(String complaintId);
  Future<ComplaintMessage> sendMessage({
    required String complaintId,
    required String senderId,
    required String senderRole,
    required String message,
  });

  // ------------------------------------------------------------ attachments
  Future<List<Attachment>> getAttachments(String complaintId);

  // ------------------------------------------------------------ notifications
  Future<List<AppNotification>> getNotifications(String userId);
  Future<void> markNotificationRead(String notificationId);
  Future<void> markAllNotificationsRead(String userId);

  // ------------------------------------------------------------ feedback
  Future<FeedbackItem?> getFeedback(String complaintId);
  Future<FeedbackItem> submitFeedback({
    required String complaintId,
    required String userId,
    required int rating,
    required bool actuallyResolved,
    required String comments,
  });

  // ------------------------------------------------------------ admin
  Future<ComplaintStats> getStats({String? departmentId});
  Future<Map<String, int>> getComplaintsByCategory({String? departmentId});
  Future<Map<String, int>> getComplaintsByDepartment();
  Future<Map<String, int>> getComplaintsByMonth({int months = 6});
  Future<Map<String, int>> getComplaintsByPriority();
  Future<Map<String, double>> getDepartmentResolutionRates();
  Future<List<Complaint>> getOverdueComplaints();
  Future<void> escalateComplaint(String complaintId, String byUserId);
  Future<void> updateUserStatus(String userId, String status);
  Future<void> approveStaff(String userId);
  Future<void> updateDepartment(Department department);
  Future<Department> addDepartment(String name, String description);
  Future<void> setDepartmentActive(String departmentId, bool active);
  Future<List<AuditLog>> getAuditLogs({int limit = 100});
  Future<void> addAuditLog({
    required String adminId,
    required String action,
    String? complaintId,
    String details = '',
  });
  Future<void> updateSlaHours(Map<String, int> slaHours);

  // ------------------------------------------------------------ suggestions
  Future<List<Suggestion>> getSuggestions();
  Future<Suggestion> addSuggestion({
    required String title,
    required String description,
    required bool isAnonymous,
    String? userId,
  });
}

/// A file the user picked with the system picker (before upload).
class PickedFile {
  final String name;
  final String path;
  final String extension;
  final int sizeBytes;

  const PickedFile({
    required this.name,
    required this.path,
    required this.extension,
    required this.sizeBytes,
  });

  String get fileType {
    final e = extension.toLowerCase();
    if (e == 'pdf') return 'pdf';
    if (e == 'mp4') return 'video';
    return 'image';
  }
}
