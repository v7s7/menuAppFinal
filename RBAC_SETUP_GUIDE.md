# Role-Based Access Control (RBAC) Setup & Testing Guide

## Overview

This merchant dashboard implements strict role-based access control with two roles:
- **ADMIN**: Full access to all features (branding, menu, orders, analytics, user management)
- **STAFF**: Limited access to orders workflow only (accept/serve/cancel orders)

---

## Architecture Summary

### Data Model

**Role Storage Path:**
```
merchants/{merchantId}/branches/{branchId}/roles/{userId}
```

**Role Document Structure:**
```javascript
{
  role: "admin" | "staff",
  email: "user@example.com",
  displayName: "John Doe",
  createdAt: Timestamp,
  createdBy: "creator_uid" // optional
}
```

### Order Audit Logging

When staff/admin updates an order, the following fields are automatically added:
```javascript
{
  updatedByUid: "firebase_auth_uid",
  updatedByRole: "admin" | "staff",
  updatedByEmail: "user@example.com",
  updatedAt: Timestamp
}
```

---

## Initial Setup: Creating Admin and Staff Accounts

### Step 1: Create Firebase Auth Accounts

#### Option A: Using Firebase Console (Recommended for First Admin)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication** → **Users**
4. Click **Add User**
5. Enter email and password:
   - **Admin Example:**
     - Email: `admin@yourstore.com`
     - Password: (set a secure password)
   - **Staff Example:**
     - Email: `staff@yourstore.com`
     - Password: (set a secure password)
6. Click **Add User**
7. **Copy the UID** from the Users table (you'll need this for Step 2)

#### Option B: Using User Management Page (For Subsequent Users)

Once you have one admin account:
1. Log into the merchant dashboard as admin
2. Click **Settings** (gear icon)
3. Go to **User Management** tab
4. Click **Add Staff Member**
5. Enter email, password, display name, and select role
6. Click **Create Account**

This will automatically:
- Create the Firebase Auth account
- Create the role document in Firestore
- Send a welcome notification (if configured)

---

### Step 2: Create Role Documents in Firestore

**IMPORTANT:** Firebase Authentication alone is NOT enough. You must create a role document for each user.

#### Option A: Using Firestore Console (Manual Setup)

1. Go to **Firestore Database** in Firebase Console
2. Navigate to: `merchants/{your_merchant_id}/branches/{your_branch_id}/roles`
3. Click **Add Document**
4. Document ID: Use the **UID from Firebase Auth** (from Step 1)
5. Add fields:

**For Admin:**
```javascript
role: "admin"
email: "admin@yourstore.com"
displayName: "Store Administrator"
createdAt: (Use "Now" from timestamp picker)
```

**For Staff:**
```javascript
role: "staff"
email: "staff@yourstore.com"
displayName: "Store Staff"
createdAt: (Use "Now" from timestamp picker)
```

6. Click **Save**

#### Option B: Using Firebase CLI / Script

Create a script `setup-roles.js`:

```javascript
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

async function setupRole(merchantId, branchId, uid, role, email, displayName) {
  const roleRef = db
    .collection('merchants')
    .doc(merchantId)
    .collection('branches')
    .doc(branchId)
    .collection('roles')
    .doc(uid);

  await roleRef.set({
    role: role, // "admin" or "staff"
    email: email,
    displayName: displayName,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`✅ Created ${role} role for ${email}`);
}

// Usage:
setupRole(
  'your_merchant_id',
  'your_branch_id',
  'firebase_auth_uid_here',
  'admin', // or 'staff'
  'admin@yourstore.com',
  'Store Administrator'
).then(() => console.log('Done'));
```

Run: `node setup-roles.js`

---

## Access Control Matrix

| Feature | Admin | Staff |
|---------|-------|-------|
| **View Orders** | ✅ | ✅ |
| **Update Order Status** (Accept/Serve/Cancel) | ✅ | ✅ |
| **View Order Details** | ✅ | ✅ |
| **View Products/Menu** | ✅ | ❌ |
| **Add/Edit/Delete Menu Items** | ✅ | ❌ |
| **Add/Edit/Delete Categories** | ✅ | ❌ |
| **Change Branding** (Colors, Logo, Title) | ✅ | ❌ |
| **Configure Loyalty Program** | ✅ | ❌ |
| **View Analytics/Reports** | ✅ | ❌ |
| **Manage Staff Accounts** | ✅ | ❌ |
| **View Settings Page** | ✅ | ✅ (limited tabs) |

---

## Testing Procedures

### Test 1: Admin Account - Full Access

1. **Login as Admin:**
   - Navigate to merchant dashboard: `/s/{your_slug}` or `?m={merchantId}&b={branchId}`
   - Login with admin credentials

2. **Verify Full Navigation:**
   - Bottom navigation should show: **Products | Orders | Analytics**
   - All tabs should be accessible

3. **Test Menu Management:**
   - Go to **Products** tab
   - Click **Add Product**
   - Verify you can create/edit/delete products
   - Verify you can manage categories

4. **Test Branding:**
   - Click **Settings** (gear icon)
   - Go to **Branding** tab
   - Change colors, title, or upload logo
   - Verify changes are saved

5. **Test User Management:**
   - In Settings, go to **User Management** tab
   - Verify you can see all staff members
   - Try adding a new staff member
   - Verify the account is created

6. **Test Analytics:**
   - Go to **Analytics** tab
   - Verify you can see sales reports, charts, and metrics

7. **Test Order Management:**
   - Go to **Orders** tab
   - Change an order status (e.g., Pending → Preparing → Ready → Served)
   - Open Firestore Console and check the order document
   - **Verify audit fields are present:**
     ```javascript
     {
       updatedByUid: "admin_uid",
       updatedByRole: "admin",
       updatedByEmail: "admin@yourstore.com",
       updatedAt: Timestamp
     }
     ```

---

### Test 2: Staff Account - Restricted Access

1. **Login as Staff:**
   - Logout from admin account
   - Login with staff credentials

2. **Verify Limited Navigation:**
   - Bottom navigation should show ONLY: **Orders**
   - Products and Analytics tabs should NOT be visible

3. **Test Navigation Blocking:**
   - Try to manually navigate to Products screen (if using deep links)
   - You should see "Access Denied" page or the tab should not exist

4. **Test Order Management:**
   - Go to **Orders** tab
   - Verify you can see all orders
   - Test status changes:
     - Pending → Start Preparing
     - Preparing → Mark Ready
     - Ready → Mark Served
     - Any status → Cancel Order (with reason)
   - **All transitions should work**

5. **Verify Audit Logging:**
   - After changing order status as staff, check Firestore
   - Order document should have:
     ```javascript
     {
       updatedByUid: "staff_uid",
       updatedByRole: "staff",
       updatedByEmail: "staff@yourstore.com",
       updatedAt: Timestamp
     }
     ```

6. **Test Settings Access:**
   - Click **Settings** (gear icon)
   - Staff should see limited settings (e.g., account info, logout)
   - **User Management** tab should NOT be visible
   - **Branding** and **Loyalty** tabs should NOT be editable (or hidden)

7. **Test Menu Blocking (Security Check):**
   - Try to access menu data via direct Firestore queries (if you have access)
   - Staff should be able to READ menu items (for order display)
   - Staff should NOT be able to WRITE/UPDATE/DELETE menu items
   - Firestore security rules will block unauthorized writes

---

### Test 3: No Role Account - Access Denied

1. **Create Firebase Auth Account Without Role:**
   - In Firebase Console, add a new user: `norole@yourstore.com`
   - Do NOT create a role document in Firestore

2. **Login Attempt:**
   - Try to login with this account
   - You should see: **"No access to this merchant"** message
   - A "Sign Out" button should be visible

3. **Verify:**
   - No access to any dashboard features
   - User must contact admin to be granted a role

---

### Test 4: Firestore Security Rules Enforcement

#### Test Invalid Order Updates by Staff

1. **Login as Staff**
2. Open browser DevTools → Console
3. Try to modify order items directly via Firestore SDK:

```javascript
// This should FAIL with permission denied
firebase.firestore()
  .doc('merchants/demo_merchant/branches/dev_branch/orders/{orderId}')
  .update({
    items: [], // Trying to delete items
    subtotal: 999.999 // Trying to change total
  });
```

**Expected Result:** Firestore permission denied error

4. Try valid status update:

```javascript
// This should SUCCEED
firebase.firestore()
  .doc('merchants/demo_merchant/branches/dev_branch/orders/{orderId}')
  .update({
    status: 'ready',
    readyAt: firebase.firestore.FieldValue.serverTimestamp(),
    updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    updatedByUid: firebase.auth().currentUser.uid,
    updatedByRole: 'staff'
  });
```

**Expected Result:** Update succeeds

#### Test Menu Updates by Staff

1. **Login as Staff**
2. Try to update a menu item:

```javascript
// This should FAIL
firebase.firestore()
  .doc('merchants/demo_merchant/branches/dev_branch/menuItems/{itemId}')
  .update({
    price: 0.001
  });
```

**Expected Result:** Firestore permission denied error

3. **Login as Admin and retry** → should succeed

---

### Test 5: Invalid Status Transitions (Security Check)

Firestore rules enforce valid status transitions. Test these scenarios:

#### Valid Transitions (Should Succeed)
- `pending` → `accepted` ✅
- `pending` → `preparing` ✅
- `pending` → `cancelled` ✅
- `accepted` → `preparing` ✅
- `accepted` → `cancelled` ✅
- `preparing` → `ready` ✅
- `preparing` → `cancelled` ✅
- `ready` → `served` ✅
- `ready` → `cancelled` ✅

#### Invalid Transitions (Should Fail)
- `served` → `ready` ❌ (Terminal state)
- `cancelled` → `pending` ❌ (Terminal state)
- `ready` → `pending` ❌ (Cannot go backwards)
- `preparing` → `served` ❌ (Must go through `ready`)

Test by attempting these transitions via the UI or Firestore Console.

---

## Troubleshooting

### Issue: "No access to this merchant" after login

**Causes:**
1. No role document exists in Firestore
2. Role document path is incorrect (wrong merchantId or branchId)
3. Firestore security rules blocking role read

**Solutions:**
1. Verify role document exists: `merchants/{m}/branches/{b}/roles/{uid}`
2. Check that `uid` matches Firebase Auth UID exactly
3. Ensure Firestore rules allow role document reads
4. Check browser console for specific Firestore errors

---

### Issue: Staff can see Products/Analytics tabs

**Causes:**
1. Role document has `role: "admin"` instead of `role: "staff"`
2. Role provider not loading correctly
3. Cache issue in Riverpod state

**Solutions:**
1. Verify role document in Firestore has `role: "staff"` (lowercase)
2. Logout and login again
3. Clear browser cache / hard refresh
4. Check browser console for role provider errors

---

### Issue: Order status update fails with permission denied

**Causes:**
1. Firestore security rules are too strict
2. Missing required audit fields (`updatedByUid`)
3. Invalid status transition
4. User doesn't have staff/admin role

**Solutions:**
1. Check Firestore rules simulator in Firebase Console
2. Verify audit fields are being sent in the update
3. Ensure transition is valid (see valid transitions table)
4. Verify user has a role document with `role: "staff"` or `role: "admin"`

---

### Issue: Changes to Firestore rules not taking effect

**Causes:**
- Rules not deployed

**Solutions:**
1. If using Firebase CLI: Run `firebase deploy --only firestore:rules`
2. If using Firebase Console: Save and publish the rules
3. Wait 1-2 minutes for rules to propagate
4. Test in an incognito window to avoid caching

---

## Security Best Practices

1. **Never use default/demo merchant IDs in production**
   - Change `demo_merchant` and `dev_branch` to real IDs

2. **Use strong passwords for all accounts**
   - Minimum 12 characters with mixed case, numbers, symbols

3. **Regularly audit role documents**
   - Review who has admin access monthly
   - Remove role documents for terminated employees immediately

4. **Monitor Firestore audit logs**
   - Check `updatedByUid` and `updatedByRole` fields in orders
   - Investigate any suspicious activity

5. **Test security rules regularly**
   - Use Firebase Rules Simulator
   - Attempt unauthorized operations to verify blocking

6. **Enable multi-factor authentication (MFA)**
   - Configure in Firebase Auth settings
   - Require for all admin accounts

---

## Support

If you encounter issues:
1. Check browser console for errors
2. Verify Firestore security rules are deployed
3. Confirm role document exists with correct structure
4. Test in Firebase Console directly to isolate issues
5. Review recent commits to identify breaking changes

---

## Summary Checklist

Before going live:

- [ ] All admin accounts created in Firebase Auth
- [ ] All staff accounts created in Firebase Auth
- [ ] Role documents created for all users in Firestore
- [ ] Firestore security rules deployed
- [ ] Tested admin full access
- [ ] Tested staff restricted access
- [ ] Tested "no role" account shows access denied
- [ ] Verified audit logging on order updates
- [ ] Tested invalid status transitions are blocked
- [ ] Tested menu updates blocked for staff
- [ ] Changed demo merchant/branch IDs to production values
- [ ] Enabled MFA for admin accounts
- [ ] Documented all account credentials securely

---

**Last Updated:** 2025-12-30
**Version:** 1.0
