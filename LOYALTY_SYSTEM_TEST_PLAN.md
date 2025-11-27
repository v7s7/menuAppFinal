# Loyalty System - Comprehensive Test Plan

## 🎯 Feature Overview

The **Loyalty Points System** allows customers to:
- Earn points based on order amount (default: 10 points per 1 BHD)
- Redeem points for discounts (default: 50 points = 1 BHD discount)
- Track points balance via phone number and car plate
- View points earned and redeemed per order

Merchants can:
- Configure all loyalty program rules (earn rate, redeem rate, minimums, maximums)
- View all customers with points balances
- See customer order history and lifetime value
- Enable/disable loyalty program

## 📋 Test Scenarios

### Scenario 1: Merchant Configuration
**Objective:** Verify merchant can configure loyalty settings

**Steps:**
1. Run merchant app: `flutter run -d web --target=lib/merchant/main_merchant.dart`
2. Login with merchant credentials
3. Navigate to Products tab
4. Click the "Loyalty Program" icon (gift card icon) in the app bar
5. Verify loyalty settings page loads with default values:
   - Enabled: ON
   - Points Earned Per 1 BHD: 10
   - Points Needed For 1 BHD Discount: 50
   - Minimum Points To Redeem: 50
   - Minimum Order Amount: 5.000 BHD
   - Maximum Discount Amount: 10.000 BHD

**Expected Result:**
- ✅ Settings page loads successfully
- ✅ All fields show default values
- ✅ Test calculator shows correct calculations
- ✅ Can save settings successfully

**Test Data:**
```
Order Amount: 40.000 BHD
→ Should earn: 400 points

Customer Has: 250 points
→ Can get: 5 BHD discount (250 ÷ 50 = 5)
```

---

### Scenario 2: Customer Earns Points (First Order)
**Objective:** Verify new customer earns points on first order

**Steps:**
1. Run customer app: `flutter run -d web`
2. Browse products and add items to cart (total: ~40 BHD)
3. Open cart sheet
4. Verify loyalty checkout widget appears
5. Enter phone number: `+973 1234 5678`
6. Enter car plate: `12345` (optional)
7. Verify "You will earn X points" message appears
8. Verify calculation: 40 BHD × 10 = 400 points
9. Confirm order
10. Go to merchant app → Loyalty Program → View Customers
11. Verify new customer appears with 400 points

**Expected Result:**
- ✅ Loyalty widget displays correctly
- ✅ Points calculation is accurate
- ✅ Customer profile created with correct data
- ✅ Points transaction logged (type: 'earned')
- ✅ Customer visible in merchant's customer list

**Edge Case: Phone number normalization**
Test with different formats:
- `+973 1234 5678`
- `97312345678`
- `1234-5678`

All should normalize to same customer profile.

---

### Scenario 3: Customer Redeems Points (Return Customer)
**Objective:** Verify customer can use points for discount

**Steps:**
1. Customer has 250 points from previous order
2. Add items to cart (total: ~20 BHD)
3. Open cart
4. Enter same phone number: `+973 1234 5678`
5. Verify current points shown: `250 pts`
6. Verify "You will earn X points" for this order
7. In "Use Your Points" section:
   - Enter points to use: `100`
   - Verify discount shown: `- 2.000 BHD` (100 ÷ 50 = 2)
   - Verify "Points after redemption: 150 pts"
8. Click "MAX" button
   - Verify it uses maximum allowed points based on:
     - Available points: 250
     - Max discount: 10 BHD = 500 points
     - Order total: 20 BHD = 1000 points max
   - Should use min(250, 500, 1000) = 250 points
   - Discount: 5 BHD
9. Set back to 100 points
10. Verify subtotal shows: 20.000 BHD
11. Verify discount shows: - 2.000 BHD
12. Verify final total shows: 18.000 BHD
13. Confirm order
14. Verify points balance updates:
    - Previous: 250 points
    - Redeemed: -100 points
    - Earned from 18 BHD order: +180 points
    - Final: 330 points (250 - 100 + 180)

**Expected Result:**
- ✅ Points balance displays correctly
- ✅ Discount calculation is accurate
- ✅ MAX button calculates correctly
- ✅ Final total accounts for discount
- ✅ Points redeemed successfully
- ✅ New points awarded for final amount (after discount)
- ✅ Customer balance updated correctly

---

### Scenario 4: Minimum Order Amount Validation
**Objective:** Verify minimum order requirement enforced

**Setup:**
- Loyalty settings: Min Order Amount = 5.000 BHD
- Customer has 200 points

**Steps:**
1. Add items to cart (total: 3.000 BHD)
2. Enter phone number
3. Verify points display shows customer has 200 points
4. Verify warning message appears:
   - "Minimum order of BHD 5.000 required to use points"
5. Verify cannot enter points to redeem
6. Add more items to reach 6.000 BHD
7. Verify "Use Your Points" section now appears
8. Redeem points successfully

**Expected Result:**
- ✅ Can't use points on orders below minimum
- ✅ Warning message displays correctly
- ✅ Can use points once minimum is met
- ✅ Still earns points on small orders

---

### Scenario 5: Maximum Discount Validation
**Objective:** Verify maximum discount per order enforced

**Setup:**
- Loyalty settings: Max Discount = 10.000 BHD
- Customer has 1000 points (could get 20 BHD discount)

**Steps:**
1. Add items to cart (total: 50.000 BHD)
2. Enter phone number
3. Verify current points: 1000 pts
4. Try to use all 1000 points
5. Verify system limits to 500 points max
   - Calculation: 10 BHD max discount × 50 pts/BHD = 500 pts max
6. Verify discount capped at: 10.000 BHD
7. Verify final total: 40.000 BHD
8. Confirm order
9. Verify points:
   - Redeemed: -500 points
   - Earned from 40 BHD: +400 points
   - Final: 900 points (1000 - 500 + 400)

**Expected Result:**
- ✅ Points usage capped at max discount
- ✅ Cannot exceed maximum discount
- ✅ Calculations remain accurate
- ✅ Remaining points preserved

---

### Scenario 6: Minimum Points to Redeem
**Objective:** Verify minimum points threshold

**Setup:**
- Loyalty settings: Min Points To Redeem = 50
- Customer has 40 points

**Steps:**
1. Add items to cart (total: 20.000 BHD)
2. Enter phone number
3. Verify current points: 40 pts
4. Verify warning message:
   - "Earn 10 more points to start redeeming"
5. Verify points input field disabled
6. Confirm order (earns 200 points)
7. Now customer has 240 points
8. Place another order
9. Verify can now redeem points

**Expected Result:**
- ✅ Can't redeem below minimum
- ✅ Helpful message shows how many more needed
- ✅ Can redeem once threshold met

---

### Scenario 7: Merchant Changes Settings Mid-Operation
**Objective:** Verify settings changes apply correctly

**Steps:**
1. Merchant changes earn rate from 10 to 20 (double points!)
2. Merchant changes redeem rate from 50 to 100 (points worth less)
3. Save settings
4. Customer places new order (40 BHD)
5. Verify earns 800 points (40 × 20)
6. Customer with 500 points tries to redeem
7. Verify can get 5 BHD discount (500 ÷ 100)

**Expected Result:**
- ✅ New orders use new rates immediately
- ✅ Existing points unaffected
- ✅ Redemption uses current rate
- ✅ No data corruption

---

### Scenario 8: Multiple Customers Same Phone
**Objective:** Verify phone number uniqueness

**Steps:**
1. Customer A orders with phone: `+973 1234 5678`
2. Customer B tries to order with same phone
3. Verify both orders credit same customer profile
4. Verify points accumulate to single profile

**Expected Result:**
- ✅ One profile per phone number
- ✅ Points accumulate correctly
- ✅ Order count tracks all orders

---

### Scenario 9: Disable Loyalty Program
**Objective:** Verify disabling loyalty works

**Steps:**
1. Merchant toggles "Enable Loyalty Program" to OFF
2. Save settings
3. Customer app: Add items to cart
4. Open cart sheet
5. Verify loyalty widget does NOT appear
6. Confirm order successfully (no phone number required)
7. Verify no points awarded
8. Re-enable loyalty program
9. Verify widget appears again

**Expected Result:**
- ✅ Widget hidden when disabled
- ✅ Orders work without phone number
- ✅ No points operations occur
- ✅ Re-enabling restores functionality

---

### Scenario 10: Car Plate Tracking
**Objective:** Verify car plate optional field

**Steps:**
1. Order with phone only (no car plate)
2. Verify profile created without car plate
3. Order again with same phone + car plate
4. Verify car plate added to existing profile
5. Order again with same phone + different car plate
6. Verify car plate updated to latest

**Expected Result:**
- ✅ Car plate is optional
- ✅ Updates on subsequent orders
- ✅ Displayed in merchant customer list

---

### Scenario 11: View Customer List (Merchant)
**Objective:** Verify merchant can view all customers

**Steps:**
1. Merchant app → Loyalty Program → View Customers icon
2. Verify list shows all customers with:
   - Phone number
   - Car plate (if provided)
   - Current points balance
   - Order count
   - Total spent (lifetime)
   - Last order date
3. Verify sorted by most recent order first
4. Create 5+ test customers
5. Verify all appear in list

**Expected Result:**
- ✅ All customers visible
- ✅ Data accurate
- ✅ Sorting correct
- ✅ Real-time updates

---

## 🐛 Edge Cases to Test

### Edge Case 1: Exact Discount Amount
- Order: 10.000 BHD
- Points: 500 (= 10 BHD discount)
- Final total should be 0.000 BHD ✅

### Edge Case 2: Very Large Numbers
- Order: 999.999 BHD (near max)
- Should earn: 9,999 points ✅
- Verify no overflow errors

### Edge Case 3: Decimal Precision
- Order: 12.345 BHD
- Earn rate: 10
- Should earn: 123 points (rounds correctly) ✅
- Redeem 50 points
- Discount: 1.000 BHD (not 1.00) ✅

### Edge Case 4: Rapid Orders
- Place 3 orders quickly with same phone
- Verify points accumulate correctly without race conditions ✅
- Check transaction integrity

### Edge Case 5: Invalid Phone Numbers
- Test with: empty, special characters, very long
- Verify validation/normalization ✅

### Edge Case 6: Zero Points
- Customer with 0 points
- Verify displays correctly
- Verify can't redeem

### Edge Case 7: Network Interruption
- Start order, lose connection, regain connection
- Verify points awarded correctly after reconnect

---

## ✅ Verification Checklist

### Functional Tests
- [ ] Merchant can configure all settings
- [ ] Test calculator works correctly
- [ ] Settings save successfully
- [ ] Customer earns points on first order
- [ ] Customer profile created correctly
- [ ] Points display in cart checkout
- [ ] Discount calculation accurate
- [ ] MAX button works
- [ ] Points redeemed successfully
- [ ] New points awarded after redemption
- [ ] Minimum order validation works
- [ ] Maximum discount validation works
- [ ] Minimum points threshold enforced
- [ ] Phone number normalization works
- [ ] Car plate tracking works
- [ ] Customer list displays correctly
- [ ] Disable/enable loyalty works
- [ ] Real-time updates work

### UI/UX Tests
- [ ] Loyalty widget appears in cart
- [ ] Points balance displays prominently
- [ ] "You will earn" message clear
- [ ] Discount preview accurate
- [ ] Final total calculation visible
- [ ] Warning messages helpful
- [ ] Input validation provides feedback
- [ ] Merchant settings page intuitive
- [ ] Customer list readable
- [ ] Icons and tooltips clear

### Data Integrity Tests
- [ ] Points never go negative
- [ ] Total spent never decreases
- [ ] Order count never decreases
- [ ] Transactions immutable
- [ ] Phone number unique per branch
- [ ] Calculations always 3 decimal places
- [ ] No data loss on errors

### Performance Tests
- [ ] Settings load quickly
- [ ] Customer list loads <2 seconds (100 customers)
- [ ] Points calculation instant
- [ ] Order creation with points <3 seconds
- [ ] Real-time updates < 1 second

### Security Tests
- [ ] Staff can view customer list
- [ ] Non-staff cannot view customers
- [ ] Cannot modify others' points manually
- [ ] Transactions audit trail immutable
- [ ] Firestore rules enforced
- [ ] Phone number privacy maintained

---

## 🚀 Quick Test Script

### 1. Initial Setup (5 min)
```bash
# Terminal 1: Run merchant app
flutter run -d web --target=lib/merchant/main_merchant.dart

# Terminal 2: Run customer app
flutter run -d chrome
```

### 2. Merchant Configuration (2 min)
1. Login to merchant app
2. Products → Loyalty Program icon
3. Verify defaults, test calculator
4. Save settings

### 3. First Customer Order (3 min)
1. Customer app: Add 40 BHD worth of items
2. Cart → Enter phone: `+973 1111 1111`
3. Verify earns 400 points
4. Confirm order

### 4. Redeem Points (3 min)
1. Add 20 BHD worth of items
2. Cart → Same phone
3. Use 100 points (= 2 BHD discount)
4. Verify final total: 18 BHD
5. Confirm order
6. Check balance: should be 330 pts

### 5. Edge Cases (5 min)
1. Test order below minimum (3 BHD)
2. Test order with max points
3. Test disable/enable loyalty
4. Test different phone format
5. View customer list

**Total Time: ~20 minutes for core flow**

---

## 📊 Expected Calculations Reference

### Default Settings
```
Earn Rate: 10 points / BHD
Redeem Rate: 50 points = 1 BHD
Min Order: 5 BHD
Max Discount: 10 BHD
Min Points: 50
```

### Sample Calculations
| Order Amount | Points Earned | With 250 pts, Max Usable | Max Discount |
|--------------|---------------|--------------------------|--------------|
| 3.000 BHD    | 30 points     | 0 (below min)            | 0            |
| 10.000 BHD   | 100 points    | 200 (= 4 BHD)            | 4.000 BHD    |
| 50.000 BHD   | 500 points    | 250 (= 5 BHD)            | 5.000 BHD    |
| 100.000 BHD  | 1000 points   | 250 (= 5 BHD)            | 5.000 BHD    |

### Points Balance Examples
| Scenario | Start | Redeemed | Earned | Final |
|----------|-------|----------|--------|-------|
| First order 40 BHD | 0 | 0 | 400 | 400 |
| Use 100 pts on 20 BHD | 400 | -100 | 180 | 480 |
| Use max on 50 BHD | 480 | -250 | 450 | 680 |

---

## 🐞 Known Limitations

1. **Phone Number Verification:** No SMS verification implemented
2. **Points Expiration:** Points never expire
3. **Fraud Prevention:** No duplicate order detection
4. **Multi-Currency:** Only BHD supported
5. **Transfer Points:** Cannot transfer between customers
6. **Partial Redemption UI:** Must type exact points amount (slider not implemented)

---

## 📝 Bug Reporting Template

If you find issues, report with:

```
**Bug Title:** [Short description]

**Steps to Reproduce:**
1. Step 1
2. Step 2
3. Step 3

**Expected Result:**
What should happen

**Actual Result:**
What actually happened

**Environment:**
- Flutter version:
- Browser/Device:
- Merchant/Customer app:

**Screenshots:**
[Attach if applicable]

**Console Errors:**
[Copy any errors from browser console]
```

---

## ✨ Success Criteria

The loyalty system is working correctly if:
- ✅ Merchants can configure all settings without errors
- ✅ Customers earn points on every order
- ✅ Points calculations are always accurate (3 decimal places)
- ✅ Discounts apply correctly to final total
- ✅ All validation rules enforced (min order, max discount, etc.)
- ✅ Customer profiles track correctly
- ✅ Merchant can view all customers with accurate data
- ✅ System handles edge cases gracefully
- ✅ No data corruption or negative balances
- ✅ Real-time updates work smoothly

---

## 🎓 Testing Tips

1. **Use Browser DevTools:** Open Console to see debug logs
2. **Firestore Console:** Monitor data changes in real-time
3. **Multiple Browsers:** Test customer and merchant simultaneously
4. **Clear Cache:** If seeing stale data, clear browser cache
5. **Check Network Tab:** Verify Firestore queries are efficient
6. **Test on Mobile:** Responsive design important
7. **Use Realistic Data:** Test with actual product prices
8. **Document Issues:** Screenshot and note exact steps to reproduce

---

Good luck testing! 🚀
