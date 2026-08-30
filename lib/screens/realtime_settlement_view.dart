import 'package:campusexpensesplit/services/debt_simplification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RealtimeSettlementView extends StatelessWidget {
  final String groupId;

  const RealtimeSettlementView({Key? key, required this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('groups').doc(groupId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Group data not found.'));
        }

        var groupData = snapshot.data!.data() as Map<String, dynamic>;
        
        // Expects a map structure like: { 'userId1': -45.0, 'userId2': 20.0, 'userId3': 25.0 }
        var rawBalances = groupData['netBalances'] as Map<String, dynamic>? ?? {};
        
        Map<String, double> netBalances = rawBalances.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );

        final optimizedTransactions = DebtSimplificationService.calculateOptimizedDebts(netBalances);

        if (optimizedTransactions.isEmpty) {
          return const Center(child: Text('All settled up! 🎉'));
        }

        return ListView.builder(
          itemCount: optimizedTransactions.length,
          itemBuilder: (context, index) {
            final tx = optimizedTransactions[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.arrow_forward),
                ),
                title: Text('${tx['from']} pays ${tx['to']}'),
                trailing: Text(
                  '\$${(tx['amount'] as double).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}