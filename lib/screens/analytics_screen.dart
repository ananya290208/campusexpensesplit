import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../widgets/user_badge.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static final Map<String, Color> _categoryColorMap = {
    'Food & Dining': Colors.teal,
    'Movie & Entertainment': Colors.purple,
    'Utilities & Bills': Colors.orange.shade800,
    'Travel & Commute': Colors.blue.shade700,
    'Printouts & Stationery': Colors.pink.shade600,
    'Subscriptions': Colors.indigo.shade600,
    'General / Others': Colors.blueGrey.shade600,
  };

  static final List<Color> _fallbackPalette = [
    Colors.teal,
    Colors.purple,
    Colors.orange.shade800,
    Colors.blue.shade700,
    Colors.pink.shade600,
    Colors.indigo.shade600,
    Colors.deepPurple,
    Colors.cyan.shade700,
    Colors.green.shade600,
    Colors.amber.shade800,
  ];

  static Color _getCategoryColor(String category, int index) {
    if (_categoryColorMap.containsKey(category)) {
      return _categoryColorMap[category]!;
    }
    return _fallbackPalette[index % _fallbackPalette.length];
  }

  static String _resolveCategory(Map<String, dynamic> data) {
    // 1. Check direct 'category' field in Firestore document
    final dynamic catField = data['category'];
    if (catField != null) {
      if (catField is String && catField.trim().isNotEmpty) {
        final trimmed = catField.trim();
        final lower = trimmed.toLowerCase();
        if (lower.contains('food') || lower.contains('dining') || lower.contains('restaurant') || lower.contains('cafe') || lower.contains('meal') || lower.contains('snack') || lower.contains('chai') || lower.contains('tea') || lower.contains('coffee')) {
          return 'Food & Dining';
        } else if (lower.contains('movie') || lower.contains('cinema') || lower.contains('film') || lower.contains('entertainment') || lower.contains('show')) {
          return 'Movie & Entertainment';
        } else if (lower.contains('utilit') || lower.contains('bill') || lower.contains('electricity') || lower.contains('rent') || lower.contains('wifi') || lower.contains('water') || lower.contains('gas')) {
          return 'Utilities & Bills';
        } else if (lower.contains('travel') || lower.contains('auto') || lower.contains('cab') || lower.contains('commute') || lower.contains('transport') || lower.contains('uber') || lower.contains('ola') || lower.contains('train') || lower.contains('bus') || lower.contains('petrol')) {
          return 'Travel & Commute';
        } else if (lower.contains('print') || lower.contains('xerox') || lower.contains('stationery') || lower.contains('book') || lower.contains('notes')) {
          return 'Printouts & Stationery';
        } else if (lower.contains('subscript') || lower.contains('netflix') || lower.contains('spotify') || lower.contains('membership')) {
          return 'Subscriptions';
        } else if (lower.contains('other') || lower.contains('general')) {
          return 'General / Others';
        }
        return trimmed;
      } else if (catField is int) {
        // Mapped to ExpenseCategory index: auto, subscription, food, printout, general
        switch (catField) {
          case 0:
            return 'Travel & Commute';
          case 1:
            return 'Subscriptions';
          case 2:
            return 'Food & Dining';
          case 3:
            return 'Printouts & Stationery';
          case 4:
          default:
            return 'General / Others';
        }
      }
    }

    // 2. Comprehensive keyword fallback based on expense title if category field was omitted or blank
    final title = (data['title'] ?? '').toString().toLowerCase();
    if (title.contains('food') || title.contains('dinner') || title.contains('lunch') || title.contains('breakfast') || title.contains('cafe') || title.contains('pizza') || title.contains('burger') || title.contains('canteen') || title.contains('mess') || title.contains('snack') || title.contains('chai') || title.contains('tea') || title.contains('coffee') || title.contains('swiggy') || title.contains('zomato') || title.contains('mcdonald') || title.contains('domino') || title.contains('biryani') || title.contains('roll') || title.contains('dosa') || title.contains('maggi') || title.contains('grocer') || title.contains('milk') || title.contains('bread') || title.contains('egg') || title.contains('fruit') || title.contains('vegetable') || title.contains('market') || title.contains('eat') || title.contains('sweet')) {
      return 'Food & Dining';
    } else if (title.contains('movie') || title.contains('cinema') || title.contains('theatre') || title.contains('film') || title.contains('show') || title.contains('pvr') || title.contains('inox')) {
      return 'Movie & Entertainment';
    } else if (title.contains('bill') || title.contains('electricity') || title.contains('rent') || title.contains('wifi') || title.contains('water') || title.contains('gas') || title.contains('recharge') || title.contains('maintenance') || title.contains('flat') || title.contains('hostel') || title.contains('maid') || title.contains('cook') || title.contains('broadband')) {
      return 'Utilities & Bills';
    } else if (title.contains('uber') || title.contains('ola') || title.contains('auto') || title.contains('cab') || title.contains('train') || title.contains('metro') || title.contains('bus') || title.contains('travel') || title.contains('petrol') || title.contains('fuel') || title.contains('diesel') || title.contains('flight') || title.contains('rickshaw') || title.contains('toll') || title.contains('parking') || title.contains('trip') || title.contains('fare')) {
      return 'Travel & Commute';
    } else if (title.contains('print') || title.contains('xerox') || title.contains('stationery') || title.contains('note') || title.contains('assignment') || title.contains('copy') || title.contains('book') || title.contains('pen') || title.contains('paper') || title.contains('project') || title.contains('binding')) {
      return 'Printouts & Stationery';
    } else if (title.contains('netflix') || title.contains('prime') || title.contains('spotify') || title.contains('youtube') || title.contains('hotstar') || title.contains('subscription') || title.contains('apple') || title.contains('gym') || title.contains('course') || title.contains('udemy') || title.contains('coursera')) {
      return 'Subscriptions';
    }

    return 'General / Others';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Analytics & Insights'),
        actions: const [UserBadge()],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .where('members', arrayContains: uid)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userGroupDocs = groupSnapshot.data?.docs ?? [];
          final Set<String> userGroupIds = userGroupDocs.map((d) => d.id).toSet();
          userGroupIds.add('personal');

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data?.docs ?? [];
              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final groupId = (data['groupId'] ?? 'personal').toString();
                final paidBy = (data['paidBy'] ?? '').toString();
                final paidContributions = data['paidContributions'] as Map<String, dynamic>?;
                final shares = data['shares'] as Map<String, dynamic>?;

                final bool isGroupMember = userGroupIds.contains(groupId);
                final bool isPayer = paidBy == uid || (paidContributions != null && paidContributions.containsKey(uid));
                final bool isSplitParticipant = shares != null && shares.containsKey(uid);

                return isGroupMember || isPayer || isSplitParticipant;
              }).toList();

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No expenses found for your groups yet.\nAdd an expense to view visual analytics!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                );
              }

              double myTotal = 0;
              double groupTotal = 0;
              Map<String, double> monthlyData = {};
              Map<String, double> categoryData = {
                'Food & Dining': 0,
                'Movie & Entertainment': 0,
                'Utilities & Bills': 0,
                'Travel & Commute': 0,
                'Printouts & Stationery': 0,
                'Subscriptions': 0,
                'General / Others': 0,
              };

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final paidBy = (data['paidBy'] ?? '').toString();
                final paidContributions = data['paidContributions'] as Map<String, dynamic>?;
                final createdAt = data['createdAt'];

                groupTotal += amt;
                if (paidContributions != null && paidContributions.containsKey(uid)) {
                  myTotal += ((paidContributions[uid] as num?)?.toDouble() ?? 0.0);
                } else if (paidBy == uid) {
                  myTotal += amt;
                }

                // Monthly breakdown calculation based on timestamp
                String monthKey = 'Recent';
                if (createdAt is Timestamp) {
                  DateTime date = createdAt.toDate();
                  monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
                }
                monthlyData[monthKey] = (monthlyData[monthKey] ?? 0.0) + amt;

                // Resolve proper category
                final category = _resolveCategory(data);
                categoryData[category] = (categoryData[category] ?? 0.0) + amt;
              }

          // Build dynamic color mapping for active categories
          Map<String, Color> activeCategoryColors = {};
          int colorIndex = 0;
          categoryData.forEach((cat, val) {
            if (val > 0) {
              activeCategoryColors[cat] = _getCategoryColor(cat, colorIndex++);
            }
          });

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
                const Text('Expense Category Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                _buildPieChartCard(categoryData, groupTotal, activeCategoryColors),
                const SizedBox(height: 28),
                const Text('Detailed Category Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                _buildCategoryBreakdown(categoryData, groupTotal, activeCategoryColors),
                const SizedBox(height: 28),
                const Text('All Expenses by Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                _buildCategorizedExpenseList(docs, activeCategoryColors),
              ],
            ),
          );
            },
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

  // Custom Pie Chart Widget with Legend & Matched Colors
  Widget _buildPieChartCard(Map<String, double> categories, double total, Map<String, Color> categoryColors) {
    final activeEntries = categories.entries.where((e) => e.value > 0).toList();

    if (activeEntries.isEmpty || total <= 0) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: Text('No category data available yet.', style: TextStyle(color: Colors.grey))),
        ),
      );
    }

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
                painter: _PieChartPainter(
                  categories: categories,
                  total: total,
                  categoryColors: categoryColors,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: activeEntries.map((entry) {
                final color = categoryColors[entry.key] ?? Colors.deepPurple;
                final percentage = (entry.value / total) * 100;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.key} (${percentage.toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
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
  Widget _buildCategoryBreakdown(Map<String, double> categories, double total, Map<String, Color> categoryColors) {
    final activeEntries = categories.entries.where((e) => e.value > 0).toList();
    // Sort highest spending category first
    activeEntries.sort((a, b) => b.value.compareTo(a.value));

    if (activeEntries.isEmpty || total <= 0) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: Text('No breakdown data available.', style: TextStyle(color: Colors.grey))),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: activeEntries.map((entry) {
            double catVal = entry.value;
            double percentage = total > 0 ? (catVal / total) : 0.0;
            Color barColor = categoryColors[entry.key] ?? Colors.deepPurple;

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

  // List of all individual expenses with their resolved category badges
  Widget _buildCategorizedExpenseList(List<QueryDocumentSnapshot> docs, Map<String, Color> categoryColors) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final doc = docs[index];
          final data = doc.data() as Map<String, dynamic>;
          final title = (data['title'] ?? 'Untitled Expense').toString();
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final category = _resolveCategory(data);
          final color = categoryColors[category] ?? Colors.blueGrey;

          IconData icon;
          if (category.contains('Food')) {
            icon = Icons.restaurant;
          } else if (category.contains('Movie')) {
            icon = Icons.movie;
          } else if (category.contains('Utilities')) {
            icon = Icons.bolt;
          } else if (category.contains('Travel')) {
            icon = Icons.directions_car;
          } else if (category.contains('Printouts')) {
            icon = Icons.print;
          } else if (category.contains('Subscriptions')) {
            icon = Icons.subscriptions;
          } else {
            icon = Icons.receipt_long;
          }

          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, size: 16, color: color),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  category,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ),
            trailing: Text(
              '\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
            ),
          );
        },
      ),
    );
  }
}

// Custom Painter to render clean proportioned arc segments for the pie chart
class _PieChartPainter extends CustomPainter {
  final Map<String, double> categories;
  final double total;
  final Map<String, Color> categoryColors;

  _PieChartPainter({
    required this.categories,
    required this.total,
    required this.categoryColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    double startAngle = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    if (total <= 0) {
      paint.color = Colors.grey.shade300;
      canvas.drawArc(rect, 0, 2 * math.pi, true, paint);
      return;
    }

    final activeCount = categories.values.where((v) => v > 0).length;

    categories.forEach((category, value) {
      if (value > 0) {
        final sweepAngle = (value / total) * 2 * math.pi;
        paint.color = categoryColors[category] ?? Colors.deepPurple;
        canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

        if (activeCount > 1) {
          canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);
        }

        startAngle += sweepAngle;
      }
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}