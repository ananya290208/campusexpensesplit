import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../provider.dart';

class AddExpenseForm extends StatefulWidget {
  const AddExpenseForm({super.key});

  @override
  State<AddExpenseForm> createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<AddExpenseForm> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  ExpenseCategory _selectedCategory = ExpenseCategory.general;
  SplitMode _splitMode = SplitMode.uniform;

  final Map<String, TextEditingController> _payerControllers = {};
  final Map<String, TextEditingController> _allocationControllers = {};
  final List<String> _selectedUniformUsers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Safety load: Ensure controllers exist for initial participants
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    for (var p in provider.participants) {
      _initParticipantControllers(p.id);
    }
  }

  // Helper method to dynamically generate controllers if new ones appear
  void _initParticipantControllers(String id) {
    _payerControllers.putIfAbsent(id, () => TextEditingController(text: '0'));
    _allocationControllers.putIfAbsent(id, () => TextEditingController(text: '0'));
    if (!_selectedUniformUsers.contains(id)) {
      _selectedUniformUsers.add(id);
    }
  }

  @override
  void dispose() {
    // Dispose all controllers properly to avoid memory & state crashes
    _titleController.dispose();
    _amountController.dispose();
    for (var controller in _payerControllers.values) {
      controller.dispose();
    }
    for (var controller in _allocationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);

    // Dynamic controller check pass
    for (var p in provider.participants) {
      _initParticipantControllers(p.id);
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Log Expense',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Total Bill Amount (₹)'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _selectedCategory,
              items: ExpenseCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase())))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 12),
            const Text('Who Paid How Much?', style: TextStyle(fontWeight: FontWeight.bold)),
            ...provider.participants.map((p) {
              return Row(
                children: [
                  Expanded(child: Text(p.name)),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _payerControllers[p.id],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(suffixText: '₹'),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 12),
            SegmentedButton<SplitMode>(
              segments: const [
                ButtonSegment(value: SplitMode.uniform, label: Text('Uniform')),
                ButtonSegment(value: SplitMode.specific, label: Text('Specific')),
                ButtonSegment(value: SplitMode.ratio, label: Text('Ratio (%)')),
              ],
              selected: {_splitMode},
              onSelectionChanged: (set) => setState(() => _splitMode = set.first),
            ),
            const SizedBox(height: 12),
            if (_splitMode == SplitMode.uniform) ...[
              Wrap(
                spacing: 8,
                children: provider.participants.map((p) {
                  final isSel = _selectedUniformUsers.contains(p.id);
                  return FilterChip(
                    label: Text(p.name),
                    selected: isSel,
                    onSelected: (val) {
                      setState(() {
                        val ? _selectedUniformUsers.add(p.id) : _selectedUniformUsers.remove(p.id);
                      });
                    },
                  );
                }).toList(),
              ),
            ] else ...[
              ...provider.participants.map((p) {
                return Row(
                  children: [
                    Expanded(child: Text(p.name)),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _allocationControllers[p.id],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          suffixText: _splitMode == SplitMode.ratio ? '%' : '₹',
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
              onPressed: () {
                final double? totalAmount = double.tryParse(_amountController.text);
                Map<String, double> payersMap = {};
                Map<String, double> allocationsMap = {};

                _payerControllers.forEach((id, ctrl) {
                  final amt = double.tryParse(ctrl.text) ?? 0.0;
                  if (amt > 0) payersMap[id] = amt;
                });

                if (_splitMode == SplitMode.uniform) {
                  for (var id in _selectedUniformUsers) {
                    allocationsMap[id] = 1.0;
                  }
                } else {
                  _allocationControllers.forEach((id, ctrl) {
                    allocationsMap[id] = double.tryParse(ctrl.text) ?? 0.0;
                  });
                }

                final err = provider.addExpense(
                  title: _titleController.text,
                  totalAmount: totalAmount ?? -1,
                  payers: payersMap,
                  splitMode: _splitMode,
                  allocations: allocationsMap,
                  category: _selectedCategory,
                );

                if (err != null) {
                  setState(() => _errorMessage = err);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}