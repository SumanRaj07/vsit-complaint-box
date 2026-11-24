import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsit_complaint_box/core/providers.dart';
import 'package:vsit_complaint_box/data/local_repository.dart';
import 'package:vsit_complaint_box/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts on the login screen', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(LocalRepository()),
        ],
        child: const VsitComplaintBoxApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('VSIT Complaint Box'), findsWidgets);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('login as demo student opens the dashboard', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(LocalRepository()),
        ],
        child: const VsitComplaintBoxApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'College email'),
        'student@demo.vsit.edu');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'Demo@1234');
    await tester.ensureVisible(find.text('Log in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Namaste'), findsOneWidget);
    expect(find.text('Submit New Complaint'), findsOneWidget);
  });
}
