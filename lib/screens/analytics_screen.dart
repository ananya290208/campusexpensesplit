import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Analytics & Insights')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          double myTotal = 0;
          double groupTotal = 0;
          Map<String, double> monthlyData = {};
          Map<String, double> categoryData = {
            'Food & Dining': 0,
            'Utilities': 0,
            'Travel': 0,
            'Others': 0,
          };

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final title = (data['title'] ?? '').toString().toLowerCase();
            final createdAt = data['createdAt'];

            groupTotal += amt;
            if (data['paidBy'] == user?.uid) {
              myTotal += amt;
            }

            // Monthly breakdown estimation based on timestamp
            String monthKey = 'Current';
            if (createdAt is Timestamp) {
              DateTime date = createdAt.toDate();
              monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
            }
            monthlyData[monthKey] = (monthlyData[monthKey] ?? 0.0) + amt;

            // Simple categorization simulation based on title keywords
            if (title.contains('food') || title.contains('dinner') || title.contains('lunch') || title.contains('cafe')) {
              categoryData['Food & Dining'] = (categoryData['Food & Dining']! + amt);
            } else if (title.contains('bill') || title.contains('electricity') || title.contains('rent') || title.contains('wifi')) {
              categoryData['Utilities'] = (categoryData['Utilities']! + amt);
            } else if (title.contains('uber') || title.contains('cab') || title.contains('train') || title.contains('travel')) {
              categoryData['Travel'] = (categoryData['Travel']! + amt);
            } else {
              categoryData['Others'] = (categoryData['Others']! + amt);
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overall Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildAnalyticsCard('Your Contribution', myTotal, Colors.deepPurple)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildAnalyticsCard('Total Spending', groupTotal, Colors.teal)),
                  ],
                ),
                const SizedBox(height: 28),
                const Text('Monthly Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                _buildCustomBarChart(monthlyData, Colors.indigo),
                const SizedBox(height: 28),
                const Text('Expense Category Pie Chart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                _buildPieChartCard(categoryData, groupTotal),
                const SizedBox(height: 28),
                const Text('Detailed Category Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                _buildCategoryBreakdown(categoryData, groupTotal),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsCard(String label, double amount, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // Custom-drawn visual bar representation for monthly trends
  Widget _buildCustomBarChart(Map<String, double> data, Color color) {
    if (data.isEmpty) {
      return const Text('No monthly data available yet.', style: TextStyle(color: Colors.grey));
    }

    double maxVal = data.values.fold(1.0, (prev, element) => element > prev ? element : prev);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: data.entries.map((entry) {
            double percentage = (entry.value / maxVal).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('\$${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Custom Pie Chart Widget with Legend
  Widget _buildPieChartCard(Map<String, double> categories, double total) {
    final colors = [Colors.purple, Colors.teal, Colors.orange, Colors.blue];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              width: 180,
              child: CustomPaint(
                painter: _PieChartPainter(categories: categories, total: total, colors: colors),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: categories.entries.map((entry) {
                int index = categories.keys.toList().indexOf(entry.key);
                Color color = colors[index % colors.length];

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Custom visual category breakdown bars
  Widget _buildCategoryBreakdown(Map<String, double> categories, double total) {
    final colors = [Colors.purple, Colors.teal, Colors.orange, Colors.blue];
    int index = 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: categories.entries.map((entry) {
            double catVal = entry.value;
            double percentage = total > 0 ? (catVal / total) : 0.0;
            Color barColor = colors[index % colors.length];
            index++;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${(percentage * 100).toStringAsFixed(1)}% (\$${catVal.toStringAsFixed(2)})', 
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// Custom Painter to render the clean proportioned arc segments for the pie chart
class _PieChartPainter extends CustomPainter {
  final Map<String, double> categories;
  final double total;
  final List<Color> colors;

  _PieChartPainter({required this.categories, required this.total, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    double startAngle = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (total <= 0) {
      paint.color = Colors.grey.shade300;
      canvas.drawArc(rect, 0, 2 * math.pi, true, paint);
      return;
    }

    int index = 0;
    categories.forEach((key, value) {
      if (value > 0) {
        final sweepAngle = (value / total) * 2 * math.pi;
        paint.color = colors[index % colors.length];
        canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
        startAngle += sweepAngle;
      }
      index++;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}