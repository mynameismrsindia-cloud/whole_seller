import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/providers.dart';
import '../widgets/labeled_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.name,
    required this.store,
    required this.contact,
    required this.location,
    required this.onSave,
    this.onSaveRemote,
  });

  final String name;
  final String store;
  final String contact;
  final String location;
  final void Function(String, String, String, String) onSave;
  final Future<void> Function(String, String, String, String)? onSaveRemote;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.name);
  late final store = TextEditingController(text: widget.store);
  late final contact = TextEditingController(text: widget.contact);
  late final location = TextEditingController(text: widget.location);
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    store.dispose();
    contact.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Name',
              child: TextFormField(
                controller: name,
                validator: _requiredValue,
                textCapitalization: TextCapitalization.words,
              ),
            ),
            LabeledField(
              label: 'Store name',
              child: TextFormField(
                controller: store,
                validator: _requiredValue,
              ),
            ),
            LabeledField(
              label: 'Store contact number',
              child: TextFormField(
                controller: contact,
                validator: _requiredValue,
                keyboardType: TextInputType.phone,
              ),
            ),
            LabeledField(
              label: 'Location',
              child: TextFormField(
                controller: location,
                validator: _requiredValue,
              ),
            ),
            FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save profile'),
            ),
            const SizedBox(height: 18),
            Card(
              color: const Color(0xFFEAF4F2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Any issue? Connect with Pratap Mity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const SelectableText('pratapmity@gmail.com'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('seller-contact-us'),
                      onPressed: _contactSupport,
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Contact Us'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String? _requiredValue(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> _save() async {
    if (formKey.currentState?.validate() != true) return;
    final values = [
      name.text.trim(),
      store.text.trim(),
      contact.text.trim(),
      location.text.trim(),
    ];
    setState(() => saving = true);
    try {
      await widget.onSaveRemote?.call(
        values[0],
        values[1],
        values[2],
        values[3],
      );
      if (!mounted) return;
      widget.onSave(values[0], values[1], values[2], values[3]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.onSaveRemote == null
                ? 'Profile saved for this demo.'
                : 'Profile saved.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _contactSupport() async {
    final messenger = ScaffoldMessenger.of(context);
    final emailUri = Uri(
      scheme: 'mailto',
      path: 'pratapmity@gmail.com',
      queryParameters: {'subject': 'Wholesale Manager support'},
    );
    try {
      final launched = await launchUrl(emailUri);
      if (!launched && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open an email app.')),
        );
      }
    } on PlatformException {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open an email app.')),
        );
      }
    }
  }
}
