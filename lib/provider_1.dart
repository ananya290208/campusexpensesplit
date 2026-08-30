import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Participant> _participants = [
    Participant(id: '1', name: 'Alex'),
    Participant(id: '2', name: 'Sam'),
    Participant(id: '3', name: 'Jordan'),
  ];
  List<Expense> _expenses = [];
  bool _isDarkMode = false;

  List<Participant> get participants => List.unmodifiable(_participants);
  List<Expense> get expenses => List.unmodifiable(
      _expenses..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  bool get isDarkMode => _isDarkMode;

  ExpenseProvider() {
    _loadFromStorage();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('qk_dark_mode', _isDarkMode);
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final pData = jsonEncode(_participants.map((p) => p.toJson()).toList());
    final eData = jsonEncode(_expenses.map((e) => e.toJson()).toList());
    await prefs.setString('qk_participants', pData);
    await prefs.setString('qk_expenses', eData);
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('qk_dark_mode') ?? false;

    final pData = prefs.getString('qk_participants');
    final eData = prefs.getString('qk_expenses');

    if (pData != null) {
      final List decoded = jsonDecode(pData);
      _participants = decoded.map((e) => Participant.fromJson(e)).toList();
    }
    if (eData != null) {
      final List decoded = jsonDecode(eData);
      _expenses = decoded.map((e) => Expense.fromJson(e)).toList();
    }
    _recalculateBalances();
    notifyListeners();
  }

  void addParticipant(String name) {
    if (name.trim().isEmpty) return;
    _participants.add(Participant(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
    ));
    _recalculateBalances();
    _saveToStorage();
    notifyListeners();
  }

  void deleteExpense(String expenseId) {
    _expenses.removeWhere((e) => e.id == expenseId);
    _recalculateBalances();
    _saveToStorage();
    notifyListeners();
  }

  void restoreExpense(Expense expense, int index) {
    _expenses.insert(index, expense);
    _recalculateBalances();
    _saveToStorage();
    notifyListeners();
  }

  String? addExpense({
    required String title,
    required double totalAmount,
    required Map<String, double> payers,
    required SplitMode splitMode,
    required Map<String, double> allocations,
    required ExpenseCategory category,
  }) {
    if (title.trim().isEmpty) return "Title cannot be empty.";
    if (totalAmount <= 0) return "Amount must be greater than zero.";
    if (allocations.isEmpty) return "Select at least 1 person to split with.";

    final paidTotal = payers.values.fold(0.0, (a, b) => a + b);
    if ((paidTotal - totalAmount).abs() > 0.01) {
      return "Payer amounts (\$${paidTotal.toStringAsFixed(2)}) must sum up to total (\$${totalAmount.toStringAsFixed(2)}).";
    }

    if (splitMode == SplitMode.specific) {
      final allocatedTotal = allocations.values.fold(0.0, (a, b) => a + b);
      if ((allocatedTotal - totalAmount).abs() > 0.01) {
        return "Allocations (\$${allocatedTotal.toStringAsFixed(2)}) must match total (\$${totalAmount.toStringAsFixed(2)}).";
      }
    } else if (splitMode == SplitMode.ratio) {
      final ratioTotal = allocations.values.fold(0.0, (a, b) => a + b);
      if ((ratioTotal - 100.0).abs() > 0.01) {
        return "Percentages (${ratioTotal.toStringAsFixed(1)}%) must total 100%.";
      }
    }

    final newExpense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      totalAmount: totalAmount,
      payers: payers,
      splitMode: splitMode,
      allocations: allocations,
      timestamp: DateTime.now(),
      category: category,
    );

    _expenses.add(newExpense);
    _recalculateBalances();
    _saveToStorage();
    notifyListeners();
    return null;
  }

  void _recalculateBalances() {
    for (var p in _participants) {
      p.netBalance = 0.0;
    }

    for (var expense in _expenses) {
      expense.payers.forEach((userId, amount) {
        final p = _participants.firstWhere((item) => item.id == userId);
        p.netBalance += amount;
      });

      if (expense.splitMode == SplitMode.uniform) {
        final count = expense.allocations.length;
        final baseShare = (expense.totalAmount / count);
        expense.allocations.forEach((userId, _) {
          final p = _participants.firstWhere((item) => item.id == userId);
          p.netBalance -= baseShare;
        });
      } else if (expense.splitMode == SplitMode.specific) {
        expense.allocations.forEach((userId, amount) {
          final p = _participants.firstWhere((item) => item.id == userId);
          p.netBalance -= amount;
        });
      } else if (expense.splitMode == SplitMode.ratio) {
        expense.allocations.forEach((userId, percentage) {
          final p = _participants.firstWhere((item) => item.id == userId);
          p.netBalance -= (expense.totalAmount * (percentage / 100.0));
        });
      }
    }
  }

  List<Settlement> calculateMinimumTransactions() {
    List<double> amountList = _participants.map((p) => p.netBalance).toList();
    List<Settlement> settlements = [];

    void minCashFlowRec(List<double> amount) {
      int mxCredit = 0, mxDebit = 0;
      for (int i = 1; i < amount.length; i++) {
        if (amount[i] > amount[mxCredit]) mxCredit = i;
        if (amount[i] < amount[mxDebit]) mxDebit = i;
      }

      if (amount[mxCredit].abs() < 0.01 && amount[mxDebit].abs() < 0.01) return;

      double minVal = (-amount[mxDebit] < amount[mxCredit])
          ? -amount[mxDebit]
          : amount[mxCredit];

      amount[mxCredit] -= minVal;
      amount[mxDebit] += minVal;

      settlements.add(Settlement(
        fromUser: _participants[mxDebit].name,
        toUser: _participants[mxCredit].name,
        amount: minVal,
      ));

      minCashFlowRec(amount);
    }

    minCashFlowRec(amountList);
    return settlements;
  }

  Map<ExpenseCategory, double> getCategorySpending() {
    Map<ExpenseCategory, double> map = {};
    for (var category in ExpenseCategory.values) {
      map[category] = 0.0;
    }
    for (var e in _expenses) {
      map[e.category] = (map[e.category] ?? 0.0) + e.totalAmount;
    }
    return map;
  }
}