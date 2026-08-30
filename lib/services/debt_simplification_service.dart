class DebtSimplificationService {
  /// Simplifies complex debt webs into the minimum number of direct peer repayment tasks.
  static List<Map<String, dynamic>> calculateOptimizedDebts(Map<String, double> balances) {
    List<Map<String, dynamic>> debtors = [];
    List<Map<String, dynamic>> creditors = [];

    balances.forEach((person, amount) {
      if (amount < -0.01) {
        debtors.add({'person': person, 'amount': -amount});
      } else if (amount > 0.01) {
        creditors.add({'person': person, 'amount': amount});
      }
    });

    // Sort descending for greedy matching
    debtors.sort((a, b) => b['amount'].compareTo(a['amount']));
    creditors.sort((a, b) => b['amount'].compareTo(a['amount']));

    List<Map<String, dynamic>> transactions = [];
    int i = 0, j = 0;

    while (i < debtors.length && j < creditors.length) {
      double paidAmount = debtors[i]['amount'] < creditors[j]['amount'] 
          ? debtors[i]['amount'] 
          : creditors[j]['amount'];

      transactions.add({
        'from': debtors[i]['person'],
        'to': creditors[j]['person'],
        'amount': paidAmount,
      });

      debtors[i]['amount'] -= paidAmount;
      creditors[j]['amount'] -= paidAmount;

      if (debtors[i]['amount'] < 0.01) i++;
      if (creditors[j]['amount'] < 0.01) j++;
    }

    return transactions;
  }
}