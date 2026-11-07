import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_user.dart';
import '../services/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.onAuthenticated, this.initialError});

  final FutureOr<void> Function(AppUser)? onAuthenticated;
  final String? initialError;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _savedCredentialsKey = 'seller_remembered_credentials';
  static const _secureStorage = FlutterSecureStorage();

  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool registering = false;
  bool loading = false;
  bool passwordVisible = false;
  bool rememberPassword = false;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreCredentials());
  }

  Future<void> _restoreCredentials() async {
    try {
      final saved = await _secureStorage.read(key: _savedCredentialsKey);
      if (saved == null) return;
      final decoded = jsonDecode(saved);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Saved credentials are invalid.');
      }
      final savedEmail = decoded['email'];
      final savedPassword = decoded['password'];
      if (savedEmail is! String || savedPassword is! String) {
        throw const FormatException('Saved credentials are invalid.');
      }
      if (!mounted || email.text.isNotEmpty || password.text.isNotEmpty) {
        return;
      }
      email.text = savedEmail;
      password.text = savedPassword;
      setState(() => rememberPassword = true);
    } catch (exception) {
      if (mounted) setState(() => error = appErrorMessage(exception));
    }
  }

  Future<void> _toggleRememberPassword(bool value) async {
    setState(() => rememberPassword = value);
    if (value) return;
    try {
      await _secureStorage.delete(key: _savedCredentialsKey);
    } catch (exception) {
      if (mounted) setState(() => error = appErrorMessage(exception));
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (loading || formKey.currentState?.validate() != true) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = registering
          ? await repository.register(
              name: name.text.trim(),
              email: email.text.trim(),
              password: password.text,
            )
          : await repository.login(
              email: email.text.trim(),
              password: password.text,
              expectedRole: 'seller',
            );
      if (!registering) {
        try {
          if (rememberPassword) {
            await _secureStorage.write(
              key: _savedCredentialsKey,
              value: jsonEncode({
                'email': email.text.trim(),
                'password': password.text,
              }),
            );
          } else {
            await _secureStorage.delete(key: _savedCredentialsKey);
          }
        } catch (exception) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Signed in, but remembered credentials could not be saved: '
                  '${appErrorMessage(exception)}',
                ),
              ),
            );
          }
        }
      }
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
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 180,
                      child: Image.asset(
                        'assets/bonzar_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      registering ? 'Create Seller account' : 'Seller sign in',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    if (registering) ...[
                      TextFormField(
                        key: const Key('seller-register-name'),
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value?.trim().length ?? 0) < 2
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      key: const Key('seller-email'),
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
                      key: const Key('seller-password'),
                      controller: password,
                      obscureText: !passwordVisible,
                      autofillHints: registering
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          key: const Key('seller-password-visibility'),
                          tooltip: passwordVisible
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () => setState(
                            () => passwordVisible = !passwordVisible,
                          ),
                          icon: Icon(
                            passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          (value?.length ?? 0) < (registering ? 12 : 1)
                          ? registering
                                ? 'Use at least 12 characters'
                                : 'Enter your password'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    if (!registering)
                      CheckboxListTile(
                        key: const Key('seller-remember-password'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Remember password'),
                        value: rememberPassword,
                        onChanged: loading
                            ? null
                            : (value) =>
                                  _toggleRememberPassword(value ?? false),
                      ),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: loading ? null : _submit,
                        child: Text(
                          loading
                              ? 'Please wait…'
                              : registering
                              ? 'Create account'
                              : 'Sign in',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => setState(() {
                              registering = !registering;
                              error = null;
                            }),
                      child: Text(
                        registering
                            ? 'Already registered? Sign in'
                            : 'New Seller? Create an account',
                      ),
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
                    const SizedBox(height: 8),
                    const Text(
                      'Account access is managed by the Wholesale API.',
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
