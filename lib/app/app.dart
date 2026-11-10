import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/sync_test/sign_in_screen.dart';
import '../features/sync_test/sync_test_screen.dart';
import 'providers.dart';

ThemeData _theme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
  useMaterial3: true,
);

/// The app once the keys are in place: sign-in screen or the test screen.
class OrbitoApp extends ConsumerWidget {
  const OrbitoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return MaterialApp(
      title: 'Orbito',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: user.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) =>
            Scaffold(body: Center(child: Text('Sign-in problem: $error'))),
        data: (signedIn) => signedIn == null
            ? const SignInScreen()
            : SyncTestScreen(key: ValueKey(signedIn.id), user: signedIn),
      ),
    );
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
      theme: _theme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orbito is not set up yet',
                    style: Theme.of(context).textTheme.headlineSmall,
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
    );
  }
}
