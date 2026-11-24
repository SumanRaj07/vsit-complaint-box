/// App configuration. VSIT Complaint Box runs FULLY LOCALLY:
/// all data (users, complaints, messages, notifications) is stored on the
/// device (SharedPreferences) — no backend, no account, no internet needed.
/// The `supabase/` folder in this project is kept only as optional reference
/// SQL if the college ever wants a cloud backend; the app never uses it.
class AppConfig {

  static const String appName = 'VSIT Complaint Box';
  static const String tagline = 'Your Voice Matters. Your Campus Improves.';
  static const String collegeName =
      'Vidyalankar School of Information Technology';

  /// Max evidence size per file (MB) — must match the DB setting.
  static const int maxAttachmentMb = 25;

  /// Allowed evidence extensions.
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf', 'mp4'];

  /// Days within which a resolved complaint may be reopened.
  static const int reopenWindowDays = 7;

  /// SLA target hours per priority (must match app_settings in the DB).
  static const Map<String, int> slaHours = {
    'critical': 24,
    'high': 72,
    'medium': 120,
    'low': 240,
  };
}
