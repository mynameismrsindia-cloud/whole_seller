import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    required this.onContinue,
    this.onAuthenticated,
    this.initialError,
  });

  final VoidCallback onContinue;
  final FutureOr<void> Function(AppUser)? onAuthenticated;
  final String? initialError;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (loading || formKey.currentState?.validate() != true) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signIn(
            email: email.text.trim(),
            password: password.text,
            expectedRole: 'owner',
          );
      if (mounted) await widget.onAuthenticated?.call(user);
    } catch (exception) {
      if (mounted) setState(() => error = appErrorMessage(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF00665D),
                      size: 46,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Wholesale Manager',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Owner desktop workspace',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('owner-email'),
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          value == null ||
                              !RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(value.trim())
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('owner-password'),
                      controller: password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => (value?.isEmpty ?? true)
                          ? 'Enter your password'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: loading ? null : _signIn,
                      icon: const Icon(Icons.login),
                      label: Text(loading ? 'Signing in…' : 'Sign in'),
                    ),
                    OutlinedButton(
                      onPressed: loading ? null : widget.onContinue,
                      child: const Text('Open demo workspace'),
                    ),
                    if (error ?? widget.initialError case final message?)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Owner accounts are provisioned securely by an administrator.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
