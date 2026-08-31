import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import '../widgets/user_badge.dart';

enum SplitType { uniform, specific, ratio }

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _groupCodeController = TextEditingController();

  String? _selectedGroupId;
  String? _selectedGroupName;
  final List<Map<String, String>> _groupMembers = []; // Contains {uid, name}

  // Expense Category Selection with 'Movie' as default
  String _selectedCategory = 'Movie';
  final List<String> _categories = ['Movie', 'Food & Dining', 'Utilities', 'Travel', 'Others'];

  SplitType _selectedSplitType = SplitType.uniform;
  final Map<String, TextEditingController> _splitControllers = {};
  final Map<String, TextEditingController> _paidControllers = {}; // For multiple contributors

  bool _isLoading = false;
  List<Map<String, dynamic>> _matchingGroups = [];

  @override
  void initState() {
    super.initState();
    _groupCodeController.addListener(_onSearchCodeChanged);
  }

  @override
  void dispose() {
    _groupCodeController.removeListener(_onSearchCodeChanged);
    _groupCodeController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    for (var controller in _splitControllers.values) {
      controller.dispose();
    }
    for (var controller in _paidControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Live search matching group codes as the user types
  void _onSearchCodeChanged() async {
    final query = _groupCodeController.text.trim();
    if (query.isEmpty) {
      setState(() => _matchingGroups = []);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      setState(() {
        _matchingGroups = snapshot.docs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      debugPrint("Error searching group name: $e");
    }
  }

  // Fetch details of members belonging to selected group
  Future<void> _fetchGroupMembers(List<dynamic> memberUids) async {
    _groupMembers.clear();
    for (var c in _splitControllers.values) {
      c.dispose();
    }
    _splitControllers.clear();

    for (var c in _paidControllers.values) {
      c.dispose();
    }
    _paidControllers.clear();

    final currentUser = FirebaseAuth.instance.currentUser;
    final totalAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    for (String uid in memberUids) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final name = userDoc.exists ? (userDoc.data()?['name'] ?? 'User').toString() : 'User';
      _groupMembers.add({'uid': uid, 'name': name});
      _splitControllers[uid] = TextEditingController(text: '0');
      
      // Default current user to full amount if first time, others 0
      if (uid == currentUser?.uid) {
        _paidControllers[uid] = TextEditingController(text: totalAmount > 0 ? totalAmount.toStringAsFixed(2) : '0');
      } else {
        _paidControllers[uid] = TextEditingController(text: '0');
      }
    }
    setState(() {});
  }

  // Dialog for group creation with dropdown & chips
  void _showCreateGroupDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final groupNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final availableUsers = usersSnapshot.docs
        .where((doc) => doc.id != currentUser.uid)
        .map((doc) => {
              'uid': doc.id,
              'name': (doc.data()['name'] ?? doc.data()['email'] ?? 'User').toString(),
            })
        .toList();

    List<Map<String, String>> selectedUsers = [];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final unselectedUsers = availableUsers
                .where((u) => !selectedUsers.any((s) => s['uid'] == u['uid']))
                .toList();

            return AlertDialog(
              title: const Text('Create New Group'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: groupNameController,
                        decoration: const InputDecoration(
                          labelText: 'Group Name (6-12 chars)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().length < 6 || v.trim().length > 12)
                            ? 'Must be 6-12 chars'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Add Members',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: UniqueKey(),
                        initialValue: null,
                        hint: const Text('Select user to add...'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: unselectedUsers.map((user) {
                          return DropdownMenuItem<String>(
                            value: user['uid'],
                            child: Text(user['name']!),
                          );
                        }).toList(),
                        onChanged: (selectedUid) {
                          if (selectedUid != null) {
                            final userObj = availableUsers.firstWhere((u) => u['uid'] == selectedUid);
                            setDialogState(() {
                              selectedUsers.add(userObj);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
                            label: const Text('You (Owner)'),
                            backgroundColor: Colors.deepPurple.shade50,
                          ),
                          ...selectedUsers.map((user) {
                            return InputChip(
                              label: Text(user['name']!),
                              onDeleted: () {
                                setDialogState(() {
                                  selectedUsers.removeWhere((u) => u['uid'] == user['uid']);
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final name = groupNameController.text.trim();
                      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
                      final roomCode = List.generate(6, (_) => chars[Random().nextInt(chars.length)]).join();

                      List<String> allMemberIds = [
                        currentUser.uid,
                        ...selectedUsers.map((u) => u['uid']!),
                      ];

                      final groupDoc = await FirebaseFirestore.instance.collection('groups').add({
                        'name': name,
                        'code': roomCode,
                        'ownerId': currentUser.uid,
                        'members': allMemberIds,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      setState(() {
                        _selectedGroupId = groupDoc.id;
                        _selectedGroupName = '$name ($roomCode)';
                      });

                      await _fetchGroupMembers(allMemberIds);

                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _joinGroup(Map<String, dynamic> group) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    List members = List.from(group['members'] ?? []);
    if (!members.contains(user.uid)) {
      members.add(user.uid);
      await FirebaseFirestore.instance.collection('groups').doc(group['docId']).update({'members': members});
    }

    setState(() {
      _selectedGroupId = group['docId'];
      _selectedGroupName = "${group['name']} (${group['code']})";
      _matchingGroups.clear();
      _groupCodeController.clear();
    });

    await _fetchGroupMembers(members);
  }

  Map<String, double> _calculateSplitShares(double totalAmount) {
    Map<String, double> shares = {};
    if (_groupMembers.isEmpty) return shares;

    if (_selectedSplitType == SplitType.uniform) {
      double perPerson = totalAmount / _groupMembers.length;
      for (var member in _groupMembers) {
        shares[member['uid']!] = perPerson;
      }
    } else if (_selectedSplitType == SplitType.specific) {
      for (var member in _groupMembers) {
        shares[member['uid']!] = double.tryParse(_splitControllers[member['uid']!]?.text ?? '0') ?? 0;
      }
    } else if (_selectedSplitType == SplitType.ratio) {
      double totalRatio = 0;
      for (var member in _groupMembers) {
        totalRatio += double.tryParse(_splitControllers[member['uid']!]?.text ?? '0') ?? 0;
      }
      for (var member in _groupMembers) {
        double ratio = double.tryParse(_splitControllers[member['uid']!]?.text ?? '0') ?? 0;
        shares[member['uid']!] = totalRatio > 0 ? (totalAmount * (ratio / totalRatio)) : 0;
      }
    }

    return shares;
  }

  Map<String, double> _calculatePaidContributions(double totalAmount) {
    Map<String, double> paidContributions = {};
    if (_groupMembers.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        paidContributions[user.uid] = totalAmount;
      }
      return paidContributions;
    }

    for (var member in _groupMembers) {
      final uid = member['uid']!;
      double paid = double.tryParse(_paidControllers[uid]?.text ?? '0') ?? 0;
      if (paid > 0) {
        paidContributions[uid] = paid;
      }
    }

    if (paidContributions.isEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        paidContributions[currentUser.uid] = totalAmount;
      }
    }

    return paidContributions;
  }

  Future<void> _saveExpense() async {
    final user = FirebaseAuth.instance.currentUser;
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (title.isEmpty || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense title.')),
      );
      return;
    }

    // Input validation for negative or zero amounts
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense amount must be greater than \$0.00.')),
      );
      return;
    }

    final paidContributions = _calculatePaidContributions(amount);

    // Validate that total paid contributions equal the total expense amount
    if (_groupMembers.isNotEmpty) {
      double totalPaidSum = paidContributions.values.fold(0.0, (sum, val) => sum + val);
      // Using a small tolerance (0.01) for floating-point math
      if ((totalPaidSum - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Total paid contributions (\$${totalPaidSum.toStringAsFixed(2)}) must equal the total amount (\$${amount.toStringAsFixed(2)})!')),
        );
        return;
      }
    }

    final shares = _calculateSplitShares(amount);

    setState(() => _isLoading = true);

    final expenseData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'amount': amount,
      'category': _selectedCategory,
      'paidBy': user.uid,
      'paidContributions': paidContributions,
      'groupId': _selectedGroupId ?? 'personal',
      'splitType': _selectedSplitType.name,
      'shares': shares,
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Hive Caching
    final cacheBox = Hive.box('expenses_cache');
    await cacheBox.add(expenseData);

    try {
      await FirebaseFirestore.instance.collection('expenses').add({
        'title': title,
        'amount': amount,
        'category': _selectedCategory,
        'paidBy': user.uid,
        'paidContributions': paidContributions,
        'groupId': _selectedGroupId ?? 'personal',
        'splitType': _selectedSplitType.name,
        'shares': shares,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved locally. Will sync when reconnected.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: const [UserBadge()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Group Selection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _showCreateGroupDialog,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Create Group'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _groupCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Search Group Code',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            if (_matchingGroups.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _matchingGroups.length,
                  itemBuilder: (context, index) {
                    final g = _matchingGroups[index];
                    return ListTile(
                      title: Text(g['name'] ?? 'Unnamed Group'),
                      subtitle: Text('Code: ${g['code']}'),
                      trailing: const Icon(Icons.add_task, color: Colors.deepPurple),
                      onTap: () => _joinGroup(g),
                    );
                  },
                ),
              ),
            ],
            if (_selectedGroupName != null) ...[
              const SizedBox(height: 12),
              Chip(
                avatar: const Icon(Icons.check_circle, color: Colors.green),
                label: Text('Group: $_selectedGroupName'),
                onDeleted: () => setState(() {
                  _selectedGroupId = null;
                  _selectedGroupName = null;
                  _groupMembers.clear();
                }),
              ),
            ],
            const Divider(height: 32),
            const Text('Expense Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Expense Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Amount (\$) ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            // Expense Category Dropdown with 'Movie' selected by default
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Expense Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
            ),
            const SizedBox(height: 20),

            // Payer Breakdown Section for Multiple Contributors
            if (_groupMembers.isNotEmpty) ...[
              const Text('Payer Breakdown (Who Paid)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ..._groupMembers.map((member) {
                final uid = member['uid']!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(child: Text(member['name']!)),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _paidControllers[uid],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Paid Amount',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            const Text('Split Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SegmentedButton<SplitType>(
              segments: const [
                ButtonSegment(value: SplitType.uniform, label: Text('Uniform')),
                ButtonSegment(value: SplitType.specific, label: Text('Specific')),
                ButtonSegment(value: SplitType.ratio, label: Text('Ratio')),
              ],
              selected: {_selectedSplitType},
              onSelectionChanged: (set) => setState(() => _selectedSplitType = set.first),
            ),
            const SizedBox(height: 16),
            if (_groupMembers.isNotEmpty) ...[
              const Text('Share Breakdown', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._groupMembers.map((member) {
                final uid = member['uid']!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(child: Text(member['name']!)),
                      if (_selectedSplitType == SplitType.uniform)
                        Text('\$${(totalAmount / _groupMembers.length).toStringAsFixed(2)}')
                      else
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _splitControllers[uid],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: _selectedSplitType == SplitType.specific ? 'Amount' : 'Ratio Weight',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: _saveExpense,
                    child: const Text('Save Expense'),
                  ),
          ],
        ),
      ),
    );
  }
}