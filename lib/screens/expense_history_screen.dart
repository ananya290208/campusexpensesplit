import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .where('members', arrayContains: uid)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userGroupDocs = groupSnapshot.data?.docs ?? [];
          final Set<String> userGroupIds = userGroupDocs.map((d) => d.id).toSet();
          userGroupIds.add('personal');

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('expenses')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error loading history: ${snapshot.error}'));
              }

              final allDocs = snapshot.data?.docs ?? [];
              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final groupId = (data['groupId'] ?? 'personal').toString();
                final paidBy = (data['paidBy'] ?? '').toString();
                final paidContributions = data['paidContributions'] as Map<String, dynamic>?;
                final shares = data['shares'] as Map<String, dynamic>?;

                final bool isGroupMember = userGroupIds.contains(groupId);
                final bool isPayer = paidBy == uid || (paidContributions != null && paidContributions.containsKey(uid));
                final bool isSplitParticipant = shares != null && shares.containsKey(uid);

                return isGroupMember || isPayer || isSplitParticipant;
              }).toList();

              if (docs.isEmpty) {
                return const Center(
                  child: Text('No expense history found for your groups. Add an expense to get started!'),
                );
              }

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;
              
              final title = data['title'] ?? 'Untitled Expense';
              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final splitType = data['splitType'] ?? 'uniform';

              final category = (data['category'] ?? 'Others').toString();

              IconData icon;
              Color iconColor;
              Color avatarBg;

              if (category.contains('Food')) {
                icon = Icons.restaurant;
                iconColor = Colors.teal;
                avatarBg = Colors.teal.shade50;
              } else if (category.contains('Movie')) {
                icon = Icons.movie;
                iconColor = Colors.purple;
                avatarBg = Colors.purple.shade50;
              } else if (category.contains('Utilities')) {
                icon = Icons.bolt;
                iconColor = Colors.orange.shade800;
                avatarBg = Colors.orange.shade50;
              } else if (category.contains('Travel')) {
                icon = Icons.directions_car;
                iconColor = Colors.blue.shade700;
                avatarBg = Colors.blue.shade50;
              } else if (category.contains('Printouts')) {
                icon = Icons.print;
                iconColor = Colors.pink.shade600;
                avatarBg = Colors.pink.shade50;
              } else if (category.contains('Subscriptions')) {
                icon = Icons.subscriptions;
                iconColor = Colors.indigo.shade600;
                avatarBg = Colors.indigo.shade50;
              } else {
                icon = Icons.receipt_long;
                iconColor = Colors.deepPurple;
                avatarBg = Colors.deepPurple.shade50;
              }

              return Dismissible(
                key: Key(docId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  color: Colors.red,
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                onDismissed: (direction) async {
                  // Temporarily store deleted data for undo functionality
                  final deletedData = Map<String, dynamic>.from(data);

                  // 1. Delete immediately from Firestore (triggers instant balance updates)
                  try {
                    await FirebaseFirestore.instance
                        .collection('expenses')
                        .doc(docId)
                        .delete();

                    // 2. Clean up from local Hive cache if present
                    final cacheBox = Hive.box('expenses_cache');
                    final hiveKey = cacheBox.keys.firstWhere(
                      (k) => cacheBox.get(k)?['title'] == title && cacheBox.get(k)?['amount'] == amount,
                      orElse: () => null,
                    );
                    if (hiveKey != null) {
                      await cacheBox.delete(hiveKey);
                    }
                  } catch (e) {
                    debugPrint('Error deleting expense: $e');
                  }

                  // 3. Show SnackBar with Undo option
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deleted "$title"'),
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () async {
                            // Restore the document back to Firestore
                            try {
                              await FirebaseFirestore.instance
                                  .collection('expenses')
                                  .doc(docId)
                                  .set(deletedData);
                            } catch (e) {
                              debugPrint('Error restoring expense: $e');
                            }
                          },
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: avatarBg,
                      child: Icon(icon, color: iconColor),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: iconColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${splitType.toString().toUpperCase()}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
            },
          );
        },
      ),
    );
  }
}