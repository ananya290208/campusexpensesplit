class Participant {
  final String id;
  final String name;
  double netBalance; // Positive = owed money, Negative = owes money

  Participant({
    required this.id,
    required this.name,
    this.netBalance = 0.0,
  });
}