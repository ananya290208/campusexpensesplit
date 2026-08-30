import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../provider.dart'; // Corrected import from provider_1.dart to provider.dart

class MainDashboardView extends StatelessWidget {
  const MainDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final minTransactions = provider.calculateMinimumTransactions();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Net Standing Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.participants.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final p = provider.participants[index];
                    final isPositive = p.netBalance >= 0;
                    return Chip(
                      label: Text(
                        // Fixed string interpolation syntax by adding $:
                        '${p.name}: ${isPositive ? "+" : ""}₹${p.netBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isPositive ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: isPositive ? Colors.green[50] : Colors.red[50],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (minTransactions.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.amber[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Optimized Debt Path (Min Transfers):',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                ...minTransactions.map((s) => Text(
                      '• ${s.fromUser} pays ${s.toUser} ₹${s.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                    )),
              ],
            ),
          ),
        ],
        const Divider(height: 1),
        Expanded(
          child: provider.expenses.isEmpty
              ? const Center(child: Text('No expenses logged yet.'))
              : ListView.builder(
                  itemCount: provider.expenses.length,
                  itemBuilder: (context, index) {
                    final expense = provider.expenses[index];
                    return Dismissible(
                      key: Key(expense.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        final deletedItem = expense;
                        final deletedIndex = index;

                        provider.deleteExpense(expense.id);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted "${deletedItem.title}"'),
                            action: SnackBarAction(
                              label: 'UNDO',
                              onPressed: () => provider.restoreExpense(deletedItem, deletedIndex),
                            ),
                          ),
                        );
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(_getCategoryIcon(expense.category)),
                        ),
                        title: Text(expense.title),
                        subtitle: Text(
                            'Paid across ${expense.payers.length} user(s) • ${expense.splitMode.name.toUpperCase()}'),
                        trailing: Text(
                          '₹${expense.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.auto:
        return Icons.directions_car;
      case ExpenseCategory.subscription:
        return Icons.subscriptions;
      case ExpenseCategory.food:
        return Icons.fastfood;
      case ExpenseCategory.printout:
        return Icons.print;
      default:
        return Icons.receipt_long;
    }
  }
}