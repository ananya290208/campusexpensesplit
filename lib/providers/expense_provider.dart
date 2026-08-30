import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/participant.dart';

class ExpenseProvider extends ChangeNotifier {
  final List<Participant> _participants = [];
  final List<Expense> _expenses = [];

  List<Participant> get participants => List.unmodifiable(_participants);
  List<Expense> get expenses => List.unmodifiable(_expenses..sort((a, b) => b.timestamp.compareTo(a.timestamp)));

  void addParticipant(String name) {
    if (name.trim().isEmpty) return;
    _participants.add(Participant(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
    ));
    notifyListeners();
  }

  // Phase 1 Equal Split Logic
  String? addExpense({
    required String title,
    required double amount,
    required String paidById,
    required List<String> splitWithIds,
    required ExpenseCategory category,
  }) {
    // Input Sanitization
    if (title.trim().isEmpty) return "Title cannot be empty.";
    if (amount <= 0) return "Amount must be greater than zero.";
    if (splitWithIds.isEmpty) return "Select at least one participant to split with.";

    final newExpense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      totalAmount: amount,
      paidById: paidById,
      splitWithUserIds: splitWithIds,
      timestamp: DateTime.now(),
      category: category,
    );

    _expenses.add(newExpense);
    _recalculateBalances();
    notifyListeners();
    return null; // Success
  }

  void _recalculateBalances() {
    // Reset balances
    for (var p in _participants) {
      p.netBalance = 0.0;
    }

    // Apply proportional math
    for (var expense in _expenses) {
      final splitShare = expense.amountPerPerson;
      
      for (var userId in expense.splitWithUserIds) {
        final participant = _participants.firstWhere((p) => p.id == userId);
        if (userId == expense.paidById) {
          participant.netBalance += (expense.totalAmount - splitShare);
        } else {
          participant.netBalance -= splitShare;
        }
      }
    }
  }
}