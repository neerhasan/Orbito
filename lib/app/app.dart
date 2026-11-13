import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/areas/areas_page.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/focus/focus_page.dart';
import '../features/goals/goals_page.dart';
import '../features/habits/habits_page.dart';
import '../features/inbox/inbox_page.dart';
import '../features/projects/projects_page.dart';
import '../features/settings/settings_page.dart';
import '../features/setup/setup_page.dart';
import '../features/sleep/sleep_page.dart';
import '../features/tasks/tasks_page.dart';
import '../features/today/today_page.dart';
import '../ui/ember.dart';
import '../ui/widgets.dart';
import 'providers.dart';
import 'shell.dart';

/// The app once the keys are in place: the sign-in screen, or the app frame
/// with its pages.
class OrbitoApp extends ConsumerWidget {
  const OrbitoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return MaterialApp(
      title: 'Orbito',
      debugShowCheckedModeBanner: false,
      theme: Ember.theme(),
      home: user.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(
          body: Center(
            child: Text(
              'Sign-in problem: $error',
              style: Ember.body.copyWith(color: Ember.onShell),
            ),
          ),
        ),
        data: (signedIn) => signedIn == null
            ? const SignInScreen()
            : AppShell(
                key: ValueKey(signedIn.id),
                email: signedIn.email ?? signedIn.id,
                pageBuilder: buildPage,
              ),
      ),
    );
  }
}

/// The content of each page.
Widget buildPage(AppPage page) => PageHost(page: page);

/// Shows the open page, or the first-run setup while the user has no life
/// areas yet.
class PageHost extends ConsumerWidget {
  const PageHost({super.key, required this.page});

  final AppPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(lifeAreasProvider);
    if (areas.isLoading && !areas.hasValue) {
      return const PageLayout(
        main: [Center(child: CircularProgressIndicator())],
      );
    }
    final noAreas = areas.value?.isEmpty ?? true;
    if (noAreas && !ref.watch(setupSkippedProvider)) {
      return const SetupPage();
    }
    return switch (page) {
      AppPage.areas => const AreasPage(),
      AppPage.projects => const ProjectsPage(),
      AppPage.goals => const GoalsPage(),
      AppPage.tasks => const TasksPage(),
      AppPage.today => const TodayPage(),
      AppPage.inbox => const InboxPage(),
      AppPage.settings => const SettingsPage(),
      AppPage.habits => const HabitsPage(),
      AppPage.sleep => const SleepPage(),
      AppPage.focus => const FocusPage(),
    };
  }
}

/// Shown instead of the app when the `.env` file is missing values.
class SetupNeededApp extends StatelessWidget {
  const SetupNeededApp({super.key, required this.missing});

  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orbito',
      debugShowCheckedModeBanner: false,
      theme: Ember.theme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Ember.paper,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orbito is not set up yet',
                      style: Ember.h1Small.copyWith(color: Ember.ink),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'These values are missing from the .env file in the '
                      'project folder:',
                    ),
                    const SizedBox(height: 8),
                    for (final name in missing) Text('•  $name'),
                    const SizedBox(height: 12),
                    const Text(
                      'Fill them in, then stop the app and start it again. '
                      'See docs/M0-SETUP.md.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
