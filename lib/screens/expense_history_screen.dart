  import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hive_flutter/hive_flutter.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No expense history found. Add an expense to get started!'),
            );
          }

          final docs = snapshot.data!.docs;

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
                      backgroundColor: Colors.deepPurple.shade100,
                      child: const Icon(Icons.receipt_long, color: Colors.deepPurple),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Split Type: ${splitType.toString().toUpperCase()}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
      ),
    );
  }
}