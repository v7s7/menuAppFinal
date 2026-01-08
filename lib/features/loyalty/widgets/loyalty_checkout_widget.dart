import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

import '../data/loyalty_models.dart';
import '../data/loyalty_service.dart';
import '../data/checkout_fields_config.dart';
import '../data/checkout_fields_service.dart';

/// State provider for customer phone number during checkout
final checkoutPhoneProvider = StateProvider<String>((ref) => '');

/// State provider for car plate during checkout
final checkoutCarPlateProvider = StateProvider<String>((ref) => '');

/// State provider for points to use
final checkoutPointsToUseProvider = StateProvider<int>((ref) => 0);

/// State provider for table number
final checkoutTableProvider = StateProvider<String>((ref) => '');

/// State providers for address fields
final checkoutAddressHomeProvider = StateProvider<String>((ref) => '');
final checkoutAddressRoadProvider = StateProvider<String>((ref) => '');
final checkoutAddressBlockProvider = StateProvider<String>((ref) => '');
final checkoutAddressFlatProvider = StateProvider<String>((ref) => '');
final checkoutAddressNotesProvider = StateProvider<String>((ref) => '');

/// Widget for loyalty checkout (phone, car plate, points)
class LoyaltyCheckoutWidget extends ConsumerStatefulWidget {
  final double orderTotal; // Current order total before discount
  final Function(CheckoutData) onCheckoutDataChanged;

  const LoyaltyCheckoutWidget({
    super.key,
    required this.orderTotal,
    required this.onCheckoutDataChanged,
  });

  @override
  ConsumerState<LoyaltyCheckoutWidget> createState() => _LoyaltyCheckoutWidgetState();
}

class _LoyaltyCheckoutWidgetState extends ConsumerState<LoyaltyCheckoutWidget> {
  // We keep the full E.164 here (ex: +97312345678)
  String _e164Phone = '';

  // Keep these for validation + profile lookup + UI helpers
  String _selectedDialCode = '+973';
  int _maxDigits = 8;

  final _phoneNumberController = TextEditingController();
  final _carPlateController = TextEditingController();
  final _pointsController = TextEditingController(text: '0');
  final _tableController = TextEditingController();

  // Address controllers
  final _addressHomeController = TextEditingController();
  final _addressRoadController = TextEditingController();
  final _addressBlockController = TextEditingController();
  final _addressFlatController = TextEditingController();
  final _addressNotesController = TextEditingController();

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _carPlateController.dispose();
    _pointsController.dispose();
    _tableController.dispose();
    _addressHomeController.dispose();
    _addressRoadController.dispose();
    _addressBlockController.dispose();
    _addressFlatController.dispose();
    _addressNotesController.dispose();
    super.dispose();
  }

  int _getMaxDigitsByDialCode(String dialCode) {
    switch (dialCode) {
      case '+973': // Bahrain
        return 8;
      case '+966': // Saudi Arabia
        return 9;
      default:
        return 10;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loyaltySettingsAsync = ref.watch(loyaltySettingsProvider);
    final checkoutFieldsConfigAsync = ref.watch(checkoutFieldsConfigProvider);

    return loyaltySettingsAsync.when(
      loading: () => const SizedBox(),
      error: (e, st) => const SizedBox(),
      data: (loyaltySettings) {
        return checkoutFieldsConfigAsync.when(
          loading: () => const SizedBox(),
          error: (e, st) {
            // If config fails to load, use defaults (phone + plate required)
            return _buildFields(
              loyaltySettings,
              const CheckoutFieldsConfig(),
            );
          },
          data: (config) => _buildFields(loyaltySettings, config),
        );
      },
    );
  }

  Widget _buildFields(LoyaltySettings loyaltySettings, CheckoutFieldsConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Row(
          children: [
            Icon(Icons.directions_car, color: loyaltySettings.enabled ? Colors.purple : Colors.grey),
            const SizedBox(width: 8),
            Text(
              loyaltySettings.enabled ? 'Customer Info & Loyalty' : 'Customer Info',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Phone Number Input (conditional)
        if (config.phoneRequired) ...[
          IntlPhoneField(
            controller: _phoneNumberController,
            initialCountryCode: 'BH',
            showCountryFlag: true,
            showDropdownIcon: true,
            dropdownIconPosition: IconPosition.trailing,
            flagsButtonPadding: const EdgeInsets.only(left: 8, right: 8),
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '${'X' * _maxDigits}',
              prefixIcon: const Icon(Icons.phone),
              border: const OutlineInputBorder(),
              helperText: '$_maxDigits digits',
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (PhoneNumber? phone) {
              final digits = (phone?.number ?? '').replaceAll(RegExp(r'\D'), '');
              final dial = phone?.countryCode ?? _selectedDialCode;
              final max = _getMaxDigitsByDialCode(dial);
              if (digits.isEmpty) return 'Phone is required';
              if (digits.length != max) return 'Enter exactly $max digits';
              return null;
            },
            onCountryChanged: (country) {
              final dial = '+${country.dialCode}';
              final max = _getMaxDigitsByDialCode(dial);

              setState(() {
                _selectedDialCode = dial;
                _maxDigits = max;
              });

              final digits = _phoneNumberController.text.replaceAll(RegExp(r'\D'), '');
              _e164Phone = digits.isEmpty ? '' : '$_selectedDialCode$digits';

              ref.read(checkoutPhoneProvider.notifier).state = _e164Phone;
              _updateCheckoutData(loyaltySettings, config);
            },
            onChanged: (phone) {
              final digits = phone.number.replaceAll(RegExp(r'\D'), '');
              final dial = phone.countryCode;
              final max = _getMaxDigitsByDialCode(dial);

              setState(() {
                _selectedDialCode = dial;
                _maxDigits = max;
              });

              _e164Phone = digits.isEmpty ? '' : '$dial$digits';

              ref.read(checkoutPhoneProvider.notifier).state = _e164Phone;
              _updateCheckoutData(loyaltySettings, config);
            },
          ),
          const SizedBox(height: 12),
        ],

        // Car Plate Input (conditional)
        if (config.plateNumberRequired) ...[
          TextField(
            controller: _carPlateController,
            decoration: const InputDecoration(
              labelText: 'Car Plate',
              hintText: 'e.g., 12345',
              prefixIcon: Icon(Icons.directions_car),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 7,
            onChanged: (value) {
              ref.read(checkoutCarPlateProvider.notifier).state = value;
              _updateCheckoutData(loyaltySettings, config);
            },
          ),
          const SizedBox(height: 12),
        ],

        // Table Number Input (conditional)
        if (config.tableRequired) ...[
          TextField(
            controller: _tableController,
            decoration: const InputDecoration(
              labelText: 'Table Number',
              hintText: 'e.g., 5',
              prefixIcon: Icon(Icons.table_restaurant),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 4,
            onChanged: (value) {
              ref.read(checkoutTableProvider.notifier).state = value;
              _updateCheckoutData(loyaltySettings, config);
            },
          ),
          const SizedBox(height: 12),
        ],

        // Address Fields (conditional)
        if (config.addressRequired) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.home, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delivery Address (Bahrain)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressHomeController,
            decoration: const InputDecoration(
              labelText: 'Building Number',
              hintText: 'e.g., 123',
              prefixIcon: Icon(Icons.apartment),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              ref.read(checkoutAddressHomeProvider.notifier).state = value;
              _updateCheckoutData(loyaltySettings, config);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressRoadController,
            decoration: const InputDecoration(
              labelText: 'Road',
              hintText: 'e.g., 12',
              prefixIcon: Icon(Icons.signpost),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              ref.read(checkoutAddressRoadProvider.notifier).state = value;
              _updateCheckoutData(loyaltySettings, config);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressBlockController,
            decoration: const InputDecoration(
              labelText: 'Block',
              hintText: 'e.g., 345',
              prefixIcon: Icon(Icons.grid_4x4),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              ref.read(checkoutAddressBlockProvider.notifier).state = value;
              _updateCheckoutData(loyaltySettings, config);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressFlatController,
            decoration: const InputDecoration(
              labelText: 'Flat / Unit (Optional)',
              hintText: 'e.g., 2A',
              prefixIcon: Icon(Icons.meeting_room),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              ref.read(checkoutAddressFlatProvider.notifier).state = value;
              _updateCheckoutData(loyaltySettings, config);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressNotesController,
            decoration: const InputDecoration(
              labelText: 'Additional Notes (Optional)',
              hintText: 'e.g., Near the park',
              prefixIcon: Icon(Icons.notes),
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (value) {
              ref.read(checkoutAddressNotesProvider.notifier).state = value;
              _updateCheckoutData(loyaltySettings, config);
            },
          ),
          const SizedBox(height: 12),
        ],

        if (loyaltySettings.enabled && config.phoneRequired) ...[
          const SizedBox(height: 4),
          _buildCustomerProfileCard(loyaltySettings),
        ],
      ],
    );
  }

  Widget _buildCustomerProfileCard(LoyaltySettings settings) {
    final phone = _e164Phone.trim();

    if (phone.isEmpty) {
      return Card(
        color: Colors.purple.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.stars, color: Colors.purple.withOpacity(0.5), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enter your phone number to see your loyalty points',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final profileAsync = ref.watch(customerProfileProvider(phone));

    return profileAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, st) => const SizedBox(),
      data: (profile) {
        final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 3);

        final pointsToEarn = settings.calculatePointsEarned(widget.orderTotal);
        final currentPoints = profile?.points ?? 0;
        final totalPointsAfterOrder = currentPoints + pointsToEarn;

        final maxUsablePoints = settings.calculateMaxUsablePoints(widget.orderTotal);
        final canUsePoints = currentPoints >= settings.minPointsToRedeem &&
            widget.orderTotal >= settings.minOrderAmount;

        return Card(
          color: Colors.purple.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.stars, color: Colors.purple),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Points',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '$currentPoints pts',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (profile != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${profile.orderCount} orders',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            currencyFormat.format(profile.totalSpent),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                  ],
                ),

                if (pointsToEarn > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You will earn $pointsToEarn points from this order',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'After order: $totalPointsAfterOrder pts',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],

                if (canUsePoints) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Use Your Points',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pointsController,
                    decoration: InputDecoration(
                      labelText: 'Points to Use',
                      hintText: 'Enter points (max: ${currentPoints.clamp(0, maxUsablePoints)})',
                      prefixIcon: const Icon(Icons.redeem),
                      border: const OutlineInputBorder(),
                      suffixIcon: TextButton(
                        onPressed: () {
                          final maxPoints = currentPoints.clamp(0, maxUsablePoints);
                          _pointsController.text = maxPoints.toString();
                          ref.read(checkoutPointsToUseProvider.notifier).state = maxPoints;
                          _updateCheckoutData(settings, const CheckoutFieldsConfig());
                        },
                        child: const Text('MAX'),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final points = int.tryParse(value) ?? 0;
                      final maxPoints = currentPoints.clamp(0, maxUsablePoints);
                      final validPoints = points.clamp(0, maxPoints);

                      if (points != validPoints) {
                        _pointsController.text = validPoints.toString();
                        _pointsController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _pointsController.text.length),
                        );
                      }

                      ref.read(checkoutPointsToUseProvider.notifier).state = validPoints;
                      _updateCheckoutData(settings, const CheckoutFieldsConfig());
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDiscountPreview(settings, currentPoints, maxUsablePoints),
                ] else if (currentPoints < settings.minPointsToRedeem) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Earn ${settings.minPointsToRedeem - currentPoints} more points to start redeeming',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (widget.orderTotal < settings.minOrderAmount) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Minimum order of ${currencyFormat.format(settings.minOrderAmount)} required to use points',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscountPreview(LoyaltySettings settings, int currentPoints, int maxUsablePoints) {
    final pointsToUse = int.tryParse(_pointsController.text) ?? 0;
    if (pointsToUse == 0) return const SizedBox();

    final discount = settings.calculateDiscount(pointsToUse);
    final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 3);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.discount, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Using $pointsToUse points',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '- ${currencyFormat.format(discount)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Points after redemption:',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                '${currentPoints - pointsToUse} pts',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateCheckoutData(LoyaltySettings settings, CheckoutFieldsConfig config) {
    final phone = _e164Phone.trim();
    final carPlate = _carPlateController.text.trim();
    final pointsToUse = int.tryParse(_pointsController.text) ?? 0;
    final discount = settings.calculateDiscount(pointsToUse);

    final table = _tableController.text.trim();

    // Build address if required
    BahrainAddress? address;
    if (config.addressRequired) {
      final home = _addressHomeController.text.trim();
      final road = _addressRoadController.text.trim();
      final block = _addressBlockController.text.trim();
      final flat = _addressFlatController.text.trim();
      final notes = _addressNotesController.text.trim();

      if (home.isNotEmpty && road.isNotEmpty && block.isNotEmpty) {
        address = BahrainAddress(
          home: home,
          road: road,
          block: block,
          flat: flat.isEmpty ? null : flat,
          notes: notes.isEmpty ? null : notes,
        );
      }
    }

    final checkoutData = CheckoutData(
      phone: phone,
      carPlate: carPlate,
      pointsToUse: pointsToUse,
      discount: discount,
      table: table.isEmpty ? null : table,
      address: address,
    );

    widget.onCheckoutDataChanged(checkoutData);
  }
}
