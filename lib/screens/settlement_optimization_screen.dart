import 'package:campusexpensesplit/services/debt_simplification_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/user_badge.dart';

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
    final paymentKey = '$from pays $to';
    setState(() {
      _isLoading = true;
      _processingPaymentFor = paymentKey;
    });

    await Future.delayed(const Duration(seconds: 1));

    try {
      await FirebaseFirestore.instance.collection('expenses').add({
        'title': 'Settlement: $groupName',
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

    final otherUid = from == FirebaseAuth.instance.currentUser?.uid ? to : from;
    final otherDisplayName = await _resolveUserName(otherUid);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Settlement Recorded!'),
          ],
        ),
        content: Text(
          'Successfully settled \$${amount.toStringAsFixed(2)} with $otherDisplayName. Net obligations across all groups have been updated.',
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: currentUserId)
          .snapshots(),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Settlement Optimization')),
            body: const Center(child: CircularProgressIndicator()),
          );
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
                return Scaffold(
                  appBar: AppBar(title: const Text('Settlement Optimization')),
                  body: const Center(child: CircularProgressIndicator()),
                );
              }

              final allExpenses = expenseSnapshot.data?.docs ?? [];

              // 1. Calculate net balances for each user across all joined groups
              final Map<String, double> globalNetBalances = {};
              final Map<String, Set<String>> userInvolvedGroups = {};

              for (var expDoc in allExpenses) {
                final data = expDoc.data() as Map<String, dynamic>;
                final gId = (data['groupId'] ?? 'personal').toString();

                if (!joinedGroupIds.contains(gId)) continue;

                final gName = groupNames[gId] ?? 'Group';
                final totalAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final paidBy = (data['paidBy'] ?? '').toString();
                final paidContributions = data['paidContributions'] as Map<String, dynamic>?;
                final shares = data['shares'] as Map<String, dynamic>?;

                // Credit who paid
                if (paidContributions != null && paidContributions.isNotEmpty) {
                  paidContributions.forEach((uid, val) {
                    final p = (val as num?)?.toDouble() ?? 0.0;
                    globalNetBalances[uid] = (globalNetBalances[uid] ?? 0.0) + p;
                    userInvolvedGroups.putIfAbsent(uid, () => {}).add(gName);
                  });
                } else if (paidBy.isNotEmpty) {
                  globalNetBalances[paidBy] = (globalNetBalances[paidBy] ?? 0.0) + totalAmount;
                  userInvolvedGroups.putIfAbsent(paidBy, () => {}).add(gName);
                }

                // Debit who owes
                if (shares != null && shares.isNotEmpty) {
                  shares.forEach((uid, val) {
                    final s = (val as num?)?.toDouble() ?? 0.0;
                    globalNetBalances[uid] = (globalNetBalances[uid] ?? 0.0) - s;
                    userInvolvedGroups.putIfAbsent(uid, () => {}).add(gName);
                  });
                }
              }

              // 2. Run global shortest-path debt simplification
              final List<Map<String, dynamic>> globalTransactions = 
                  DebtSimplificationService.calculateOptimizedDebts(globalNetBalances);

              // 3. Aggregate transactions involving the current user into per-peer obligations
              final Map<String, double> owedByMeToPeer = {}; // peerUid -> totalAmount I owe them
              final Map<String, double> owedToMeByPeer = {}; // peerUid -> totalAmount they owe me

              for (var tx in globalTransactions) {
                final fromUid = tx['from'] as String;
                final toUid = tx['to'] as String;
                final amount = (tx['amount'] as num).toDouble();

                if (amount < 0.01) continue;

                if (fromUid == currentUserId) {
                  owedByMeToPeer[toUid] = (owedByMeToPeer[toUid] ?? 0.0) + amount;
                } else if (toUid == currentUserId) {
                  owedToMeByPeer[fromUid] = (owedToMeByPeer[fromUid] ?? 0.0) + amount;
                }
              }

              // 4. Net out obligations per user across all groups into a single combined debt
              final Set<String> allPeers = {...owedByMeToPeer.keys, ...owedToMeByPeer.keys};
              final List<Map<String, dynamic>> paymentsToMake = [];
              final List<Map<String, dynamic>> paymentsToReceive = [];

              for (var peerUid in allPeers) {
                final iOwe = owedByMeToPeer[peerUid] ?? 0.0;
                final theyOwe = owedToMeByPeer[peerUid] ?? 0.0;
                final netObligation = theyOwe - iOwe;

                // Shared groups between current user and this peer
                final Set<String> sharedGroups = (userInvolvedGroups[peerUid] ?? {})
                    .intersection(userInvolvedGroups[currentUserId] ?? {});

                final String groupsSummary = sharedGroups.isEmpty
                    ? (userInvolvedGroups[peerUid]?.join(', ') ?? 'Shared Expenses')
                    : (sharedGroups.length == 1 
                        ? 'Group: ${sharedGroups.first}' 
                        : 'Across: ${sharedGroups.join(', ')}');

                if (netObligation < -0.01) {
                  // Current user owes peer
                  paymentsToMake.add({
                    'from': currentUserId,
                    'to': peerUid,
                    'amount': -netObligation,
                    'groupId': 'personal',
                    'groupName': groupsSummary,
                  });
                } else if (netObligation > 0.01) {
                  // Peer owes current user
                  paymentsToReceive.add({
                    'from': peerUid,
                    'to': currentUserId,
                    'amount': netObligation,
                    'groupId': 'personal',
                    'groupName': groupsSummary,
                  });
                }
              }

              final double totalDueToPay = paymentsToMake.fold(0.0, (acc, item) => acc + (item['amount'] as double));
              final double totalDueToReceive = paymentsToReceive.fold(0.0, (acc, item) => acc + (item['amount'] as double));

              if (paymentsToMake.isEmpty && paymentsToReceive.isEmpty) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Settlement Optimization')),
                  body: Center(
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
                  ),
                );
              }

              final isDark = Theme.of(context).brightness == Brightness.dark;

              return DefaultTabController(
                length: 2,
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('Settlement Optimization'),
                    actions: const [UserBadge()],
                    bottom: TabBar(
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.arrow_upward, color: Colors.redAccent),
                          text: 'What I Owe (${paymentsToMake.length})',
                        ),
                        Tab(
                          icon: const Icon(Icons.arrow_downward, color: Colors.greenAccent),
                          text: 'Owed to Me (${paymentsToReceive.length})',
                        ),
                      ],
                    ),
                  ),
                  body: TabBarView(
                    children: [
                      // TAB 1: What I Owe (Payments YOU need to make)
                      ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          Card(
                            color: totalDueToPay > 0 
                                ? (isDark ? Colors.red.shade900.withValues(alpha: 0.25) : Colors.red.shade50)
                                : (isDark ? Colors.green.shade900.withValues(alpha: 0.25) : Colors.green.shade50),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: totalDueToPay > 0 
                                    ? (isDark ? Colors.red.shade700 : Colors.red.shade200) 
                                    : (isDark ? Colors.green.shade700 : Colors.green.shade200),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Icon(
                                    totalDueToPay > 0 ? Icons.payment : Icons.check_circle,
                                    color: totalDueToPay > 0 
                                        ? (isDark ? Colors.redAccent.shade100 : Colors.red.shade800) 
                                        : (isDark ? Colors.greenAccent.shade100 : Colors.green.shade800),
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
                                              : 'You Don\'t Owe Anything!',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: totalDueToPay > 0 
                                                ? (isDark ? Colors.redAccent.shade100 : Colors.red.shade900) 
                                                : (isDark ? Colors.greenAccent.shade100 : Colors.green.shade900),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '\$${totalDueToPay.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: totalDueToPay > 0 
                                                ? (isDark ? Colors.redAccent : Colors.red.shade800) 
                                                : (isDark ? Colors.greenAccent : Colors.green.shade800),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Payments You Need to Make',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap "Settle Up" to send money or record payment:',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          if (paymentsToMake.isEmpty)
                            Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Colors.green.shade400, size: 54),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'You are all settled up!',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'You do not owe any money to anyone in your joined groups.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
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
                              final paymentKey = '$currentUserId pays $toUid';
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
                        ],
                      ),

                      // TAB 2: What Others Owe Me (To Receive)
                      ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          Card(
                            color: isDark ? Colors.green.shade900.withValues(alpha: 0.25) : Colors.green.shade50,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isDark ? Colors.green.shade700 : Colors.green.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.savings, color: isDark ? Colors.greenAccent.shade100 : Colors.green.shade800, size: 32),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Total Owed to You',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.greenAccent.shade100 : Colors.green.shade900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '\$${totalDueToReceive.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.greenAccent : Colors.green.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
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
                          if (paymentsToReceive.isEmpty)
                            Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'No one currently owes you money.',
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                                ),
                              ),
                            )
                          else
                            ...paymentsToReceive.map((tx) {
                              final fromUid = tx['from'] as String;
                              final amount = tx['amount'] as double;
                              final groupId = tx['groupId'] as String;
                              final groupName = tx['groupName'] as String;
                              final paymentKey = '$fromUid pays $currentUserId';
                              final isProcessing = _isLoading && _processingPaymentFor == paymentKey;

                              return FutureBuilder<String>(
                                future: _resolveUserName(fromUid),
                                builder: (context, nameSnapshot) {
                                  final debtorName = nameSnapshot.data ?? fromUid;

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
                                            backgroundColor: Colors.green.shade100,
                                            child: const Icon(Icons.arrow_downward, color: Colors.green),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$debtorName owes you',
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
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          OutlinedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : () => _simulateDummySettlement(
                                                      from: fromUid,
                                                      to: currentUserId,
                                                      amount: amount,
                                                      groupId: groupId,
                                                      groupName: groupName,
                                                    ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.teal.shade800,
                                              side: BorderSide(color: Colors.teal.shade300),
                                            ),
                                            child: Text(isProcessing ? 'Recording...' : 'Mark Received'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
  }
}