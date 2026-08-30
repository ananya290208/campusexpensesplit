import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models.dart';
import '../provider.dart'; // Fixed import to standard provider.dart

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final categoryData = provider.getCategorySpending();
    final totalSpend = categoryData.values.fold(0.0, (a, b) => a + b);

    if (totalSpend == 0) {
      return const Center(child: Text('Add expenses to view spend insights.'));
    }

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.orange,
      Colors.green,
      Colors.purple
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 80.0),
      child: Column(
        children: [
          const Text(
            'Spend Distribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: ExpenseCategory.values.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final cat = entry.value;
                  final val = categoryData[cat] ?? 0.0;
                  final pct = totalSpend > 0 ? (val / totalSpend * 100) : 0.0;

                  return PieChartSectionData(
                    color: colors[idx % colors.length],
                    value: val,
                    // Fixed string interpolation with $ symbol:
                    title: pct > 0 ? '₹${pct.toStringAsFixed(0)}%' : '',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...ExpenseCategory.values.asMap().entries.map((entry) {
            final idx = entry.key;
            final cat = entry.value;
            // Uncommented and restored definition of val:
            final val = categoryData[cat] ?? 0.0;

            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
              leading: CircleAvatar(
                backgroundColor: colors[idx % colors.length],
                radius: 6,
              ),
              title: Text(
                cat.name.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: Text(
                // Fixed string interpolation with $ symbol:
                '₹${val.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          }),
        ],
      ),
    );
  }
}