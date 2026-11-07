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
  static const _savedCredentialsKey = 'owner_remembered_credentials';
  static const _secureStorage = FlutterSecureStorage();

  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool registering = false;
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
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (loading || formKey.currentState?.validate() != true) return;
    final isRegistering = registering;
    final shouldRememberPassword = !isRegistering && rememberPassword;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = isRegistering
          ? await repository.registerOwner(
              name: name.text.trim(),
              email: email.text.trim(),
              password: password.text,
            )
          : await repository.signIn(
              email: email.text.trim(),
              password: password.text,
              expectedRole: 'owner',
            );
      try {
        if (shouldRememberPassword) {
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
                    SizedBox(
                      height: 180,
                      child: Image.asset(
                        'assets/bonzar_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Owner desktop workspace',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      registering ? 'Create Owner account' : 'Owner sign in',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    if (registering) ...[
                      TextFormField(
                        key: const Key('owner-register-name'),
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) {
                          final length = value?.trim().length ?? 0;
                          return registering && (length < 2 || length > 120)
                              ? 'Enter a name between 2 and 120 characters'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      key: const Key('owner-email'),
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          value == null ||
                              value.trim().length > 254 ||
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
                      obscureText: !passwordVisible,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          key: const Key('owner-password-visibility'),
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
                      validator: (value) => registering
                          ? (value?.length ?? 0) < 12 ||
                                    (value?.length ?? 0) > 128
                                ? 'Use 12 to 128 characters'
                                : null
                          : (value?.isEmpty ?? true)
                          ? 'Enter your password'
                          : null,
                    ),
                    if (!registering)
                      CheckboxListTile(
                        key: const Key('owner-remember-password'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Remember password'),
                        value: rememberPassword,
                        onChanged: loading
                            ? null
                            : (value) =>
                                  _toggleRememberPassword(value ?? false),
                      ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: loading ? null : _submit,
                      icon: Icon(
                        registering ? Icons.person_add_alt_1 : Icons.login,
                      ),
                      label: Text(
                        loading
                            ? 'Please wait…'
                            : registering
                            ? 'Create owner account'
                            : 'Sign in',
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
                            : 'New Owner? Create an account',
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
                    const SizedBox(height: 12),
                    const Text(
                      'Owner accounts use the same registration process as '
                      'Seller accounts.',
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
