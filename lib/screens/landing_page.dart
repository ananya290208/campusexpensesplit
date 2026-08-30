import 'package:campusexpensesplit/screens/settlement_optimization_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import 'login_screen.dart';
import 'add_expense_screen.dart';
import 'expense_summary_screen.dart';
import 'analytics_screen.dart';
import 'expense_history_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Expense Split'),
        actions: [
          IconButton(
            icon: Icon(provider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => provider.toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle, size: 18, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildMenuCard(
                context,
                title: 'Add Expense',
                subtitle: 'Create/Join group & add receipts',
                icon: Icons.add_circle_outline,
                color: Colors.deepPurple,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
              ),
              const SizedBox(height: 10),
              _buildMenuCard(
                context,
                title: 'Expense Summary',
                subtitle: 'Check net balances & settle up',
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseSummaryScreen())),
              ),
              const SizedBox(height: 10),
              _buildMenuCard(
                context,
                title: 'Expense Analytics',
                subtitle: 'Self & Group spending trends',
                icon: Icons.insights_outlined,
                color: Colors.indigo,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
              ),
              const SizedBox(height: 10),
              _buildMenuCard(
                context,
                title: 'Expense History',
                subtitle: 'Swipe to delete records with undo support',
                icon: Icons.history_rounded,
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseHistoryScreen())),
              ),
              const SizedBox(height: 10),
              _buildMenuCard(
                context,
                title: 'Settlement Optimization',
                subtitle: 'Simplify debt webs & mock payments',
                icon: Icons.alt_route_rounded,
                color: Colors.amber.shade800,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettlementOptimizationScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 75,
      child: Card(
        elevation: 3,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}