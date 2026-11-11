import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../ui/ember.dart';
import '../../ui/widgets.dart';

/// Sign in or create an account with email and password.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool createAccount}) async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });

    final auth = ref.read(supabaseProvider).auth;
    String? message;
    try {
      if (createAccount) {
        final response = await auth.signUp(email: email, password: password);
        if (response.session == null) {
          message =
              'The account was created, but it is not signed in. '
              'Email confirmation is probably still switched on in Supabase.';
        }
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (error) {
      message = error.message;
    } catch (error) {
      message =
          'Could not reach the server. Check the internet connection and '
          'try again. ($error)';
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Ember.paper,
                borderRadius: BorderRadius.circular(18),
              ),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Orbito', style: Ember.h3.copyWith(color: Ember.ink2)),
                    const SizedBox(height: 14),
                    Text(
                      'Log in',
                      style: Ember.h1Small.copyWith(color: Ember.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your plan is kept on this device and synced.',
                      style: Ember.meta,
                    ),
                    const SizedBox(height: 22),
                    const FieldLabel('Email'),
                    TextField(
                      key: const Key('email'),
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Password'),
                    TextField(
                      key: const Key('password'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: !_showPassword,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(createAccount: false),
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          key: const Key('show-password'),
                          tooltip: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                          iconSize: 18,
                          color: Ember.ink2,
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('sign-in'),
                      onPressed: _busy
                          ? null
                          : () => _submit(createAccount: false),
                      child: const Text('Log in'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('create-account'),
                      onPressed: _busy
                          ? null
                          : () => _submit(createAccount: true),
                      child: const Text('Create an account'),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(minHeight: 3),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _message!,
                        key: const Key('sign-in-message'),
                        style: Ember.meta.copyWith(color: Ember.nowInk),
                      ),
                    ],
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
