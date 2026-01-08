# Checkout Tabs Feature - Implementation Guide

## 🎯 Overview

Implemented a **tabbed interface** for the checkout process that dynamically adapts based on merchant configuration. Users can now choose between different order types (Car Plate, Delivery, Dine-in) when multiple options are enabled by the admin.

---

## ✨ Key Features

### 1. **Dynamic Tab Display**
- **Multiple Types Enabled**: Shows horizontal tab selector with 3 columns
- **Single Type Enabled**: Shows selected type as a highlighted card
- **No Types Enabled**: Falls back to phone-only (loyalty)

### 2. **Order Types**
Each tab represents a different fulfillment method:

| Order Type | Icon | Required Fields |
|------------|------|-----------------|
| **Car Plate** | 🚗 `directions_car` | Car plate number (7 chars) |
| **Delivery** | 🚚 `delivery_dining` | Full Bahrain address (Home, Road, Block, City) |
| **Dine-in** | 🍽️ `restaurant` | Table number (4 digits) |

### 3. **Smart Field Management**
- Only fields for the selected tab are shown
- Switching tabs automatically clears irrelevant fields
- Phone number persists across all tabs (for loyalty)

### 4. **Visual Design**
- **Selected Tab**: Purple background, white text, shadow
- **Unselected Tabs**: Transparent background, gray text
- **Single Type**: Purple-themed card with checkmark
- **80px height** tabs for easy touch targets

---

## 🔧 Technical Implementation

### Files Modified

#### 1. `lib/features/loyalty/widgets/loyalty_checkout_widget.dart`

**Added:**
- `OrderType` enum with 3 types (carPlate, delivery, dineIn)
- `selectedOrderTypeProvider` - State provider for current tab
- `_buildOrderTypeTabs()` - 3-column tab selector widget
- `_buildSingleTypeCard()` - Single type display card
- `_buildOrderTypeFields()` - Routes to appropriate field builder
- `_buildCarPlateFields()` - Car plate input UI
- `_buildDeliveryFields()` - Delivery address form
- `_buildDineInFields()` - Table number input
- `_clearFieldsForType()` - Clears irrelevant fields on tab switch

**Modified:**
- `_buildFields()` - Logic to determine available types and show tabs
- Main column structure to conditionally render tabs

#### 2. `lib/features/cart/widgets/cart_sheet.dart`

**Modified:**
- `_confirmOrder()` validation logic:
  - Checks if order type is selected (when multiple available)
  - Validates fields based on selected type only
  - Shows specific error messages per field type

---

## 🎨 UI/UX Flow

### Scenario 1: Multiple Types Enabled
```
Admin enables: Car Plate + Delivery + Dine-in
↓
User sees: 3-column tab selector
↓
User clicks: "Delivery" tab
↓
Form shows: Only address fields (Home, Road, Block, City, Flat, Notes)
↓
User switches to: "Car Plate" tab
↓
Form shows: Only car plate field (address cleared)
```

### Scenario 2: Single Type Enabled
```
Admin enables: Only Delivery
↓
User sees: Purple highlighted card "Delivery - Selected order type"
↓
Form shows: Address fields (no tabs needed)
```

### Scenario 3: Phone Only (Legacy)
```
Admin requires: Only phone (no car/delivery/table)
↓
User sees: Phone input + loyalty card
↓
No tabs displayed
```

---

## 🔐 Validation Rules

### Tab Selection Validation
- **If multiple types available**: User MUST select a tab before checkout
- Error message: `"Please select an order type to continue"`

### Field Validation (per type)
| Order Type | Validation |
|------------|------------|
| **Car Plate** | Required, 7 characters max, uppercase |
| **Delivery** | All 4 fields required (Home, Road, Block, City) |
| **Dine-in** | Required, 4 digits max |
| **Phone** | Always validated if `phoneRequired: true` |

### Validation Flow
```dart
1. Check if tab selected (when multiple types available)
2. Validate phone (if required)
3. Validate fields for selected tab ONLY
   - Car Plate: Check carPlate is not empty
   - Delivery: Check address.isValid (all 4 required fields)
   - Dine-in: Check table is not empty
4. Proceed to order creation
```

---

## 📱 Merchant Configuration

### Firestore Path
```
/merchants/{merchantId}/branches/{branchId}/config/checkoutFields
```

### Configuration Document
```json
{
  "phoneRequired": true,          // Always show phone (for loyalty)
  "plateNumberRequired": true,    // Enable Car Plate tab
  "addressRequired": true,        // Enable Delivery tab
  "tableRequired": true,          // Enable Dine-in tab
  "updatedAt": Timestamp
}
```

### Tab Display Logic
```dart
availableTypes = []
if (config.plateNumberRequired) → Add "Car Plate" tab
if (config.addressRequired) → Add "Delivery" tab
if (config.tableRequired) → Add "Dine-in" tab

if (availableTypes.length > 1) → Show tab selector
if (availableTypes.length == 1) → Show single card
if (availableTypes.length == 0) → No tabs (phone only)
```

---

## 🧪 Testing Scenarios

### Test Case 1: Multiple Tabs
1. Set Firestore config: `plateNumberRequired: true, addressRequired: true, tableRequired: true`
2. Open cart → Checkout
3. ✅ Verify 3 tabs appear: Car Plate | Delivery | Dine-in
4. Click "Delivery" tab
5. ✅ Verify address fields appear
6. Click "Car Plate" tab
7. ✅ Verify address fields clear, car plate field appears
8. Try to checkout without filling fields
9. ✅ Verify validation error for selected tab

### Test Case 2: Single Tab
1. Set Firestore config: `plateNumberRequired: false, addressRequired: true, tableRequired: false`
2. Open cart → Checkout
3. ✅ Verify single "Delivery" card appears (no tabs)
4. ✅ Verify address fields shown immediately

### Test Case 3: No Order Type Required
1. Set Firestore config: `plateNumberRequired: false, addressRequired: false, tableRequired: false`
2. Open cart → Checkout
3. ✅ Verify only phone + loyalty card appear
4. ✅ Verify checkout succeeds with just phone number

### Test Case 4: Tab Switching
1. Enable all 3 types
2. Select "Delivery" tab
3. Fill: Home=123, Road=45, Block=678, City=Manama
4. Switch to "Car Plate" tab
5. ✅ Verify address fields cleared
6. Fill: Car Plate=ABC123
7. Switch back to "Delivery" tab
8. ✅ Verify car plate cleared, address fields empty

---

## 🎯 User Benefits

1. **Clearer Intent**: User explicitly selects order type before filling details
2. **Less Clutter**: Only relevant fields shown at a time
3. **Faster Input**: No scrolling through irrelevant fields
4. **Visual Clarity**: Tab design makes options obvious
5. **Error Prevention**: Can't submit wrong field combination

---

## 🔄 Backward Compatibility

### ✅ Existing Orders
- Old orders with all fields filled still work
- Validation logic unchanged for existing data

### ✅ Existing Configs
- Merchants with old config (no tabs) continue working
- Falls back to showing all enabled fields (legacy behavior if tab selection fails)

### ✅ Firestore Rules
- No changes needed to security rules
- Validation logic remains the same
- Field requirements unchanged

---

## 🚀 Deployment Checklist

- [x] Code implemented in `loyalty_checkout_widget.dart`
- [x] Validation updated in `cart_sheet.dart`
- [x] Error messages added for tab selection
- [x] Field clearing logic on tab switch
- [x] Auto-select first tab when only one available
- [ ] Test with Firestore emulator (all 3 configs)
- [ ] Test on mobile devices (touch targets)
- [ ] Update merchant docs with new tab screenshots
- [ ] Deploy to production

---

## 📊 Configuration Examples

### Example 1: Restaurant with Delivery
```json
{
  "phoneRequired": true,
  "plateNumberRequired": false,
  "addressRequired": true,
  "tableRequired": true
}
```
→ Shows **2 tabs**: Delivery | Dine-in

### Example 2: Drive-Through Only
```json
{
  "phoneRequired": true,
  "plateNumberRequired": true,
  "addressRequired": false,
  "tableRequired": false
}
```
→ Shows **1 card**: Car Plate (no tabs)

### Example 3: All Fulfillment Methods
```json
{
  "phoneRequired": true,
  "plateNumberRequired": true,
  "addressRequired": true,
  "tableRequired": true
}
```
→ Shows **3 tabs**: Car Plate | Delivery | Dine-in

---

## 🐛 Known Limitations

1. **No Mixed Types**: User can only select ONE type per order (by design)
2. **Tab Order Fixed**: Always Car Plate → Delivery → Dine-in (not configurable)
3. **No Tab Icons Customization**: Icons are hardcoded per type
4. **Desktop Layout**: Tabs stack horizontally (may need breakpoint for very wide screens)

---

## 🎓 Code Examples

### Checking Selected Type in Custom Code
```dart
final selectedType = ref.watch(selectedOrderTypeProvider);

if (selectedType == OrderType.delivery) {
  // Show delivery-specific UI
}
```

### Programmatically Selecting a Tab
```dart
ref.read(selectedOrderTypeProvider.notifier).state = OrderType.carPlate;
```

### Getting Available Types
```dart
final config = await ref.read(checkoutFieldsServiceProvider).getCheckoutFieldsConfig();

final availableTypes = <OrderType>[];
if (config.plateNumberRequired) availableTypes.add(OrderType.carPlate);
if (config.addressRequired) availableTypes.add(OrderType.delivery);
if (config.tableRequired) availableTypes.add(OrderType.dineIn);
```

---

## 📞 Support

For questions about this feature:
1. Check `loyalty_checkout_widget.dart` for UI logic
2. Check `cart_sheet.dart` for validation logic
3. Check `checkout_fields_config.dart` for config structure
4. Review Firestore Rules for field validation

---

## ✅ Implementation Complete

**Status**: ✅ Ready for testing
**Version**: 1.0.0
**Date**: January 8, 2026
**Developer**: Claude AI + v7s7
