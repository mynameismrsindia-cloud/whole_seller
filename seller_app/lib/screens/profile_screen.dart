import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Card(
        margin: const EdgeInsets.all(20),
        child: ListTile(
          contentPadding: const EdgeInsets.all(20),
          leading: CircleAvatar(
            child: Text(
              name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
            ),
          ),
          title: Text(name),
          subtitle: Text(email),
        ),
      ),
    ),
  );
}
