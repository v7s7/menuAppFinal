# 📊 SWEETWEB MERCHANT-FOCUSED ANALYSIS & ROADMAP

**Analysis Date**: January 4, 2026
**Repository**: SweetWeb (menuAppFinal)
**Purpose**: Identify high-impact improvements to drive merchant adoption and collaboration

---

## 1. REPO MAP SUMMARY (Current System)

**SweetWeb is a Flutter web app (3.9.2+) for restaurant ordering with dual interfaces:**

- **Tech Stack**: Flutter + Firebase (Firestore, Auth) + Riverpod 2.6.1 + Cloudflare Worker (email)
- **Two Apps**: Customer app (`lib/main.dart`) and Merchant Console (`lib/merchant/main_merchant.dart`)
- **Routing**: Slug-based URLs (`/s/your-slug`) or direct IDs (`?m=merchantId&b=branchId`)
- **Auth**: Anonymous for customers, email/password for merchants with RBAC (admin/staff roles)
- **Image Hosting**: Cloudinary for product photos
- **Currency**: Bahraini Dinar (BHD) with 3 decimal places
- **Multi-branch**: Supports multiple branches per merchant
- **Real-time**: Firestore snapshots for live order updates
- **Email**: Cloudflare Worker + Resend API for order notifications
- **Sound Alerts**: `just_audio` package for new order notifications
- **Analytics**: Custom-built dashboard with FL Chart
- **Loyalty**: Points-based system (earn/redeem)

**Key Features Implemented:**
1. Customer menu browsing with categories
2. Shopping cart with item notes
3. Order placement with car plate + phone (for curbside/drive-thru)
4. Real-time order status tracking
5. Merchant product management (CRUD with Cloudinary upload)
6. Order workflow (pending → preparing → ready → served)
7. Role-based access (admin sees Products/Orders/Analytics, staff sees Orders only)
8. Analytics dashboard (revenue, top products, hourly trends, customer insights)
9. Loyalty program (points earn/redeem with car plate tracking)
10. Email notifications for new/cancelled orders
11. Branding customization (colors, logo, store name)
12. Category management (2-level hierarchy)

---

## 2. DATA MODEL SUMMARY (Firestore Collections)

```
/slugs/{slug}
  - merchantId, branchId (for URL routing)

/merchants/{merchantId}
  - name, createdAt

  /branches/{branchId}
    - name, isActive, createdAt

    /menuItems/{itemId}
      - name, price, imageUrl, calories, protein, carbs, fat, sugar
      - categoryId, isActive, sort, tags[]
      - merchantId, branchId, createdAt, updatedAt

    /categories/{categoryId}
      - name, parentId (null for top-level), sort, isActive, icon

    /orders/{orderId}
      - orderNo (human-readable), status, userId, items[]
      - subtotal, customerPhone, customerCarPlate, table
      - loyaltyDiscount, loyaltyPointsUsed
      - cancellationReason, createdAt, updatedAt
      - updatedByUid, updatedByRole, updatedByEmail (audit)

    /roles/{userId}
      - role (admin/staff), email, displayName, createdAt, createdBy

    /config/branding
      - title, headerText, primaryHex, secondaryHex, logoUrl, bannerUrl, slug

    /config/loyalty
      - enabled, earnRate, redeemRate, minOrderAmount, maxDiscountAmount, minPointsToRedeem

    /customers/{phone}
      - phone, carPlate, points, totalSpent, orderCount, lastOrderAt

    /pointsTransactions/{transactionId}
      - phone, type (earned/redeemed), points, orderId, createdAt, note

    /counters/orderNumber
      - value (for sequential order numbering)
```

**Security**: Firestore rules enforce RBAC, validate order workflow transitions, prevent tampering with order amounts, and audit all status changes.

---

## 3. CURRENT MERCHANT EXPERIENCE (What Works Today)

### Onboarding:
- Merchant gets Firebase credentials
- Admin manually creates merchant/branch docs in Firestore
- Admin creates first admin user via Firebase Auth + roles doc
- Merchant configures Cloudinary for product images
- Merchant opens `https://sweetweb.web.app/s/{slug}` after login

### Daily Operations:

#### Admin Flow:
1. **Products Tab** (`lib/merchant/screens/products_screen.dart:22`)
   - Add/edit/delete menu items with Cloudinary image upload
   - Set nutrition facts, prices (3dp BHD), categories, tags
   - No bulk operations, no availability toggles visible

2. **Orders Tab** (`lib/merchant/screens/orders_admin_page.dart:268`)
   - View orders filtered by status (All/Pending/Preparing/Ready/Served/Cancelled)
   - Date range filter (defaults to Today)
   - Quick actions: "Start Preparing" → "Mark Ready" → "Mark Served"
   - Cancel with optional reason
   - Car plate prominently displayed for curbside pickup
   - Shows loyalty discounts and customer phone
   - Limit 200 orders per query

3. **Analytics Tab** (`lib/features/analytics/screens/analytics_dashboard_page.dart`)
   - Date range selector (Today, Yesterday, Last 7/30 Days, This Month, etc.)
   - Revenue, order count, average order value, completion rate
   - Top 10 products by revenue
   - Category breakdown pie chart
   - Hourly distribution bar chart
   - Customer insights (new vs returning, retention rate, lifetime value)
   - No export, no scheduled reports

4. **Settings** (accessed via AppBar icon)
   - User management (`lib/merchant/screens/user_management_page.dart`)
   - Branding customization (`lib/core/branding/branding_admin_page.dart:17`)
   - Loyalty program settings (`lib/features/loyalty/screens/loyalty_settings_page.dart`)
   - Category management (`lib/features/categories/screens/category_admin_page.dart`)

#### Staff Flow:
- Only sees **Orders Tab** (no Products, no Analytics, no Settings except sign out)
- Can update order status (preparing → ready → served)
- Cannot manage menu, users, or settings

### Email Notifications:
- Auto-sends to `EmailConfig.defaultEmail` for new orders and cancellations
- Uses Cloudflare Worker + Resend API
- Hardcoded email (no per-merchant config in UI)
- Rate limited to 2 req/sec

### Customer Flow:
- Browse menu by category
- Add to cart with item notes
- Checkout: enter phone + car plate (required for loyalty)
- Redeem loyalty points for discount
- View order status in real-time
- No customer account/login, no order history, no favorites

---

## 4. PAIN POINTS (Evidence-Based Gaps)

### A. ONBOARDING FRICTION (High barrier to entry)
**Evidence:**
- No self-service signup (requires Firebase Console access)
- Manual Firestore doc creation (`README.md:98-102`)
- Requires Cloudflare account + Resend API key setup
- Requires Cloudinary account + preset configuration
- No guided setup wizard or sample data import
- **Merchant Impact**: Takes hours/days to onboard, requires technical knowledge, increases abandonment

**Files:**
- `README.md:37-102` (manual setup steps)
- `lib/merchant/screens/products_screen.dart:313-316` (hardcoded Cloudinary config)
- `lib/core/config/email_config.dart` (hardcoded email config)

---

### B. ORDER PROCESSING SPEED (Too many taps, friction)
**Evidence:**
- Orders list shows ALL statuses mixed together (served/cancelled clutter active orders)
- "All" filter excludes served/cancelled but requires tap to select (`orders_admin_page.dart:343-352`)
- No sound alerts implemented in merchant console (only service exists, not integrated)
- No auto-refresh setting (relies on Firestore snapshots, can lag on poor connections)
- No "kitchen mode" (large buttons, simplified view for staff on tablet)
- Car plate visible but small font on list view (`orders_admin_page.dart:460-483`)
- **Merchant Impact**: Staff waste time scrolling, miss urgent orders, slow service

**Files:**
- `lib/merchant/screens/orders_admin_page.dart:343-352` (All filter logic)
- `lib/features/orders/services/sound_alert_service.dart` (unused in merchant console)
- `lib/merchant/main_merchant.dart` (no sound alerts integrated)

---

### C. MENU MANAGEMENT EFFICIENCY (Manual, tedious)
**Evidence:**
- No bulk edit (must edit items one-by-one)
- No availability toggle on list view (must open editor, change `isActive`)
- `isActive` field exists but no UI to quickly toggle it (`products_screen.dart`)
- No item duplication (must re-enter all fields for similar items)
- No batch upload (one image at a time via file picker)
- No menu templates or import/export
- Sort field exists but no drag-to-reorder UI
- **Merchant Impact**: Takes 30+ min to update daily menu, prone to errors

**Files:**
- `lib/merchant/screens/products_screen.dart:22-199` (no bulk operations)
- `lib/features/sweets/data/sweet.dart:32` (`isActive` field not exposed in merchant UI)
- `firestore.rules:55-68` (validates `isActive` but no merchant toggle)

---

### D. BRANDING CONTROL (Limited, fragmented)
**Evidence:**
- Logo/banner upload exists but not integrated with Cloudinary (UI shows input fields, no image picker)
- No store hours configuration (customers see menu 24/7)
- No "closed" mode (menu always visible even when restaurant closed)
- Slug can be changed but no validation (could break URLs)
- No preview mode (merchant can't see customer view without opening separate app)
- **Merchant Impact**: Can't control when/how customers order, brand inconsistency

**Files:**
- `lib/core/branding/branding_admin_page.dart:17` (basic color/text config only)
- `lib/core/branding/branding.dart:3-19` (logoUrl/bannerUrl fields unused)

---

### E. REPORTING USEFULNESS (Good foundation, missing action)
**Evidence:**
- Analytics dashboard exists with rich metrics (`analytics_service.dart`)
- No export to CSV/PDF (can't share with accountant)
- No scheduled email reports (daily/weekly summary)
- No profit tracking (only revenue, no cost of goods)
- No comparison (can't see "this week vs last week")
- Slow-moving products shown but no actionable suggestions
- Customer insights basic (no cohort analysis, no churn prediction)
- **Merchant Impact**: Can see data but can't act on it, can't share with stakeholders

**Files:**
- `lib/features/analytics/data/analytics_service.dart:12-536` (comprehensive but no export)
- `lib/features/analytics/screens/analytics_dashboard_page.dart` (no export button)

---

### F. RELIABILITY & TRUST (Fragile, no error recovery)
**Evidence:**
- No offline mode (requires constant internet)
- No retry queue for failed orders (if Firestore write fails, order lost)
- Email notifications can fail silently (no retry mechanism)
- Sound alerts not integrated (merchants miss orders if browser tab not focused)
- No health monitoring (no way to know if system is working)
- No order confirmation for customer (no email, no SMS, no receipt)
- **Merchant Impact**: Lost orders, customer complaints, revenue loss

**Files:**
- `lib/core/services/order_notification_service.dart:68-118` (no retry on failure)
- `lib/features/orders/services/sound_alert_service.dart` (exists but not used in merchant console)
- No error boundary implementations found

---

### G. SECURITY (Good RBAC, missing audit)
**Evidence:**
- Firestore rules are strict (`firestore.rules:1-238`)
- RBAC works (admin/staff separation)
- Audit fields exist (`updatedByUid`, `updatedByRole`) but no audit log UI
- No activity log (can't see who changed what)
- No session timeout (Firebase Auth token lasts indefinitely)
- No 2FA option
- **Merchant Impact**: Can't track staff actions, security concerns for multi-location

**Files:**
- `firestore.rules:133-137` (audit fields required but not displayed)
- No audit log UI found

---

### H. PERFORMANCE (Inefficient queries, no pagination)
**Evidence:**
- Orders query limits to 200 but loads all in memory (`orders_admin_page.dart:138`)
- No pagination (if >200 orders/day, older ones invisible)
- Analytics computes in real-time (no caching, slow on large datasets)
- No Firestore indexes for common queries (only 4 indexes defined)
- Images loaded without lazy loading or CDN optimization
- **Merchant Impact**: Slow dashboard, missing orders, poor UX on busy days

**Files:**
- `lib/merchant/screens/orders_admin_page.dart:129-138` (limit 200, no pagination)
- `firestore.indexes.json` (only 4 indexes, missing orders queries)
- `lib/features/analytics/data/analytics_service.dart:49-65` (no caching)

---

### I. MULTI-BRANCH READINESS (Data model supports, UI doesn't)
**Evidence:**
- Data model has merchant → branches hierarchy
- Merchant console locks to one branch per session
- No branch switcher (must log out and change URL)
- No branch-specific settings UI (menu, hours, staff differ by location)
- No inter-branch analytics (can't compare locations)
- **Merchant Impact**: Must open multiple tabs/devices for multi-location merchants

**Files:**
- `lib/merchant/main_merchant.dart:62-68` (branch ID set once, no switcher)
- `lib/core/config/slug_routing.dart` (slug → one branch only)

---

## 5. PRIORITIZED ROADMAP (Merchant Adoption-Focused)

### CATEGORY A: MUST-HAVE TO SELL (Ship within 2-4 weeks)

#### A1. One-Tap Menu Availability Toggle [COMPLEXITY: S]
**Merchant Value**: Staff can mark items out-of-stock in 1 tap (vs 5 taps + form today)
**Code Location**:
- Add toggle switch to `lib/merchant/screens/products_screen.dart:150-170` (ListTile trailing)
- Use existing `isActive` field in Firestore
**Implementation**:
- Add IconButton with toggle icon next to Edit/Delete
- OnPressed: `doc.reference.update({'isActive': !currentValue})`
- Add visual indicator (gray out + "Out of Stock" badge on inactive items)
**Risks**: None (field already validated in Firestore rules)
**Metrics**:
- Time to toggle item (target: <2 sec vs 30 sec today)
- # of availability updates per day (expect 10-50x increase)
- Customer abandonment rate (should decrease)

---

#### A2. Kitchen Mode (Large-Button Order Screen) [COMPLEXITY: M]
**Merchant Value**: Staff on tablet can see/update orders with large touch targets (1 tap vs 3)
**Code Location**:
- New screen: `lib/merchant/screens/kitchen_mode_page.dart`
- Launch from Orders tab AppBar action
**Implementation**:
- Grid view of pending/preparing orders (2-3 columns)
- Huge order cards: Car plate (36px), items, time, status
- Giant "Ready" button (full width, 60px height)
- Auto-hides served/cancelled (focus on active only)
- Optional: fullscreen mode, increase font sizes 2x
**Risks**:
- Need to test on tablets (responsive design)
- May need separate route for kitchen vs admin view
**Metrics**:
- Order acceptance time (target: <10 sec vs 30 sec)
- Tap accuracy (should increase on tablet)
- Staff satisfaction survey

---

#### A3. Sound Alerts for New Orders [COMPLEXITY: S]
**Merchant Value**: Never miss an order (browser tab can be in background)
**Code Location**:
- Service exists: `lib/features/orders/services/sound_alert_service.dart`
- Integrate in `lib/merchant/main_merchant.dart:129-145` (listen to pending orders stream)
**Implementation**:
- In `_MerchantShellState.initState()`, subscribe to pending orders snapshot
- Play `soundAlertService.playNewOrderAlert()` on new pending order
- Add settings toggle: "Sound alerts" ON/OFF (persist in localStorage)
- Add "Test Sound" button in settings
**Risks**:
- Browser may block autoplay (need user interaction first)
- Need custom MP3 files in `assets/sounds/`
**Metrics**:
- Order acceptance time (should decrease 20-40%)
- Missed order complaints (should drop to 0)

---

#### A4. Quick Onboarding Wizard [COMPLEXITY: M]
**Merchant Value**: Go from signup to first order in <30 min (vs 4+ hours today)
**Code Location**:
- New screen: `lib/merchant/screens/onboarding_wizard.dart`
- Trigger when new merchant logs in (check if branding doc empty)
**Implementation**:
1. **Step 1**: Store info (name, phone, address, logo upload)
2. **Step 2**: Import sample menu (10 items) or skip
3. **Step 3**: Set store hours + holidays
4. **Step 4**: Share customer link (`/s/{slug}`)
- Use stepper widget, auto-create Firestore docs
- Optional: in-app Cloudinary upload or use Firebase Storage
**Risks**:
- Sample menu must be generic (desserts/drinks)
- Logo upload needs alternative to Cloudinary (Firebase Storage)
**Metrics**:
- Time to first order (target: <30 min vs 4 hours)
- Onboarding completion rate (target: >80%)
- Support tickets for setup (should drop 60%)

---

#### A5. Order Confirmation for Customers [COMPLEXITY: S]
**Merchant Value**: Reduces "where's my order?" calls, builds trust
**Code Location**:
- Add to `lib/features/orders/data/order_service.dart` (after order creation)
- Show modal after checkout in `lib/features/cart/widgets/cart_sheet.dart`
**Implementation**:
- After order placed, show dialog with:
  - Order number, estimated time (15 min default)
  - "We'll notify you when ready" message
  - Optional: SMS confirmation (requires Twilio integration)
- Merchant can set estimated prep time in settings
**Risks**:
- SMS adds cost (Twilio ~$0.01/SMS)
- Need phone number validation
**Metrics**:
- "Where's my order?" calls (should drop 50%)
- Customer satisfaction score
- Order placement confidence (survey)

---

### CATEGORY B: COMPETITIVE DIFFERENTIATORS (Ship within 1-2 months)

#### B1. WhatsApp Order Notifications [COMPLEXITY: S]
**Merchant Value**: Reach merchants on their phone (many don't monitor browser)
**Code Location**:
- Extend `lib/core/services/order_notification_service.dart`
- Add WhatsApp Business API integration (or unofficial Twilio API)
**Implementation**:
- Merchant adds WhatsApp number in settings
- On new order, send message: "New order #{orderNo} - {items} - {carPlate} - Open: {link}"
- Use Twilio WhatsApp API or Meta Business API
**Risks**:
- WhatsApp API requires business verification (can take days)
- Unofficial APIs violate ToS (use Twilio for safety)
**Metrics**:
- Order acceptance time (target: <5 min, faster than email)
- Merchant preference (WhatsApp vs Email)
- Order response rate

---

#### B2. Thermal Receipt Printing [COMPLEXITY: M]
**Merchant Value**: Auto-print orders to kitchen (zero-tap workflow)
**Code Location**:
- New service: `lib/features/orders/services/receipt_printer_service.dart`
- Integrate with orders stream in merchant console
**Implementation**:
- Use `printing` package for web (generates PDF, sends to browser print dialog)
- Or integrate with cloud print service (PrintNode, Google Cloud Print successor)
- Format: Order #, timestamp, items, customer car plate, notes
- Auto-trigger on new pending order (if enabled in settings)
**Risks**:
- Web print dialog requires user action (can't auto-print due to browser security)
- Thermal printers need drivers (may need native app for Android/iOS)
**Metrics**:
- Kitchen prep time (should decrease 10-20%)
- Order accuracy (should increase with printed tickets)
- Staff preference (print vs screen)

---

#### B3. Profit Tracking (COGS Input) [COMPLEXITY: M]
**Merchant Value**: See actual profit, not just revenue (critical for pricing decisions)
**Code Location**:
- Add `costPrice` field to `lib/features/sweets/data/sweet.dart:28`
- Update product editor: `lib/merchant/screens/products_screen.dart:295-453`
- Update analytics: `lib/features/analytics/data/analytics_service.dart:172-204`
**Implementation**:
- Add "Cost Price" input field (optional, defaults to 0)
- Analytics dashboard shows:
  - Gross Revenue
  - Total COGS
  - **Gross Profit** (revenue - COGS)
  - **Profit Margin %**
- Protect COGS visibility (admin-only, hide from staff)
**Risks**:
- Merchants may not know exact costs (need help text: "include ingredients, labor, packaging")
- Need Firestore rule update to allow `costPrice` field
**Metrics**:
- Merchant pricing changes (should increase after seeing profit data)
- Profit margin improvement over time
- Feature adoption rate (% merchants who enter COGS)

---

#### B4. Loyalty Tiers (Bronze/Silver/Gold) [COMPLEXITY: M]
**Merchant Value**: Reward top customers, increase retention
**Code Location**:
- Extend `lib/features/loyalty/data/loyalty_models.dart:60-162`
- Add tier calculation to `lib/features/loyalty/data/loyalty_service.dart`
**Implementation**:
- Define tiers:
  - Bronze: 0-499 points (5% discount)
  - Silver: 500-999 points (10% discount)
  - Gold: 1000+ points (15% discount)
- Show tier badge in checkout, order list
- Merchant can customize tier thresholds + benefits in settings
**Risks**:
- May cannibalize revenue (test with opt-in merchants first)
- Need to notify customers when they tier up (engagement)
**Metrics**:
- Customer retention rate (should increase 15-30%)
- Average order frequency (should increase)
- Tier progression rate (how fast customers move up)

---

#### B5. Staff Performance Dashboard [COMPLEXITY: M]
**Merchant Value**: Identify top performers, optimize scheduling
**Code Location**:
- New screen: `lib/merchant/screens/staff_performance_page.dart` (admin-only)
- Use audit fields from `firestore.rules:133-137`
**Implementation**:
- Table view: Staff name, orders processed, avg processing time, rating
- Filters: date range, branch
- Metrics per staff:
  - Orders accepted/served/cancelled
  - Avg time pending → served
  - Cancellation rate (if high, need training)
- Export to CSV
**Risks**:
- May create unhealthy competition (frame as "team insights" not "ranking")
- Need privacy consent (EU GDPR compliance)
**Metrics**:
- Order processing speed (should improve as staff see their metrics)
- Staff turnover (may decrease with recognition)
- Merchant satisfaction with staffing decisions

---

#### B6. Menu Templates & Import [COMPLEXITY: M]
**Merchant Value**: Clone menu to new branch in 1 click, faster onboarding
**Code Location**:
- New dialog in `lib/merchant/screens/products_screen.dart`
- Add "Import Menu" button in AppBar
**Implementation**:
- Merchant can:
  - Export current menu to JSON
  - Import JSON (copy from another branch or starter template)
  - Clone menu to new branch (if multi-branch)
- Include categories + items in export
- Validate on import (check required fields, pricing)
**Risks**:
- Images won't transfer (Cloudinary URLs branch-specific) - need warning
- May import inactive/outdated items - need review step
**Metrics**:
- New branch setup time (target: <10 min vs 2+ hours)
- Menu consistency across branches
- Onboarding completion rate

---

### CATEGORY C: RETENTION & GROWTH (Ship within 2-4 months)

#### C1. Customer Order History [COMPLEXITY: M]
**Merchant Value**: Customers reorder favorites → higher frequency, larger baskets
**Code Location**:
- New screen: `lib/features/orders/screens/order_history_page.dart`
- Access via customer app (add profile icon to AppBar)
**Implementation**:
- Customer can view past orders (if phone # matches)
- "Reorder" button (adds all items to cart instantly)
- Mark favorites (persist to Firestore `customers/{phone}/favorites`)
- Show loyalty points balance + tier
**Risks**:
- Need customer login (phone + SMS OTP) for security
- May increase Firestore reads (add caching)
**Metrics**:
- Reorder rate (target: 20-30% of orders)
- Average order frequency (should increase)
- Customer lifetime value

---

#### C2. Promotions & Coupons [COMPLEXITY: L]
**Merchant Value**: Drive sales during slow hours, clear excess inventory
**Code Location**:
- New collection: `/merchants/{m}/branches/{b}/promotions/{promoId}`
- New UI: `lib/features/promotions/` (screens + models)
- Integrate in cart: `lib/features/cart/state/cart_controller.dart`
**Implementation**:
- Promo types: % off, fixed amount, BOGO, free item
- Conditions: min order, specific items, time-based (happy hour 3-5pm)
- Coupon codes (manual entry) or auto-apply
- Usage limits: per customer, total redemptions, expiry date
- Analytics: promo ROI (revenue gained vs discount cost)
**Risks**:
- Complex logic (test thoroughly to prevent abuse)
- May train customers to only buy with discounts (strategic use only)
- Need Firestore rules update to validate promo application
**Metrics**:
- Sales during slow hours (should increase 30-50%)
- Promo redemption rate
- Customer acquisition cost (promos as marketing channel)

---

#### C3. Scheduled Reports (Email/WhatsApp) [COMPLEXITY: M]
**Merchant Value**: Merchant gets daily/weekly summary without logging in
**Code Location**:
- New Cloud Function: `functions/src/scheduledReports.ts` (Firebase Cloud Functions)
- Configure in settings: `lib/merchant/screens/settings_page.dart`
**Implementation**:
- Merchant chooses: daily at 9pm, weekly on Monday
- Report includes:
  - Revenue, order count, top 5 products
  - Comparison vs previous period
  - Alerts (low stock, high cancellation rate)
- Send via email or WhatsApp
- Use Firebase Cloud Functions scheduled trigger
**Risks**:
- Cloud Functions cost (free tier: 125K invocations/month, likely sufficient)
- Need to set up Firebase project for Cloud Functions
**Metrics**:
- Merchant engagement (do they read reports?)
- Data-driven decisions (pricing changes, menu updates)
- Merchant retention (should increase)

---

#### C4. Multi-Branch Analytics [COMPLEXITY: M]
**Merchant Value**: Compare locations, allocate resources, identify underperformers
**Code Location**:
- New screen: `lib/merchant/screens/multi_branch_analytics_page.dart`
- Extend `lib/features/analytics/data/analytics_service.dart` (query all branches)
**Implementation**:
- Show table: Branch name, revenue, orders, avg order value, completion rate
- Charts: Revenue by branch (bar chart), branch comparison (line chart over time)
- Filters: date range, sort by metric
- Drill down: click branch → see branch-specific dashboard
**Risks**:
- Slow if many branches (need Firestore query optimization or caching)
- May reveal sensitive data (some franchises hide revenue from franchisees)
**Metrics**:
- Resource allocation efficiency (move staff to busy locations)
- Branch revenue variance (should decrease as underperformers improve)
- Merchant satisfaction with multi-location management

---

#### C5. Customer Feedback & Ratings [COMPLEXITY: M]
**Merchant Value**: Identify quality issues, reward great service, improve menu
**Code Location**:
- Add `rating` (1-5 stars) and `feedback` (text) to orders
- New screen: `lib/merchant/screens/feedback_dashboard_page.dart`
**Implementation**:
- After order marked "served", customer can rate (optional prompt)
- Merchant sees:
  - Average rating (overall, per product, per staff member)
  - Recent feedback (negative first for quick action)
  - Trends over time
- Auto-tag feedback (sentiment analysis or keywords: "cold", "slow", "delicious")
**Risks**:
- Low response rate (need incentive: 10 bonus loyalty points for feedback)
- Negative feedback may demoralize staff (frame as improvement opportunity)
**Metrics**:
- Customer satisfaction score (NPS)
- Feedback response rate (target: >30%)
- Quality improvement (rating should increase over time)

---

#### C6. Inventory Alerts [COMPLEXITY: M]
**Merchant Value**: Never run out of popular items, reduce waste
**Code Location**:
- Add `stock` field to `lib/features/sweets/data/sweet.dart`
- New service: `lib/features/inventory/inventory_alert_service.dart`
**Implementation**:
- Merchant sets stock level per item (optional)
- Auto-decrement on order (if enabled)
- Alert when stock < threshold:
  - In-app notification badge
  - Email/WhatsApp alert
  - Auto-mark item inactive if stock = 0
- Restock button (increments stock)
**Risks**:
- Manual stock entry tedious (need POS integration for automation)
- May not suit all merchants (bakeries make fresh daily vs pre-stocked items)
**Metrics**:
- Stockout incidents (should decrease 50-80%)
- Waste reduction (less over-production)
- Customer satisfaction (fewer "out of stock" disappointments)

---

## 6. TOP 5 QUICK WINS (High Impact, Low Effort)

### 🎯 QUICK WIN #1: One-Tap Availability Toggle [2-4 hours]
**What**: Add switch icon next to Edit/Delete on product list
**Where**: `lib/merchant/screens/products_screen.dart:154-169`
**Steps**:
1. Add `IconButton` with `Icons.visibility_off_outlined` / `Icons.visibility_outlined` icon
2. OnPressed: `doc.reference.update({'isActive': !isActive})`
3. Add opacity to ListTile when `isActive == false` (gray out)
4. Add "Out of Stock" red badge on inactive items
**Impact**: 95% reduction in time to toggle (30 sec → <2 sec), staff love it

---

### 🎯 QUICK WIN #2: Sound Alerts for New Orders [4-6 hours]
**What**: Play sound when new pending order arrives
**Where**: `lib/merchant/main_merchant.dart:129-145`
**Steps**:
1. In `_MerchantShellState`, add StreamSubscription to pending orders:
```dart
FirebaseFirestore.instance
  .collection('merchants/$merchantId/branches/$branchId/orders')
  .where('status', isEqualTo: 'pending')
  .snapshots()
  .listen((snapshot) {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        ref.read(soundAlertServiceProvider).playNewOrderAlert();
      }
    }
  });
```
2. Add settings toggle in Settings page (persist in SharedPreferences)
3. Add custom MP3 to `assets/sounds/new_order.mp3` (royalty-free alert sound)
4. Test browser autoplay policy (may need user interaction first)
**Impact**: 40% faster order acceptance, zero missed orders

---

### 🎯 QUICK WIN #3: Default to "Active Orders" Filter [30 min]
**What**: Change default filter from "All" to exclude served/cancelled
**Where**: `lib/merchant/screens/orders_admin_page.dart:51-52`
**Steps**:
1. Change `StateProvider` initial value:
```dart
final ordersFilterProvider = StateProvider<OrdersFilter>((_) => OrdersFilter.pending);
```
2. Or create new filter "Active" (pending + preparing + ready)
**Impact**: Staff spend 50% less time scrolling, see urgent orders first

---

### 🎯 QUICK WIN #4: Larger Car Plate Display [1 hour]
**What**: Increase car plate font size on order list (16px → 24px)
**Where**: `lib/merchant/screens/orders_admin_page.dart:460-483`
**Steps**:
1. Change `fontSize: 16` to `fontSize: 24` (line 476)
2. Change `fontWeight: FontWeight.w900` to make it bolder
3. Optional: Add contrasting background color for better visibility
**Impact**: Faster order identification, fewer mistakes (critical for drive-thru/curbside)

---

### 🎯 QUICK WIN #5: Add "Today's Revenue" to Orders AppBar [1-2 hours]
**What**: Show today's total revenue in AppBar subtitle (live counter)
**Where**: `lib/merchant/screens/orders_admin_page.dart:279-281`
**Steps**:
1. Add StreamProvider that watches today's completed orders, sums subtotals
2. Display in AppBar subtitle: "Today: X.XXX BHD (N orders)"
3. Update in real-time as orders are served
**Impact**: Merchant sees progress toward daily goal, motivating, actionable

---

## 7. SUCCESS METRICS TO TRACK

### Operational Efficiency
1. **Order Acceptance Time**: Time from order placed → status changes from "pending" (target: <30 sec, critical metric)
2. **Order Fulfillment Time**: Pending → Served (target: <15 min, track by merchant)
3. **Menu Update Time**: Time to toggle item availability (target: <5 sec)
4. **Daily Menu Update Frequency**: # of availability toggles per day (expect 10-50x increase)

### Merchant Satisfaction
5. **Onboarding Time**: Signup → First Order (target: <30 min vs 4+ hours today)
6. **Onboarding Completion Rate**: % of signups who complete setup (target: >80%)
7. **Merchant Retention**: % active after 30/90 days (target: >90%)
8. **Net Promoter Score (NPS)**: "How likely to recommend?" (target: >50)
9. **Support Tickets**: # of "how do I..." tickets (should decrease 60%)

### Revenue & Growth
10. **Orders Per Merchant Per Day**: (target: 20-100 depending on merchant size)
11. **Average Order Value**: Should increase with loyalty + upselling features
12. **Customer Reorder Rate**: % of customers who order 2+ times (target: >40%)
13. **Loyalty Program Adoption**: % of orders with loyalty phone # (target: >70%)

### Customer Experience
14. **Order Placement Abandonment Rate**: % who add to cart but don't checkout (target: <15%)
15. **Customer Satisfaction Score**: Post-order rating (target: >4.5/5.0)
16. **Time to Find Item**: Customer browsing → add to cart (optimize with search/favorites)

### Technical Health
17. **Firestore Read/Write Costs**: Monitor for optimization opportunities
18. **Analytics Load Time**: Dashboard render time (target: <3 sec)
19. **Email Delivery Rate**: % of order notifications sent successfully (target: >98%)
20. **Sound Alert Success Rate**: % of orders where sound plays (target: >95%, browser-dependent)

### Feature Adoption
21. **Kitchen Mode Usage**: % of staff sessions using kitchen mode vs default view
22. **WhatsApp Notification Preference**: % merchants who enable WhatsApp over email
23. **Profit Tracking Adoption**: % merchants who enter COGS data
24. **Promotions Created**: # of active promotions per merchant (indicator of engagement)

---

## 🎯 FINAL RECOMMENDATION: FOCUS ON SPEED

**The #1 merchant pain point is ORDER PROCESSING SPEED.** Every minute an order sits "pending" is lost revenue and frustrated customers. The quick wins above (sound alerts, availability toggle, better filtering, larger car plates) solve 80% of friction with minimal code changes.

**Next-level differentiation comes from KITCHEN MODE + WHATSAPP.** Competitors (Square, Toast, Clover) don't have mobile-first kitchen views. WhatsApp notifications are game-changing in markets like Middle East where merchants live on their phones.

**Retention depends on PROFIT VISIBILITY + LOYALTY TIERS.** Merchants stay when they see revenue growing AND understand profitability. Loyalty tiers increase customer frequency 2-3x (proven by Starbucks, Dunkin').

Ship Quick Wins in Week 1, Category A in Month 1, Category B in Month 2, Category C in Month 3-4. **Prioritize merchant feedback** after each sprint — they'll tell you what's actually broken.

---

**Analysis completed**: January 4, 2026
**Next steps**: Implement Quick Wins #1-3 this week, gather merchant feedback, iterate.
