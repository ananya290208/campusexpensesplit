enum ExpenseCategory { auto, subscription, food, printout, general }
enum SplitMode { uniform, specific, ratio }

class Settlement {
  final String fromUser;
  final String toUser;
  final double amount;

  Settlement({
    required this.fromUser,
    required this.toUser,
    required this.amount,
  });
}

class Participant {
  final String id;
  final String name;
  double netBalance;

  Participant({
    required this.id,
    required this.name,
    this.netBalance = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'netBalance': netBalance,
      };

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: json['id'],
        name: json['name'],
        netBalance: (json['netBalance'] as num).toDouble(),
      );
}

class Expense {
  final String id;
  final String title;
  final double totalAmount;
  final Map<String, double> payers;
  final SplitMode splitMode;
  final Map<String, double> allocations;
  final DateTime timestamp;
  final ExpenseCategory category;

  Expense({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.payers,
    required this.splitMode,
    required this.allocations,
    required this.timestamp,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'totalAmount': totalAmount,
        'payers': payers,
        'splitMode': splitMode.index,
        'allocations': allocations,
        'timestamp': timestamp.toIso8601String(),
        'category': category.index,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        title: json['title'],
        totalAmount: (json['totalAmount'] as num).toDouble(),
        payers: Map<String, double>.from(
            (json['payers'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble()))),
        splitMode: SplitMode.values[json['splitMode']],
        allocations: Map<String, double>.from(
            (json['allocations'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble()))),
        timestamp: DateTime.parse(json['timestamp']),
        category: ExpenseCategory.values[json['category']],
      );
}