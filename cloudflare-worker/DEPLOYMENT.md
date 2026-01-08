# WhatsApp Notification System - Deployment Guide

## Overview

This Cloudflare Worker provides 24/7 WhatsApp order notifications for SweetWeb using:
- **Cloudflare Cron Triggers** (runs every 1 minute)
- **Firestore REST API** (no Cloud Functions needed)
- **Twilio WhatsApp API**
- **Idempotent delivery** with persistent tracking

## Architecture

```
Customer Places Order (Flutter App)
    ↓
Firestore: Order with notifications.waNewSent = false
    ↓
Cloudflare Worker Cron (every minute)
    ↓
Query Firestore REST API for pending notifications
    ↓
Read Branch WhatsApp Config
    ↓
Send WhatsApp via Twilio API
    ↓
Update Firestore: notifications.waNewSent = true (with precondition)
```

## Prerequisites

### 1. Firebase Service Account

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** → **Service Accounts**
4. Click **Generate New Private Key**
5. Save the JSON file securely
6. Extract these values:
   - `project_id` → **FIREBASE_PROJECT_ID**
   - `client_email` → **FIREBASE_CLIENT_EMAIL**
   - `private_key` → **FIREBASE_PRIVATE_KEY** (entire PEM block including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`)

### 2. Twilio WhatsApp Account

#### Option A: Twilio Sandbox (Testing)
1. Create account at [Twilio Console](https://console.twilio.com/)
2. Go to **Messaging** → **Try it out** → **Send a WhatsApp message**
3. Follow instructions to connect your WhatsApp number to sandbox
4. Use **TWILIO_WHATSAPP_FROM**: `whatsapp:+14155238886` (Twilio sandbox number)

#### Option B: Twilio Production WhatsApp (Production)
1. Go to [Twilio WhatsApp Sender Registration](https://www.twilio.com/console/sms/whatsapp/senders)
2. Register your business phone number with Meta
3. Complete WhatsApp Business Profile verification
4. Use **TWILIO_WHATSAPP_FROM**: `whatsapp:+YOUR_VERIFIED_NUMBER`

**Get Credentials:**
1. Go to [Twilio Console](https://console.twilio.com/)
2. Copy **Account SID** → **TWILIO_ACCOUNT_SID**
3. Copy **Auth Token** → **TWILIO_AUTH_TOKEN**

### 3. Branch WhatsApp Configuration in Firestore

For each branch that should receive WhatsApp notifications, create this document:

**Path:** `merchants/{merchantId}/branches/{branchId}/config/notifications`

**Fields:**
```json
{
  "whatsappEnabled": true,
  "whatsappNumber": "+97312345678"
}
```

**Important:**
- `whatsappNumber` must be in **E.164 format** (e.g., `+973XXXXXXXX` for Bahrain)
- For Twilio Sandbox: The merchant's WhatsApp number must first send `join <your-sandbox-code>` to the Twilio sandbox number
- For Twilio Production: Number must be verified by Meta

## Deployment Steps

### Step 1: Deploy Worker to Cloudflare

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **Workers & Pages**
3. Click **Create application** → **Create Worker**
4. Name it: `sweetweb-whatsapp-notifications`
5. Click **Deploy**
6. Click **Edit Code**
7. Delete default code and paste contents of `worker.js`
8. Click **Save and Deploy**

### Step 2: Configure Secrets

In the Worker dashboard, go to **Settings** → **Variables**

Add these **Secret** environment variables:

| Secret Name | Value | Example |
|------------|-------|---------|
| `FIREBASE_PROJECT_ID` | Your Firebase project ID | `sweetweb-prod` |
| `FIREBASE_CLIENT_EMAIL` | Service account email | `firebase-adminsdk-xxxxx@sweetweb-prod.iam.gserviceaccount.com` |
| `FIREBASE_PRIVATE_KEY` | Full private key PEM | `-----BEGIN PRIVATE KEY-----\nMIIE...` |
| `TWILIO_ACCOUNT_SID` | Twilio Account SID | `ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `TWILIO_AUTH_TOKEN` | Twilio Auth Token | `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `TWILIO_WHATSAPP_FROM` | Twilio WhatsApp sender | `whatsapp:+14155238886` (sandbox) or `whatsapp:+97312345678` (production) |

**Important Notes:**
- For `FIREBASE_PRIVATE_KEY`: Copy the ENTIRE private_key value from your service account JSON, including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`
- Make sure to preserve all newlines in the private key (they should be literal `\n` in the JSON)
- Click **Encrypt** for each secret

### Step 3: Configure Cron Trigger

1. In Worker dashboard, go to **Triggers** tab
2. Scroll to **Cron Triggers**
3. Click **Add Cron Trigger**
4. Enter schedule: `* * * * *` (every minute)
5. Click **Add Trigger**

**Cron Schedule Format:**
- `* * * * *` = Every minute
- `*/5 * * * *` = Every 5 minutes (if you want less frequent checks)

### Step 4: Verify Deployment

1. Go to **Logs** tab in Worker dashboard
2. Wait for next cron trigger (up to 1 minute)
3. You should see logs like:
   ```
   [CRON] Starting WhatsApp notification check
   [AUTH] Generating new OAuth token
   [PENDING] Checking for pending orders needing notifications
   [PENDING] Found 0 pending orders
   [CANCELLED] Checking for cancelled orders needing notifications
   [CANCELLED] Found 0 cancelled orders
   [CRON] Completed successfully
   ```

## Testing

### 1. Create Test Order

1. Open your Flutter app (customer side)
2. Add items to cart
3. Place an order
4. Order is created with `notifications.waNewSent = false`

### 2. Verify Worker Processing

1. Wait up to 1 minute for cron trigger
2. Check Worker logs for:
   ```
   [PENDING] Found 1 pending orders
   [NEW ORDER] Processing ORD-123 (merchant: xxx, branch: yyy)
   [NEW ORDER] ✅ WhatsApp sent for ORD-123 to +97312345678 (SID: SMxxxx)
   ```

### 3. Verify WhatsApp Received

Check the merchant's WhatsApp - they should receive:
```
🔔 *New Order: ORD-123*

📍 Table: 5

*Items:*
• Chocolate Cake (x2) - 3.500 BHD
• Espresso (x1) - 1.200 BHD

*Total: 8.200 BHD*

⏰ Status: PENDING
```

### 4. Test Cancellation

1. In merchant console, cancel an order
2. Wait up to 1 minute for cron trigger
3. Merchant WhatsApp should receive cancellation notification

## Monitoring

### View Logs

**Real-time Logs:**
1. Worker dashboard → **Logs** tab
2. Enable **Log Stream**

**Search Logs:**
1. Worker dashboard → **Logs** → **Search**
2. Filter by time range and log level

### Key Log Patterns

**Success:**
```
[NEW ORDER] ✅ WhatsApp sent for ORD-123 to +97312345678 (SID: SMxxxx)
```

**Configuration Missing:**
```
[NEW ORDER] WhatsApp not configured for branch xxx, skipping
```

**Twilio Error:**
```
[TWILIO] Failed to send WhatsApp: [Error details]
```

**Auth Error:**
```
[AUTH] OAuth token exchange failed: [Error details]
```

## Troubleshooting

### No WhatsApp Messages Sent

**Check 1: Cron Trigger Active?**
- Worker → Triggers → Verify cron schedule exists
- Check Logs for `[CRON]` entries every minute

**Check 2: Secrets Configured?**
- Worker → Settings → Variables → Verify all 6 secrets present
- Re-enter secrets if worker was redeployed

**Check 3: Firestore Config Exists?**
```
merchants/{merchantId}/branches/{branchId}/config/notifications
{
  "whatsappEnabled": true,
  "whatsappNumber": "+97312345678"
}
```

**Check 4: Twilio Sandbox Connected?**
- If using sandbox, merchant must send `join <code>` to Twilio number first
- Check [Twilio Console](https://console.twilio.com/us1/develop/sms/try-it-out/whatsapp-learn) for sandbox status

### "OAuth token exchange failed"

**Issue:** Invalid Firebase credentials

**Solution:**
1. Regenerate service account key in Firebase Console
2. Update all 3 Firebase secrets in Worker
3. Ensure `FIREBASE_PRIVATE_KEY` includes `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`
4. Verify no extra spaces or formatting issues

### "FAILED_PRECONDITION" in Logs

**Issue:** Multiple workers trying to update same order (rare)

**Solution:** This is expected behavior - worker uses preconditions for idempotency. The log message indicates order was already processed. No action needed.

### Twilio "Recipient not authorized"

**Issue:** Using sandbox and recipient hasn't joined

**Solution:**
1. Merchant sends WhatsApp message: `join <your-sandbox-code>` to Twilio sandbox number
2. Or upgrade to Twilio Production WhatsApp

### "Missing Firebase credentials"

**Issue:** Secrets not properly configured

**Solution:**
1. Go to Worker → Settings → Variables
2. Click **Add variable** → Select **Secret**
3. Add all required secrets
4. Click **Encrypt** for each
5. Click **Deploy**

## Performance

### Rate Limits

**Firestore REST API:**
- No hard limit for reads
- Worker queries max 10 orders per cron run per type (20 total)

**Twilio WhatsApp:**
- Sandbox: ~10 messages per hour
- Production: Varies by tier (check Twilio dashboard)

**Cloudflare Workers:**
- Free tier: 100,000 requests/day (sufficient for cron triggers)
- CPU time: 10ms per request (actual usage: ~50-200ms per cron)

### Scaling

**Current Setup:**
- Processes up to 20 orders per minute (10 new + 10 cancelled)
- Handles bursts automatically (oldest orders processed first)

**If You Need Higher Throughput:**
1. Increase limit in queries from 10 to 50
2. Or increase cron frequency to every 30 seconds: `*/0.5 * * * *` (requires paid plan)

### OAuth Token Caching

- Token cached globally in Worker isolate
- Reduces Firebase auth calls by ~60x
- Cache valid for ~55 minutes (auto-refreshes)
- First cron run takes ~300ms, subsequent runs ~100ms

## Cost Estimation

**Cloudflare Workers:**
- Free tier: 100,000 requests/day
- Cron triggers: ~1,440 per day (every minute)
- Well within free tier

**Firestore:**
- Reads: ~40 per minute (collectionGroup queries + config docs)
- ~57,600 reads/day
- Cost: ~$0.36/day ($10.80/month) at Firestore pricing

**Twilio WhatsApp:**
- Sandbox: Free
- Production: ~$0.005 per message (varies by country)
- Example: 1,000 orders/month = ~$5/month

**Total Estimated Cost:** ~$15-20/month for moderate volume

## Security

### Firestore Rules

Ensure Worker service account has read access to orders and config:

```javascript
// Allow service accounts to read all data
match /{document=**} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.email.matches('.*@.*\\.iam\\.gserviceaccount\\.com$')
                  && request.resource.data.keys().hasOnly(['notifications']);
}
```

This allows:
- Service account to **read** orders and config
- Service account to **write only notification fields** on orders

### Secrets Management

- All secrets stored encrypted in Cloudflare
- Secrets never exposed in logs
- Private key never leaves Cloudflare Workers
- OAuth tokens cached in-memory only (not persisted)

## Migration from Email

If you were using the old email notification system:

1. **Flutter app:** Orders now include `notifications` field automatically
2. **Worker:** Email endpoints deprecated (return error message)
3. **Merchant console:** Can remove `OrderNotificationService` and `CancelledOrderNotificationService` initialization (optional)

No breaking changes - old orders without `notifications` field are simply skipped.

## Support

### Common Issues

1. **Orders not being detected:** Check notification flags are being written on order creation
2. **WhatsApp not received:** Check Twilio sandbox connection or credentials
3. **Multiple messages sent:** Check for duplicate cron triggers or multiple workers
4. **Slow processing:** Check Worker logs for auth errors (token not caching)

### Debug Checklist

- [ ] Cron trigger configured and active
- [ ] All 6 secrets present in Worker
- [ ] Firestore config document exists for branch
- [ ] Merchant WhatsApp connected to Twilio sandbox (if using sandbox)
- [ ] Orders have `notifications.waNewSent = false` field
- [ ] Worker logs show `[CRON]` messages every minute

### Getting Help

1. Check Worker logs for specific error messages
2. Verify each prerequisite step completed
3. Test with a single order first
4. Check Twilio logs: https://console.twilio.com/us1/monitor/logs/sms

## Future Enhancements

Potential improvements:

1. **Retry Logic:** Automatic retry for failed Twilio sends
2. **Status Updates:** Send WhatsApp when order status changes to "ready" or "served"
3. **Analytics:** Track message delivery rates and failures
4. **Multiple Languages:** Support Arabic/English messages based on merchant preference
5. **Rich Media:** Send order images or location maps via WhatsApp
6. **Two-Way Messaging:** Allow merchants to reply to orders via WhatsApp
