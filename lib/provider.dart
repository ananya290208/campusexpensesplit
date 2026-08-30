import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseProvider extends ChangeNotifier {
  late Box _participantsBox;
  late Box _expensesBox;
  late Box _settingsBox;
  String? _currentUserId;
  String? get currentUserId => _currentUserId;
  String? _groupId;
  String? get groupId => _groupId;
  
  List<Participant> _participants = [];
  List<Expense> _expenses = [];
  bool _isDarkMode = false;
  bool _isInitialized = false;

  List<Participant> get participants => List.unmodifiable(_participants);
  
  // FIX 1: Sort a copy instead of mutating _expenses directly inside getter
  List<Expense> get expenses {
    final listCopy = List<Expense>.from(_expenses);
    listCopy.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(listCopy);
  }

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  ExpenseProvider() {
    _initHive();
  }

  Future<void> _initHive() async {
  try {
    await Hive.initFlutter();
    
    _participantsBox = await Hive.openBox('participants_box');
    _expensesBox = await Hive.openBox('expenses_box');
    _settingsBox = await Hive.openBox('settings_box');

    _isDarkMode = _settingsBox.get('isDarkMode', defaultValue: false);

    // Silent Anonymous Firebase Authentication
    UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
    _currentUserId = userCredential.user?.uid;

    _loadData();
  } catch (e) {
    debugPrint("Initialization error: $e");
  } finally {
    _isInitialized = true;
    notifyListeners();
  }
}

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _settingsBox.put('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  void _loadData() {
    if (_participantsBox.isEmpty) {
      _participants = [
        Participant(id: '1', name: 'Ananya'),
        Participant(id: '2', name: 'Gitesh'),
        Participant(id: '3', name: 'Doulsy'),
      ];
      _saveParticipants();
    } else {
      _participants = _participantsBox.values.map((item) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map);
        return Participant.fromJson(map);
      }).toList();
    }

    _expenses = _expensesBox.values.map((item) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map);
      return Expense.fromJson(map);
    }).toList();

    _recalculateBalances();
  }

  Future<void> _saveParticipants() async {
    await _participantsBox.clear();
    for (var i = 0; i < _participants.length; i++) {
      await _participantsBox.put(i, _participants[i].toJson());
    }
  }

  Future<void> _saveExpenses() async {
    await _expensesBox.clear();
    for (var i = 0; i < _expenses.length; i++) {
      await _expensesBox.put(i, _expenses[i].toJson());
    }
  }

  void addParticipant(String name) {
    if (name.trim().isEmpty) return;
    _participants.add(Participant(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
    ));
    _recalculateBalances();
    _saveParticipants();
    notifyListeners();
  }

  void deleteExpense(String expenseId) {
    _expenses.removeWhere((e) => e.id == expenseId);
    _recalculateBalances();
    _saveExpenses();
    notifyListeners();
  }

  void restoreExpense(Expense expense, int index) {
    _expenses.insert(index, expense);
    _recalculateBalances();
    _saveExpenses();
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
      return "Payer amounts (₹${paidTotal.toStringAsFixed(2)}) must sum up to total (₹${totalAmount.toStringAsFixed(2)}).";
    }

    if (splitMode == SplitMode.specific) {
      final allocatedTotal = allocations.values.fold(0.0, (a, b) => a + b);
      if ((allocatedTotal - totalAmount).abs() > 0.01) {
        return "Allocations (₹${allocatedTotal.toStringAsFixed(2)}) must match total (₹${totalAmount.toStringAsFixed(2)}).";
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
    _saveExpenses();
    notifyListeners();
    return null;
  }

  // FIX 2: Safe participant lookups using firstWhereOrNull to prevent crashes
  void _recalculateBalances() {
    for (var p in _participants) {
      p.netBalance = 0.0;
    }

    for (var expense in _expenses) {
      expense.payers.forEach((userId, amount) {
        final index = _participants.indexWhere((item) => item.id == userId);
        if (index != -1) {
          _participants[index].netBalance += amount;
        }
      });

      if (expense.splitMode == SplitMode.uniform) {
        final count = expense.allocations.length;
        if (count > 0) {
          final baseShare = (expense.totalAmount / count);
          expense.allocations.forEach((userId, _) {
            final index = _participants.indexWhere((item) => item.id == userId);
            if (index != -1) {
              _participants[index].netBalance -= baseShare;
            }
          });
        }
      } else if (expense.splitMode == SplitMode.specific) {
        expense.allocations.forEach((userId, amount) {
          final index = _participants.indexWhere((item) => item.id == userId);
          if (index != -1) {
            _participants[index].netBalance -= amount;
          }
        });
      } else if (expense.splitMode == SplitMode.ratio) {
        expense.allocations.forEach((userId, percentage) {
          final index = _participants.indexWhere((item) => item.id == userId);
          if (index != -1) {
            _participants[index].netBalance -= (expense.totalAmount * (percentage / 100.0));
          }
        });
      }
    }
  }

  List<Settlement> calculateMinimumTransactions() {
    List<double> amountList = _participants.map((p) => p.netBalance).toList();
    List<Settlement> settlements = [];

    if (amountList.isEmpty) return settlements;

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

  bool isDuplicateParticipant(String name) {
    final trimmed = name.trim().toLowerCase();
    return _participants.any((p) => p.name.trim().toLowerCase() == trimmed);
  }

  // Create Group Room
  Future<void> createGroup(String userName) async {
    final code = Random().nextInt(90000) + 10000; // 5-digit code
    _groupId = code.toString();

    final groupRef = FirebaseFirestore.instance.collection('groups').doc(_groupId);

    await groupRef.set({
      'createdAt': FieldValue.serverTimestamp(),
      'members': [_currentUserId],
    });

    // Add User as Participant
    await groupRef.collection('participants').doc(_currentUserId).set({
      'name': userName,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    _listenToGroupUpdates();
  }

  // Join Existing Room
  Future<void> joinGroup(String userName, String code) async {
    _groupId = code;
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(_groupId);

    await groupRef.update({
      'members': FieldValue.arrayUnion([_currentUserId]),
    });

    await groupRef.collection('participants').doc(_currentUserId).set({
      'name': userName,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    _listenToGroupUpdates();
  }

  // Live Stream Expenses from Cloud Firestore
  void _listenToGroupUpdates() {
    if (_groupId == null) return;

    FirebaseFirestore.instance
        .collection('groups')
        .doc(_groupId)
        .collection('expenses')
        .snapshots()
        .listen((snapshot) {
      // Sync Cloud Data to Local Hive and UI State
      notifyListeners();
    });
  }
}