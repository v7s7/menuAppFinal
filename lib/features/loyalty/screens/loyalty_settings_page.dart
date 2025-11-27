import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/loyalty_models.dart';
import '../data/loyalty_service.dart';

/// Merchant page for configuring loyalty program settings
class LoyaltySettingsPage extends ConsumerStatefulWidget {
  const LoyaltySettingsPage({super.key});

  @override
  ConsumerState<LoyaltySettingsPage> createState() => _LoyaltySettingsPageState();
}

class _LoyaltySettingsPageState extends ConsumerState<LoyaltySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Form controllers
  late TextEditingController _earnRateController;
  late TextEditingController _redeemRateController;
  late TextEditingController _minOrderController;
  late TextEditingController _maxDiscountController;
  late TextEditingController _minPointsController;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _earnRateController = TextEditingController();
    _redeemRateController = TextEditingController();
    _minOrderController = TextEditingController();
    _maxDiscountController = TextEditingController();
    _minPointsController = TextEditingController();
  }

  @override
  void dispose() {
    _earnRateController.dispose();
    _redeemRateController.dispose();
    _minOrderController.dispose();
    _maxDiscountController.dispose();
    _minPointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(loyaltySettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty Program Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'View Customers',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersListPage()),
              );
            },
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (settings) {
          // Initialize form values
          if (_earnRateController.text.isEmpty) {
            _earnRateController.text = settings.earnRate.toString();
            _redeemRateController.text = settings.redeemRate.toString();
            _minOrderController.text = settings.minOrderAmount.toStringAsFixed(3);
            _maxDiscountController.text = settings.maxDiscountAmount.toStringAsFixed(3);
            _minPointsController.text = settings.minPointsToRedeem.toString();
            _enabled = settings.enabled;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enable/Disable Switch
                  Card(
                    child: SwitchListTile(
                      title: const Text('Enable Loyalty Program'),
                      subtitle: const Text('Turn loyalty points on/off for customers'),
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Earning Rules
                  Text(
                    'Earning Rules',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure how customers earn points when they place orders',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller: _earnRateController,
                    label: 'Points Earned Per 1 BHD',
                    hint: 'e.g., 10 (customer gets 10 points for every 1 BHD spent)',
                    icon: Icons.add_circle,
                    isInteger: true,
                  ),
                  const SizedBox(height: 16),
                  _buildExampleCard(
                    'Example: If set to 10, a 40 BHD order earns 400 points',
                    Colors.green,
                  ),
                  const SizedBox(height: 32),

                  // Redemption Rules
                  Text(
                    'Redemption Rules',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure how customers redeem points for discounts',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller: _redeemRateController,
                    label: 'Points Needed For 1 BHD Discount',
                    hint: 'e.g., 50 (customer needs 50 points to get 1 BHD off)',
                    icon: Icons.remove_circle,
                    isInteger: true,
                  ),
                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller: _minPointsController,
                    label: 'Minimum Points To Redeem',
                    hint: 'e.g., 50 (minimum points needed to use discount)',
                    icon: Icons.trending_down,
                    isInteger: true,
                  ),
                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller: _minOrderController,
                    label: 'Minimum Order Amount (BHD)',
                    hint: 'e.g., 5.000 (min order to use points)',
                    icon: Icons.shopping_cart,
                    isInteger: false,
                  ),
                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller: _maxDiscountController,
                    label: 'Maximum Discount Amount (BHD)',
                    hint: 'e.g., 10.000 (max discount per order)',
                    icon: Icons.discount,
                    isInteger: false,
                  ),
                  const SizedBox(height: 16),

                  _buildExampleCard(
                    'Example: Customer has 250 points\n'
                    '→ Can get 5 BHD discount (250 ÷ 50 = 5)\n'
                    '→ Must spend at least 5 BHD to use points\n'
                    '→ Cannot get more than 10 BHD discount per order',
                    Colors.blue,
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : () => _saveSettings(settings),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Test Calculator
                  const SizedBox(height: 32),
                  _buildTestCalculator(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isInteger,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      inputFormatters: isInteger
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}'))],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Required';
        }
        final num = isInteger ? int.tryParse(value) : double.tryParse(value);
        if (num == null || num <= 0) {
          return 'Must be greater than 0';
        }
        return null;
      },
    );
  }

  Widget _buildExampleCard(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color.withOpacity(0.9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCalculator() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Test Calculator',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _TestCalculatorWidget(
              earnRate: int.tryParse(_earnRateController.text) ?? 10,
              redeemRate: int.tryParse(_redeemRateController.text) ?? 50,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings(LoyaltySettings currentSettings) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final newSettings = LoyaltySettings(
        enabled: _enabled,
        earnRate: int.parse(_earnRateController.text),
        redeemRate: int.parse(_redeemRateController.text),
        minOrderAmount: double.parse(_minOrderController.text),
        maxDiscountAmount: double.parse(_maxDiscountController.text),
        minPointsToRedeem: int.parse(_minPointsController.text),
      );

      await ref.read(loyaltyServiceProvider).updateLoyaltySettings(newSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Loyalty settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _TestCalculatorWidget extends StatefulWidget {
  final int earnRate;
  final int redeemRate;

  const _TestCalculatorWidget({
    required this.earnRate,
    required this.redeemRate,
  });

  @override
  State<_TestCalculatorWidget> createState() => _TestCalculatorWidgetState();
}

class _TestCalculatorWidgetState extends State<_TestCalculatorWidget> {
  final _orderAmountController = TextEditingController(text: '40.000');
  final _pointsController = TextEditingController(text: '250');

  @override
  void dispose() {
    _orderAmountController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderAmount = double.tryParse(_orderAmountController.text) ?? 0;
    final points = int.tryParse(_pointsController.text) ?? 0;

    final earnedPoints = (orderAmount * widget.earnRate).round();
    final discount = (points / widget.redeemRate).floor();

    return Column(
      children: [
        TextField(
          controller: _orderAmountController,
          decoration: const InputDecoration(
            labelText: 'Order Amount (BHD)',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '→ Customer earns $earnedPoints points',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pointsController,
          decoration: const InputDecoration(
            labelText: 'Customer Has Points',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '→ Can get $discount BHD discount',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Page to view all customers
class CustomersListPage extends ConsumerWidget {
  const CustomersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(allCustomersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty Customers'),
      ),
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No customers yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(customer.points.toString()),
                ),
                title: Text(customer.phone),
                subtitle: Text(
                  '${customer.carPlate} • ${customer.orderCount} orders • BHD ${customer.totalSpent.toStringAsFixed(3)} spent',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${customer.points} pts',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (customer.lastOrderAt != null)
                      Text(
                        _formatDate(customer.lastOrderAt!),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}
