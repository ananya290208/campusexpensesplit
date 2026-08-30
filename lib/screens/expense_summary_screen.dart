import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ExpenseSummaryScreen extends StatelessWidget {
  const ExpenseSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Expense Summary'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'My Summary'),
              Tab(icon: Icon(Icons.group), text: 'Group Summaries'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPersonalSummary(user?.uid),
            _buildGroupSummaries(user?.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalSummary(String? uid) {
    if (uid == null) return const Center(child: Text('User not logged in.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        
        double totalSpentByMe = 0;
        double totalIOwe = 0;
        double totalOwedToMe = 0;

        List<Map<String, dynamic>> myPaidExpenses = [];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num).toDouble();
          final paidBy = (data['paidBy'] ?? '').toString();
          final Map<String, dynamic>? shares = data['shares'] as Map<String, dynamic>?;

          // Track personal spending paid directly by user
          if (paidBy == uid) {
            totalSpentByMe += amount;
            myPaidExpenses.add(data);
          }

          // Calculate owed balances based on recorded split shares
          if (shares != null) {
            double myShare = (shares[uid] as num?)?.toDouble() ?? 0.0;

            if (paidBy == uid) {
              // I paid for this expense, others owe me their portion
              shares.forEach((memberId, shareAmount) {
                if (memberId != uid) {
                  totalOwedToMe += (shareAmount as num).toDouble();
                }
              });
            } else if (shares.containsKey(uid)) {
              // Someone else paid, I owe my calculated share
              totalIOwe += myShare;
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Total Personal Expenditure Card
              Card(
                color: Colors.deepPurple.shade50,
                child: ListTile(
                  title: const Text('Total Personal Expenditure'),
                  subtitle: Text('\$${totalSpentByMe.toStringAsFixed(2)}', 
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  leading: const Icon(Icons.account_balance, color: Colors.deepPurple, size: 36),
                ),
              ),
              const SizedBox(height: 8),

              // 2. Net Balances Overview Row
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('You Owe', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('\$${totalIOwe.toStringAsFixed(2)}', 
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Owed to You', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('\$${totalOwedToMe.toStringAsFixed(2)}', 
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Text('My Payments History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),

              // 3. Paid Expenses List
              Expanded(
                child: myPaidExpenses.isEmpty
                    ? const Center(child: Text('No expenses recorded yet.'))
                    : ListView.builder(
                        itemCount: myPaidExpenses.length,
                        itemBuilder: (context, index) {
                          final item = myPaidExpenses[index];
                          final Timestamp? timestamp = item['createdAt'] as Timestamp?;
                          final dateStr = timestamp != null 
                              ? DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate())
                              : 'Recent';

                          return ListTile(
                            title: Text(item['title'] ?? 'Expense'),
                            subtitle: Text(dateStr),
                            trailing: Text('\$${(item['amount'] as num).toStringAsFixed(2)}', 
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupSummaries(String? uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: uid)
          .snapshots(),
      builder: (context, groupSnapshot) {
        if (!groupSnapshot.hasData) return const Center(child: CircularProgressIndicator());

        final groups = groupSnapshot.data!.docs;
        if (groups.isEmpty) return const Center(child: Text('You are not part of any active groups.'));

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final groupData = group.data() as Map<String, dynamic>;
            final List membersList = groupData['members'] ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('expenses')
                  .where('groupId', isEqualTo: group.id)
                  .snapshots(),
              builder: (context, expenseSnapshot) {
                double totalGroupSpend = 0;
                Map<String, double> memberPaid = {};
                Map<String, double> memberOwedShare = {};

                if (expenseSnapshot.hasData) {
                  for (var doc in expenseSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final amount = (data['amount'] as num).toDouble();
                    final paidBy = (data['paidBy'] ?? '').toString();

                    totalGroupSpend += amount;
                    memberPaid[paidBy] = (memberPaid[paidBy] ?? 0) + amount;

                    final Map<String, dynamic>? shares = data['shares'] as Map<String, dynamic>?;
                    if (shares != null) {
                      shares.forEach((memberId, shareAmount) {
                        final amt = (shareAmount as num).toDouble();
                        memberOwedShare[memberId] = (memberOwedShare[memberId] ?? 0) + amt;
                      });
                    } else if (membersList.isNotEmpty) {
                      double equalShare = amount / membersList.length;
                      for (var mId in membersList) {
                        memberOwedShare[mId] = (memberOwedShare[mId] ?? 0) + equalShare;
                      }
                    }
                  }
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                    title: Text(groupData['name'] ?? 'Group', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Code: ${groupData['code']} • Members: ${membersList.length}'),
                    trailing: Text('\$${totalGroupSpend.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Member Balances & Contributions:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                        ),
                      ),
                      ...membersList.map((memberUid) {
                        final paid = memberPaid[memberUid] ?? 0.0;
                        final owedShare = memberOwedShare[memberUid] ?? 0.0;
                        final netBalance = paid - owedShare;
                        final isCurrentUser = memberUid == uid;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(memberUid).get(),
                          builder: (context, userSnapshot) {
                            String displayName = isCurrentUser ? 'You' : 'Member';
                            if (userSnapshot.hasData && userSnapshot.data!.exists) {
                              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                              displayName = isCurrentUser 
                                  ? 'You (${userData?['name'] ?? 'User'})' 
                                  : (userData?['name'] ?? 'User');
                            }

                            String statusText;
                            Color statusColor;

                            if (netBalance > 0.01) {
                              statusText = 'Gets back \$${netBalance.toStringAsFixed(2)}';
                              statusColor = Colors.green.shade700;
                            } else if (netBalance < -0.01) {
                              statusText = 'Owes \$${netBalance.abs().toStringAsFixed(2)}';
                              statusColor = Colors.red.shade700;
                            } else {
                              statusText = 'Settled up';
                              statusColor = Colors.grey;
                            }

                            return ListTile(
                              dense: true,
                              leading: Icon(
                                isCurrentUser ? Icons.person : Icons.person_outline,
                                color: isCurrentUser ? Colors.deepPurple : Colors.grey,
                              ),
                              title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Paid: \$${paid.toStringAsFixed(2)} | Share: \$${owedShare.toStringAsFixed(2)}'),
                              trailing: Text(
                                statusText,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            );
                          },
                        );
                      }),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Recent Expenses:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (expenseSnapshot.hasData)
                        ...expenseSnapshot.data!.docs.map((e) {
                          final data = e.data() as Map<String, dynamic>;
                          final Timestamp? timestamp = data['createdAt'] as Timestamp?;
                          final dateStr = timestamp != null 
                              ? DateFormat('MMM dd, yyyy').format(timestamp.toDate()) 
                              : '';
                          return ListTile(
                            dense: true,
                            title: Text(data['title'] ?? 'Expense'),
                            subtitle: Text(dateStr),
                            trailing: Text('\$${(data['amount'] as num).toStringAsFixed(2)}'),
                          );
                        })
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}