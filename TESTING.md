# Testing Guide

## Manual Testing Checklist

### Customer App - Menu Browsing

- [ ] **Load App** - App loads without errors at `/s/<slug>` or `?m=<merchantId>&b=<branchId>`
- [ ] **View Products** - All products display with images, names, and prices
- [ ] **Category Filter** - Category bar shows all categories and filters products correctly
- [ ] **Product Details** - Tap product to view nutrition info and description
- [ ] **Branding** - Custom colors and restaurant name display correctly

### Customer App - Cart & Ordering

- [ ] **Add to Cart** - Products add to cart with quantity increment
- [ ] **Cart Badge** - Cart icon shows correct item count
- [ ] **Add Note** - Can add custom note to cart item (e.g., "no sugar")
- [ ] **Modify Cart** - Can increase/decrease quantities in cart
- [ ] **Remove Item** - Can remove items from cart
- [ ] **Cart Totals** - Subtotal calculates correctly (3 decimal places for BHD)
- [ ] **Empty Cart** - Empty cart shows appropriate message

### Customer App - Loyalty (if enabled)

- [ ] **Phone Input** - Country picker works (default Bahrain +973)
- [ ] **Car Plate** - Can enter car plate number
- [ ] **Points Display** - Existing customer points display correctly
- [ ] **Points Calculation** - Points earned calculation shown (1 BHD = X points)
- [ ] **Redeem Points** - Can toggle points redemption
- [ ] **Discount Applied** - Discount reduces total correctly

### Customer App - Order Placement

- [ ] **Place Order** - Order submits successfully
- [ ] **Order Number** - Receives order number (ORD-001, ORD-002, etc.)
- [ ] **Status Page** - Redirects to order status page
- [ ] **Real-time Updates** - Status updates in real-time when merchant changes it
- [ ] **Order Details** - All items, quantities, and notes display correctly

### Merchant Console - Authentication

- [ ] **Login Required** - Redirects to login if not authenticated
- [ ] **Email Login** - Can log in with email/password
- [ ] **Logout** - Can log out successfully
- [ ] **Role Enforcement** - Only users with owner/staff role can access

### Merchant Console - Products

- [ ] **View Products** - All products display in grid
- [ ] **Add Product** - Can create new product with image upload
- [ ] **Edit Product** - Can edit existing product details
- [ ] **Toggle Active** - Can activate/deactivate products
- [ ] **Delete Product** - Can delete product (with confirmation)
- [ ] **Price Validation** - Price must be >= 0
- [ ] **Image Upload** - Can upload product images (PNG, JPG)

### Merchant Console - Orders

- [ ] **View Orders** - All orders display with status
- [ ] **Pending Badge** - Shows count of pending orders in navigation
- [ ] **Order Details** - Tap order to view full details
- [ ] **Update Status** - Can change order status (pending → accepted → preparing → ready → served)
- [ ] **Cancel Order** - Can cancel order with reason
- [ ] **Sound Alert** - Sound plays when new order arrives (web only)
- [ ] **Email Notification** - Email sent when new order placed
- [ ] **Cancellation Email** - Email sent when order cancelled

### Merchant Console - Analytics

- [ ] **Date Range** - Can select custom date range
- [ ] **Revenue Chart** - Daily revenue displays in line chart
- [ ] **Stat Cards** - Shows total revenue, orders, avg order value
- [ ] **Top Products** - Lists best-selling products
- [ ] **Hourly Chart** - Shows order distribution by hour
- [ ] **Category Breakdown** - Pie chart shows sales by category
- [ ] **Export Report** - Can email report to configured address

### Merchant Console - Settings

- [ ] **Branding** - Can update restaurant name, colors, logo
- [ ] **Loyalty Settings** - Can enable/disable and configure loyalty program
- [ ] **Slug Management** - Can create/update slug for easy sharing
- [ ] **Changes Save** - Settings persist after refresh

## Cross-Browser Testing

Test in the following browsers:

- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)
- [ ] Mobile Safari (iOS)
- [ ] Chrome Mobile (Android)

## Responsive Design Testing

Test at the following viewport sizes:

- [ ] Mobile (375x667) - iPhone SE
- [ ] Mobile (390x844) - iPhone 12/13/14
- [ ] Tablet (768x1024) - iPad
- [ ] Desktop (1920x1080) - Full HD
- [ ] Desktop (1280x720) - HD

## Performance Testing

### Lighthouse Scores (Target >= 90)

- [ ] Performance >= 90
- [ ] Accessibility >= 90
- [ ] Best Practices >= 90
- [ ] SEO >= 90
- [ ] PWA (installable)

Run Lighthouse:
```bash
# Open Chrome DevTools > Lighthouse tab
# Or use CLI:
npm install -g lighthouse
lighthouse https://your-app.web.app --view
```

### Load Time Metrics

- [ ] First Contentful Paint (FCP) < 1.8s
- [ ] Largest Contentful Paint (LCP) < 2.5s
- [ ] Time to Interactive (TTI) < 3.9s
- [ ] Total Blocking Time (TBT) < 300ms
- [ ] Cumulative Layout Shift (CLS) < 0.1

## Security Testing

### Authentication & Authorization

- [ ] **Unauthenticated Access** - Cannot access merchant console without login
- [ ] **Role Enforcement** - Staff cannot perform owner-only actions
- [ ] **Order Ownership** - Customers can only view their own orders
- [ ] **Firestore Rules** - Rules prevent unauthorized reads/writes

Test with Firebase Emulator:
```bash
firebase emulators:start
```

### Input Validation

- [ ] **SQL Injection** - Cannot inject SQL in text inputs
- [ ] **XSS** - Cannot inject scripts in notes or product names
- [ ] **Price Tampering** - Cannot submit negative prices
- [ ] **Quantity Limits** - Cart enforces max quantity (999)
- [ ] **File Upload** - Only accepts images (PNG, JPG)

### API Keys

- [ ] **No Exposed Keys** - Check browser DevTools Network tab for exposed secrets
- [ ] **Environment Variables** - Cloudflare Worker uses env variables (not hardcoded keys)

## Edge Cases

### Error Handling

- [ ] **Network Error** - Shows error message if offline
- [ ] **Firebase Error** - Shows error if Firestore query fails
- [ ] **Empty States** - Handles empty cart, no products, no orders gracefully
- [ ] **Invalid Slug** - Shows error message for non-existent slug
- [ ] **Missing IDs** - Shows error if no merchant/branch specified

### Data Integrity

- [ ] **Duplicate Orders** - Cannot submit same order twice (debounced button)
- [ ] **Concurrent Edits** - Handles multiple staff editing same product
- [ ] **Stale Data** - Real-time listeners update UI when data changes
- [ ] **Transaction Rollback** - Order counter increments correctly even with errors

### Boundary Values

- [ ] **Zero Price** - Product with 0.000 BHD price
- [ ] **Max Price** - Product with 999.999 BHD price
- [ ] **Long Names** - Product name with 100+ characters
- [ ] **Many Items** - Cart with 50 items (max limit)
- [ ] **Large Order** - Order with 1000 BHD subtotal (max limit)

## Regression Testing

After each major change, re-test:

1. Core user flows (browse → add to cart → place order)
2. Merchant order management (view → update status)
3. Real-time updates (place order on customer app, see in merchant console)
4. Email notifications (check inbox for order emails)

## Automated Testing (Optional)

### Unit Tests

Run existing tests:
```bash
flutter test
```

### Integration Tests

Create integration tests for critical flows:
```bash
flutter test integration_test/
```

### E2E Tests (Recommended)

Use a tool like Playwright or Cypress for automated E2E testing:

Example Playwright test:
```javascript
test('customer can place order', async ({ page }) => {
  await page.goto('https://your-app.web.app?m=test&b=test');
  await page.click('text=Chocolate Donut');
  await page.click('button:has-text("Add to Cart")');
  await page.click('[aria-label="Cart"]');
  await page.click('button:has-text("Place Order")');
  await expect(page.locator('text=Order Confirmed')).toBeVisible();
});
```

## Continuous Monitoring

### After Deployment

- [ ] **Firebase Console** - Monitor Firestore reads/writes usage
- [ ] **Cloudflare Dashboard** - Monitor Worker requests
- [ ] **Resend Dashboard** - Monitor email delivery rate
- [ ] **Error Tracking** - Set up Sentry or similar for runtime errors
- [ ] **Analytics** - Set up Google Analytics or Firebase Analytics

### Weekly Checks

- [ ] Review email delivery logs
- [ ] Check for Firestore errors in console
- [ ] Review user feedback/support tickets
- [ ] Monitor performance metrics

## Bug Reporting Template

When filing bugs, include:

1. **Environment**: Browser, OS, device
2. **Steps to Reproduce**: Detailed steps
3. **Expected Behavior**: What should happen
4. **Actual Behavior**: What actually happened
5. **Screenshots/Video**: Visual evidence
6. **Console Errors**: Any errors in browser console
7. **Network Logs**: Relevant network requests

## Test Data Cleanup

After testing, clean up:

```bash
# Delete test orders
firebase firestore:delete --shallow merchants/TEST_MERCHANT/branches/TEST_BRANCH/orders

# Delete test products
firebase firestore:delete --shallow merchants/TEST_MERCHANT/branches/TEST_BRANCH/menuItems
```

## Pre-Launch Checklist

- [ ] All critical flows tested and passing
- [ ] No console errors or warnings
- [ ] Lighthouse scores >= 90 across all categories
- [ ] Email notifications working in production
- [ ] Firestore rules deployed and tested
- [ ] Real merchant data populated
- [ ] Cloudflare Worker deployed with correct API keys
- [ ] Custom domain configured (if applicable)
- [ ] SSL certificate active (Firebase Hosting handles this)
- [ ] Monitoring and analytics configured
