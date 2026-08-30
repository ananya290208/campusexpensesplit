import 'package:campusexpensesplit/services/debt_simplification_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettlementOptimizationScreen extends StatefulWidget {
  const SettlementOptimizationScreen({super.key});

  @override
  State<SettlementOptimizationScreen> createState() => _SettlementOptimizationScreenState();
}

class _SettlementOptimizationScreenState extends State<SettlementOptimizationScreen> {
  bool _isLoading = false;
  String? _processingPaymentFor;

  // Cache resolved names to prevent redundant Firestore reads
  final Map<String, String> _nameCache = {};

  // Helper widget or function to safely resolve UIDs to actual names in real-time
  Future<String> _resolveUserName(String uid) async {
    // If it's already a clean human name (e.g. 'Alice'), return it
    if (uid.length < 20 || uid.contains(' ')) {
      return uid;
    }

    if (_nameCache.containsKey(uid)) {
      return _nameCache[uid]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final name = data['name'] ?? data['fullName'] ?? data['displayName'] ?? 'User (${uid.substring(0, 5)})';
        _nameCache[uid] = name;
        return name;
      }
    } catch (e) {
      debugPrint('Error fetching user name for $uid: $e');
    }

    // Fallback if user doc doesn't exist
    return 'User (${uid.substring(0, 5)}...)';
  }

  // Simulate dummy payment gateway call & net off balance in Firestore
  Future<void> _simulateDummySettlement(String from, String to, double amount) async {
    setState(() {
      _isLoading = true;
      _processingPaymentFor = '$from pays $to';
    });

    await Future.delayed(const Duration(seconds: 2));

    try {
      await FirebaseFirestore.instance.collection('expenses').add({
        'title': 'Settlement Payment',
        'amount': amount,
        'paidBy': from,
        'shares': {to: amount},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error recording settlement: $e');
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _processingPaymentFor = null;
    });

    // Resolve readable names for the dialog message
    final fromDisplayName = await _resolveUserName(from);
    final toDisplayName = await _resolveUserName(to);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Settlement Successful'),
          ],
        ),
        content: Text('Successfully transferred \$${amount.toStringAsFixed(2)} from $fromDisplayName to $toDisplayName. Balances have been updated.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement Optimization'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No expenses found to calculate settlements.'),
            );
          }

          Map<String, double> netBalances = {};

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final totalAmount = (data['amount'] as num?)?.toDouble() 
                ?? (data['total'] as num?)?.toDouble() 
                ?? 0.0;

            // 1. Credit who paid (checking common field variations)
            final paidContributions = data['paidContributions'] as Map<String, dynamic>?;
            if (paidContributions != null && paidContributions.isNotEmpty) {
              paidContributions.forEach((uid, val) {
                double paidVal = (val as num?)?.toDouble() ?? 0.0;
                netBalances[uid] = (netBalances[uid] ?? 0.0) + paidVal;
              });
            } else {
              final paidBy = data['paidBy'] ?? data['paid_by'] ?? data['payer'] ?? 'User';
              netBalances[paidBy] = (netBalances[paidBy] ?? 0.0) + totalAmount;
            }

            // 2. Debit who owes based on shares breakdown
            final shares = data['shares'] as Map<String, dynamic>? 
                ?? data['split'] as Map<String, dynamic>?;
            
            if (shares != null && shares.isNotEmpty) {
              shares.forEach((uid, shareVal) {
                double share = (shareVal as num?)?.toDouble() ?? 0.0;
                netBalances[uid] = (netBalances[uid] ?? 0.0) - share;
              });
            } else {
              final paidBy = data['paidBy'] ?? data['paid_by'] ?? data['payer'] ?? 'User';
              netBalances[paidBy] = (netBalances[paidBy] ?? 0.0) - totalAmount;
            }
          }

          final optimizedTransactions = DebtSimplificationService.calculateOptimizedDebts(netBalances);

          // Filter transactions to only show those involving the logged-in user
          final userTransactions = optimizedTransactions.where((tx) {
            final fromUid = tx['from'] as String;
            final toUid = tx['to'] as String;
            return fromUid == currentUserId || toUid == currentUserId;
          }).toList();

          if (userTransactions.isEmpty) {
            return const Center(
              child: Text('You have no pending debts or obligations! 🎉'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const Text(
                'Your Personal Repayment Path',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Transactions involving your account:',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...userTransactions.map((tx) {
                final fromUid = tx['from'] as String;
                final toUid = tx['to'] as String;
                final amount = tx['amount'] as double;
                final isProcessing = _isLoading && _processingPaymentFor == '$fromUid pays $toUid';

                return FutureBuilder<List<String>>(
                  future: Future.wait([_resolveUserName(fromUid), _resolveUserName(toUid)]),
                  builder: (context, nameSnapshot) {
                    final fromName = nameSnapshot.data?[0] ?? fromUid;
                    final toName = nameSnapshot.data?[1] ?? toUid;
                    final titleText = '$fromName pays $toName';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Amount: \$${amount.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _isLoading 
                                  ? null 
                                  : () => _simulateDummySettlement(fromUid, toUid, amount),
                              icon: isProcessing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.payment, size: 16),
                              label: Text(isProcessing ? 'Processing...' : 'Settle Up'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}