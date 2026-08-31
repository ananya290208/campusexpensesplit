import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import 'add_expense_form.dart';

class LandingPage extends StatelessWidget {
  final Function(int) onNavigateTab;

  const LandingPage({super.key, required this.onNavigateTab});

  void _showAddBuddyDialog(BuildContext context) {
    final controller = TextEditingController();
    String? errorMessage;
    bool showBuddyList = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final provider = Provider.of<ExpenseProvider>(context, listen: false);
            final existingBuddies = provider.participants;

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CampusBuddy'),
                  IconButton(
                    icon: Icon(
                      showBuddyList ? Icons.person_add : Icons.people_alt_outlined,
                      size: 20,
                    ),
                    tooltip: showBuddyList ? 'Add Buddy' : 'View Existing Buddies',
                    onPressed: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setDialogState(() {
                          showBuddyList = !showBuddyList;
                          errorMessage = null;
                        });
                      });
                    },
                  ),
                ],
              ),
              content: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 250),
                child: showBuddyList
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Existing Buddies:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          if (existingBuddies.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text('No buddies added yet.'),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: existingBuddies.length,
                                itemBuilder: (context, index) {
                                  final buddy = existingBuddies[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      radius: 12,
                                      child: Icon(Icons.person, size: 14),
                                    ),
                                    title: Text(buddy.name),
                                  );
                                },
                              ),
                            ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: 'Buddy Name',
                                hintText: 'e.g., Alex',
                                errorText: errorMessage,
                                prefixIcon: const Icon(Icons.person),
                              ),
                              autofocus: true,
                              onChanged: (_) {
                                if (errorMessage != null) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    setDialogState(() => errorMessage = null);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                if (!showBuddyList)
                  ElevatedButton(
                    onPressed: () {
                      final name = controller.text.trim();

                      if (name.isEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setDialogState(() {
                            errorMessage = 'Please enter a name.';
                          });
                        });
                        return;
                      }

                      if (provider.isDuplicateParticipant(name)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setDialogState(() {
                            errorMessage = 'Duplicate buddy! "$name" already exists.';
                          });
                        });
                        return;
                      }

                      provider.addParticipant(name);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$name added as a CampusBuddy!')),
                      );
                    },
                    child: const Text('Add'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddExpenseModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return ChangeNotifierProvider.value(
          value: Provider.of<ExpenseProvider>(context, listen: false),
          child: const AddExpenseForm(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Compact Header
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 36,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Campus Expense Split',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              'Split group expenses instantly with your roommates & buddies',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Compact 2x2 Grid Layout
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildGridTile(
                      context,
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Add CampusBuddy',
                      subtitle: 'Add member to ledger',
                      color: Colors.blue,
                      onTap: () => _showAddBuddyDialog(context),
                    ),
                    _buildGridTile(
                      context,
                      icon: Icons.add_card_rounded,
                      title: 'Add Expenses',
                      subtitle: 'Log a new split expense',
                      color: Colors.green,
                      onTap: () => _showAddExpenseModal(context),
                    ),
                    _buildGridTile(
                      context,
                      icon: Icons.receipt_long_rounded,
                      title: 'Expenses',
                      subtitle: 'View active balances',
                      color: Colors.deepPurple,
                      onTap: () => onNavigateTab(1),
                    ),
                    _buildGridTile(
                      context,
                      icon: Icons.pie_chart_rounded,
                      title: 'Analytics',
                      subtitle: 'Spend distribution charts',
                      color: Colors.orange,
                      onTap: () => onNavigateTab(2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}