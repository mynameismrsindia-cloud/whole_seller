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
  });

  final VoidCallback onContinue;
  final FutureOr<void> Function(AppUser)? onAuthenticated;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool loading = false;
  String? error;

  Future<void> _signIn() async {
    if (!firebaseConfigured) {
      widget.onContinue();
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signIn(expectedRole: 'owner');
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
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Owner desktop workspace',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: loading ? null : _signIn,
                    icon: const Icon(Icons.login),
                    label: Text(
                      loading
                          ? 'Signing in…'
                          : firebaseConfigured
                          ? 'Continue with Google'
                          : 'Open demo workspace',
                    ),
                  ),
                  if (loading) ...[
                    const SizedBox(height: 12),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    firebaseConfigured
                        ? 'Secure owner sign-in with Google and Firebase.'
                        : 'Demo mode. Firebase is not initialized.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
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
