enum ExpenseCategory { auto, subscription, food, printout, general }

class Expense {
  final String id;
  final String title;
  final double totalAmount;
  final String paidById;
  final List<String> splitWithUserIds;
  final DateTime timestamp;
  final ExpenseCategory category;

  Expense({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.paidById,
    required this.splitWithUserIds,
    required this.timestamp,
    required this.category,
  });

  // Calculate equal split amount per person
  double get amountPerPerson => 
      splitWithUserIds.isEmpty ? 0.0 : totalAmount / splitWithUserIds.length;
}