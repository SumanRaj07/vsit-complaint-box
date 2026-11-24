import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsit_complaint_box/core/utils.dart';
import 'package:vsit_complaint_box/data/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalRepository();
  });

  test('demo seed: departments and demo accounts exist', () async {
    final departments = await repo.getDepartments();
    expect(departments.length, 8);
    expect(departments.map((d) => d.name),
        contains('Information Technology'));

    final student =
        await repo.signIn('student@demo.vsit.edu', 'Demo@1234');
    expect(student, isNotNull);
    expect(student!.role, 'student');
    expect(student.fullName, 'Aarav Sharma');
  });

  test('wrong password is rejected', () async {
    expect(
      () => repo.signIn('student@demo.vsit.edu', 'wrong'),
      throwsA(isA<Exception>()),
    );
  });

  test('student registration then login', () async {
    final departments = await repo.getDepartments();
    final profile = await repo.signUpStudent(
      fullName: 'Test Student',
      collegeId: 'VSIT2026999',
      email: 'test@student.vsit.edu',
      departmentId: departments.first.id,
      classYear: 'FYBSc IT',
      password: 'secret123',
    );
    expect(profile.role, 'student');
    expect(profile.accountStatus, 'active');

    final loggedIn =
        await repo.signIn('test@student.vsit.edu', 'secret123');
    expect(loggedIn!.id, profile.id);
  });

  test('staff registration stays pending until approved', () async {
    final departments = await repo.getDepartments();
    final profile = await repo.signUpStaff(
      fullName: 'Test Staff',
      employeeId: 'EMP9999',
      email: 'test@staff.vsit.edu',
      departmentId: departments.first.id,
      designation: 'Assistant Professor',
      password: 'secret123',
    );
    expect(profile.accountStatus, 'pending_approval');
    expect(
      () => repo.signIn('test@staff.vsit.edu', 'secret123'),
      throwsA(isA<Exception>()),
    );
    await repo.approveStaff(profile.id);
    final loggedIn = await repo.signIn('test@staff.vsit.edu', 'secret123');
    expect(loggedIn, isNotNull);
  });

  test('full complaint lifecycle', () async {
    final student =
        (await repo.signIn('student@demo.vsit.edu', 'Demo@1234'))!;
    final departments = await repo.getDepartments();
    final dept = departments.firstWhere(
        (d) => d.name == 'Information Technology');

    final complaint = await repo.submitComplaint(
      title: 'Test complaint about lab PCs',
      description: 'Several PCs in the lab do not boot at all.',
      category: 'Computer Laboratory',
      departmentId: dept.id,
      location: 'Lab 2',
      priority: 'high',
      isAnonymous: false,
      isEmergency: false,
      userId: student.id,
    );
    expect(complaint.trackingId, startsWith('VSIT-'));
    expect(complaint.status, 'submitted');

    // Student sees it in their list.
    final mine = await repo.getComplaints(userId: student.id);
    expect(mine.map((c) => c.id), contains(complaint.id));

    // Officer workflow through the status machine.
    final officer =
        (await repo.signIn('officer@demo.vsit.edu', 'Demo@1234'))!;
    var updated = await repo.updateComplaintStatus(
      complaintId: complaint.id,
      newStatus: 'acknowledged',
      updatedBy: officer.id,
      message: 'Noted.',
    );
    expect(updated.status, 'acknowledged');

    // Illegal jump is rejected.
    expect(
      () => repo.updateComplaintStatus(
        complaintId: complaint.id,
        newStatus: 'resolved',
        updatedBy: officer.id,
      ),
      throwsA(isA<Exception>()),
    );

    updated = await repo.updateComplaintStatus(
      complaintId: complaint.id,
      newStatus: 'under_review',
      updatedBy: officer.id,
    );
    updated = await repo.updateComplaintStatus(
      complaintId: complaint.id,
      newStatus: 'action_taken',
      updatedBy: officer.id,
      message: 'PCs repaired.',
    );
    updated = await repo.updateComplaintStatus(
      complaintId: complaint.id,
      newStatus: 'resolved',
      updatedBy: officer.id,
      message: 'Fixed.',
    );
    expect(updated.status, 'resolved');
    expect(updated.resolvedAt, isNotNull);

    // Timeline has all public updates.
    final updates = await repo.getUpdates(complaint.id);
    expect(updates.length, greaterThanOrEqualTo(4));
    expect(updates.last.newStatus, 'resolved');

    // Feedback after resolution.
    final fb = await repo.submitFeedback(
      complaintId: complaint.id,
      userId: student.id,
      rating: 5,
      actuallyResolved: true,
      comments: 'Fixed quickly, thank you.',
    );
    expect(fb.rating, 5);

    // Reopen within the window works.
    final reopened = await repo.reopenComplaint(
      complaintId: complaint.id,
      userId: student.id,
      reason: 'One PC still does not boot.',
    );
    expect(reopened.status, 'reopened');
  });

  test('anonymous complaint tracked only with the right PIN', () async {
    final student =
        (await repo.signIn('student@demo.vsit.edu', 'Demo@1234'))!;
    final departments = await repo.getDepartments();
    const pin = '482917';
    final complaint = await repo.submitComplaint(
      title: 'Anonymous test complaint',
      description: 'Washroom taps leak on the second floor.',
      category: 'Cleanliness and Hygiene',
      departmentId: departments
          .firstWhere((d) => d.name == 'Infrastructure and Maintenance')
          .id,
      location: '2nd floor',
      priority: 'medium',
      isAnonymous: true,
      isEmergency: false,
      userId: student.id,
      pinHash: hashPin(pin),
    );
    expect(complaint.isAnonymous, isTrue);
    // Identity is not attached to the anonymous complaint.
    expect(complaint.userId, isNull);

    final found =
        await repo.trackAnonymous(complaint.trackingId, hashPin(pin));
    expect(found, isNotNull);
    expect(found!.trackingId, complaint.trackingId);

    final wrongPin =
        await repo.trackAnonymous(complaint.trackingId, hashPin('000000'));
    expect(wrongPin, isNull);
  });

  test('rejection needs a reason', () async {
    final officer =
        (await repo.signIn('officer@demo.vsit.edu', 'Demo@1234'))!;
    final complaints = await repo.getComplaints();
    final target = complaints.firstWhere((c) => c.status == 'submitted');
    expect(
      () => repo.updateComplaintStatus(
        complaintId: target.id,
        newStatus: 'rejected',
        updatedBy: officer.id,
      ),
      throwsA(isA<Exception>()),
    );
    final rejected = await repo.updateComplaintStatus(
      complaintId: target.id,
      newStatus: 'rejected',
      updatedBy: officer.id,
      rejectionReason: 'Duplicate of an existing complaint.',
    );
    expect(rejected.status, 'rejected');
    expect(rejected.rejectionReason, contains('Duplicate'));
  });

  test('stats and duplicate detection', () async {
    final stats = await repo.getStats();
    expect(stats.total, greaterThanOrEqualTo(4));
    expect(stats.resolved, greaterThanOrEqualTo(1));

    final dups = await repo.findPotentialDuplicates(
      title: 'Projector not working in Lab 3',
      description: 'The projector in Computer Lab 3 has not worked for two weeks.',
      category: 'Computer Laboratory',
      departmentId: 'dept-it',
    );
    expect(dups, isNotEmpty);
  });

  test('notifications: unread count drops after mark-all-read', () async {
    final student =
        (await repo.signIn('student@demo.vsit.edu', 'Demo@1234'))!;
    final before = await repo.getNotifications(student.id);
    expect(before.where((n) => !n.isRead), isNotEmpty);
    await repo.markAllNotificationsRead(student.id);
    final after = await repo.getNotifications(student.id);
    expect(after.where((n) => !n.isRead), isEmpty);
  });
}
