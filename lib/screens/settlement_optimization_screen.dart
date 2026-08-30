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

    return 'User (${uid.length > 5 ? uid.substring(0, 5) : uid}...)';
  }

  // Simulate settlement payment & record settlement in Firestore
  Future<void> _simulateDummySettlement({
    required String from,
    required String to,
    required double amount,
    required String groupId,
    required String groupName,
  }) async {
    final paymentKey = '$from pays $to in $groupId';
    setState(() {
      _isLoading = true;
      _processingPaymentFor = paymentKey;
    });

    await Future.delayed(const Duration(seconds: 2));

    try {
      await FirebaseFirestore.instance.collection('expenses').add({
        'title': 'Settlement Payment',
        'amount': amount,
        'category': 'General / Others',
        'paidBy': from,
        'shares': {to: amount},
        'groupId': groupId,
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

    final toDisplayName = await _resolveUserName(to);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Payment Sent!'),
          ],
        ),
        content: Text(
          'Successfully transferred \$${amount.toStringAsFixed(2)} to $toDisplayName for "$groupName". Balances have been updated.',
        ),
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

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settlement Optimization')),
        body: const Center(child: Text('Please log in to view settlements.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement Optimization'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .where('members', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupDocs = groupSnapshot.data?.docs ?? [];
          final Map<String, String> groupNames = {};
          final Set<String> joinedGroupIds = {};

          for (var g in groupDocs) {
            final data = g.data() as Map<String, dynamic>;
            joinedGroupIds.add(g.id);
            groupNames[g.id] = (data['name'] ?? 'Group').toString();
          }

          // Also include personal category
          joinedGroupIds.add('personal');
          groupNames['personal'] = 'Personal / Direct';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
            builder: (context, expenseSnapshot) {
              if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allExpenses = expenseSnapshot.data?.docs ?? [];

              // Group expenses by their groupId
              final Map<String, List<Map<String, dynamic>>> expensesByGroup = {};
              for (var expDoc in allExpenses) {
                final data = expDoc.data() as Map<String, dynamic>;
                final gId = (data['groupId'] ?? 'personal').toString();

                if (joinedGroupIds.contains(gId)) {
                  expensesByGroup.putIfAbsent(gId, () => []).add(data);
                }
              }

              // Calculate optimized transactions per group
              List<Map<String, dynamic>> paymentsToMake = [];
              List<Map<String, dynamic>> paymentsToReceive = [];

              expensesByGroup.forEach((gId, gExpenses) {
                final gName = groupNames[gId] ?? 'Group';
                final Map<String, double> netBalances = {};

                for (var data in gExpenses) {
                  final totalAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  final paidBy = (data['paidBy'] ?? '').toString();
                  final paidContributions = data['paidContributions'] as Map<String, dynamic>?;
                  final shares = data['shares'] as Map<String, dynamic>?;

                  // 1. Credit who paid
                  if (paidContributions != null && paidContributions.isNotEmpty) {
                    paidContributions.forEach((uid, val) {
                      final p = (val as num?)?.toDouble() ?? 0.0;
                      netBalances[uid] = (netBalances[uid] ?? 0.0) + p;
                    });
                  } else if (paidBy.isNotEmpty) {
                    netBalances[paidBy] = (netBalances[paidBy] ?? 0.0) + totalAmount;
                  }

                  // 2. Debit who owes based on shares
                  if (shares != null && shares.isNotEmpty) {
                    shares.forEach((uid, val) {
                      final s = (val as num?)?.toDouble() ?? 0.0;
                      netBalances[uid] = (netBalances[uid] ?? 0.0) - s;
                    });
                  }
                }

                // Run debt simplification for this group
                final simplified = DebtSimplificationService.calculateOptimizedDebts(netBalances);

                for (var tx in simplified) {
                  final fromUid = tx['from'] as String;
                  final toUid = tx['to'] as String;
                  final amount = (tx['amount'] as num).toDouble();

                  if (amount < 0.01) continue;

                  if (fromUid == currentUserId) {
                    paymentsToMake.add({
                      'from': fromUid,
                      'to': toUid,
                      'amount': amount,
                      'groupId': gId,
                      'groupName': gName,
                    });
                  } else if (toUid == currentUserId) {
                    paymentsToReceive.add({
                      'from': fromUid,
                      'to': toUid,
                      'amount': amount,
                      'groupId': gId,
                      'groupName': gName,
                    });
                  }
                }
              });

              final double totalDueToPay = paymentsToMake.fold(0.0, (acc, item) => acc + (item['amount'] as double));
              final double totalDueToReceive = paymentsToReceive.fold(0.0, (acc, item) => acc + (item['amount'] as double));

              if (paymentsToMake.isEmpty && paymentsToReceive.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'You are all settled up!',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No pending payments or debts for your joined groups.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Overview Summary Card
                  Card(
                    color: totalDueToPay > 0 ? Colors.red.shade50 : Colors.green.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: totalDueToPay > 0 ? Colors.red.shade200 : Colors.green.shade200,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            totalDueToPay > 0 ? Icons.payment : Icons.done_all,
                            color: totalDueToPay > 0 ? Colors.red.shade800 : Colors.green.shade800,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  totalDueToPay > 0
                                      ? 'Total You Need to Pay'
                                      : 'No Payments Due from You',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: totalDueToPay > 0 ? Colors.red.shade900 : Colors.green.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '\$${totalDueToPay.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: totalDueToPay > 0 ? Colors.red.shade800 : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (totalDueToReceive > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('To Receive', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  '\$${totalDueToReceive.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Payments YOU need to make
                  const Text(
                    'Payments You Need to Make',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap "Settle Up" to record your payment:',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  if (paymentsToMake.isEmpty)
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.check, color: Colors.green),
                            SizedBox(width: 10),
                            Text('You have no payments to make! 🎉', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...paymentsToMake.map((tx) {
                      final toUid = tx['to'] as String;
                      final amount = tx['amount'] as double;
                      final groupId = tx['groupId'] as String;
                      final groupName = tx['groupName'] as String;
                      final paymentKey = '$currentUserId pays $toUid in $groupId';
                      final isProcessing = _isLoading && _processingPaymentFor == paymentKey;

                      return FutureBuilder<String>(
                        future: _resolveUserName(toUid),
                        builder: (context, nameSnapshot) {
                          final recipientName = nameSnapshot.data ?? toUid;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.red.shade100,
                                    child: const Icon(Icons.arrow_upward, color: Colors.red),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pay $recipientName',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Group: $groupName',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '\$${amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _simulateDummySettlement(
                                              from: currentUserId,
                                              to: toUid,
                                              amount: amount,
                                              groupId: groupId,
                                              groupName: groupName,
                                            ),
                                    icon: isProcessing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
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

                  const SizedBox(height: 24),

                  // Section 2: Payments You Will Receive
                  if (paymentsToReceive.isNotEmpty) ...[
                    const Text(
                      'Payments You Are Expecting',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Members who owe you money in your joined groups:',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ...paymentsToReceive.map((tx) {
                      final fromUid = tx['from'] as String;
                      final amount = tx['amount'] as double;
                      final groupName = tx['groupName'] as String;

                      return FutureBuilder<String>(
                        future: _resolveUserName(fromUid),
                        builder: (context, nameSnapshot) {
                          final debtorName = nameSnapshot.data ?? fromUid;

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: const Icon(Icons.arrow_downward, color: Colors.green),
                              ),
                              title: Text(
                                '$debtorName owes you',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text('Group: $groupName', style: const TextStyle(fontSize: 12)),
                              trailing: Text(
                                '\$${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}