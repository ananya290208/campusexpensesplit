import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../provider.dart';

class UserBadge extends StatelessWidget {
  final bool showThemeToggle;
  const UserBadge({super.key, this.showThemeToggle = true});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final provider = Provider.of<ExpenseProvider>(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showThemeToggle)
          IconButton(
            icon: Icon(
              provider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
            ),
            tooltip: provider.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => provider.toggleTheme(),
          ),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            String name = user.displayName ?? '';
            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null && (data['name'] ?? '').toString().trim().isNotEmpty) {
                name = data['name'].toString().trim();
              }
            }
            if (name.isEmpty) {
              name = user.email?.split('@').first ?? 'User';
            }

            final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                avatar: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                label: Text(
                  name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              ),
            );
          },
        ),
      ],
    );
  }
}
