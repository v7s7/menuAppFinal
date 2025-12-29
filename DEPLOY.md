# Deployment Guide

## Prerequisites Checklist

- [ ] Flutter SDK 3.9.2+ installed
- [ ] Firebase project created
- [ ] Cloudflare account set up
- [ ] Resend API key obtained
- [ ] Firebase CLI installed (`npm install -g firebase-tools`)

## Environment Configuration

### 1. Update Email Configuration

Edit `lib/core/config/email_config.dart`:

```dart
static const String workerUrl = 'https://YOUR_WORKER_URL.workers.dev';
static const String defaultEmail = 'your-notifications@example.com';
```

### 2. Deploy Cloudflare Worker

```bash
cd cloudflare-worker

# Login to Cloudflare
wrangler login

# Deploy the worker
wrangler deploy

# Set environment variable in Cloudflare dashboard:
# RESEND_API_KEY = your_resend_api_key
```

### 3. Deploy Firestore Rules & Indexes

```bash
firebase login
firebase use --add  # Select your Firebase project

# Deploy security rules and indexes
firebase deploy --only firestore:rules,firestore:indexes
```

## Build for Production

### Customer App

```bash
flutter build web --release --base-href="/"
```

Output: `build/web/`

### Merchant Console

```bash
flutter build web --release -t lib/merchant/main_merchant.dart --base-href="/" -o build/web-merchant
```

Output: `build/web-merchant/`

## Deploy to Firebase Hosting

### Option 1: Single Hosting (Customer App Only)

```bash
firebase deploy --only hosting
```

### Option 2: Multiple Targets (Customer + Merchant)

Update `firebase.json`:

```json
{
  "hosting": [
    {
      "target": "customer",
      "public": "build/web",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [{ "source": "**", "destination": "/index.html" }]
    },
    {
      "target": "merchant",
      "public": "build/web-merchant",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [{ "source": "**", "destination": "/index.html" }]
    }
  ]
}
```

Deploy:

```bash
# Deploy customer app to main site
firebase target:apply hosting customer your-app
firebase deploy --only hosting:customer

# Deploy merchant console to separate site
firebase target:apply hosting merchant your-app-merchant
firebase deploy --only hosting:merchant
```

## Post-Deployment

### 1. Create Initial Data

Access Firebase Console and create:

1. **Merchant Document**: `merchants/{merchantId}`
   ```json
   {
     "name": "Your Restaurant",
     "createdAt": "2024-01-01T00:00:00Z"
   }
   ```

2. **Branch Document**: `merchants/{merchantId}/branches/{branchId}`
   ```json
   {
     "name": "Main Branch",
     "address": "123 Main St",
     "phone": "+1234567890",
     "createdAt": "2024-01-01T00:00:00Z"
   }
   ```

3. **Branding Config**: `merchants/{merchantId}/branches/{branchId}/config/branding`
   ```json
   {
     "title": "Your Restaurant",
     "headerText": "Welcome!",
     "primaryHex": "#FFFFFF",
     "secondaryHex": "#000000",
     "logo": ""
   }
   ```

4. **Slug Mapping** (optional): `/slugs/{your-slug}`
   ```json
   {
     "merchantId": "your-merchant-id",
     "branchId": "your-branch-id"
   }
   ```

### 2. Create Admin User

1. Go to Firebase Console > Authentication
2. Add a user with email/password
3. Copy the user's UID
4. Create role document: `merchants/{merchantId}/branches/{branchId}/roles/{uid}`
   ```json
   {
     "role": "owner",
     "email": "admin@example.com",
     "createdAt": "2024-01-01T00:00:00Z"
   }
   ```

### 3. Test URLs

**Customer App:**
- Direct: `https://your-app.web.app?m=merchantId&b=branchId`
- Slug: `https://your-app.web.app/s/your-slug`

**Merchant Console:**
- Direct: `https://your-app-merchant.web.app?m=merchantId&b=branchId`
- Slug: `https://your-app-merchant.web.app/s/your-slug`

## Monitoring & Maintenance

### Check Email Notifications

Monitor Cloudflare Worker logs:
```bash
wrangler tail
```

### Check Firestore Usage

```bash
firebase firestore:databases:list
```

### Update Security Rules

After making changes to `firestore.rules`:
```bash
firebase deploy --only firestore:rules
```

## Rollback

If you need to rollback to a previous version:

```bash
# List previous deployments
firebase hosting:releases:list

# Rollback to specific version
firebase hosting:rollback
```

## Performance Optimization

### Enable Caching

Ensure `firebase.json` has proper cache headers (already configured):

```json
{
  "headers": [
    {
      "source": "**/*.@(js|css)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    }
  ]
}
```

### Monitor Performance

Use Firebase Performance Monitoring:

```bash
firebase deploy --only hosting --with-performance
```

## Troubleshooting

### Issue: "DefaultFirebaseOptions not configured for android"

**Solution**: App is web-only. To add mobile support, run `flutterfire configure`.

### Issue: Email notifications not working

**Checklist:**
- [ ] Cloudflare Worker deployed
- [ ] RESEND_API_KEY set in Cloudflare dashboard
- [ ] Worker URL updated in `email_config.dart`
- [ ] Check worker logs: `wrangler tail`

### Issue: Slug routing not working

**Checklist:**
- [ ] Slug document exists in Firestore `/slugs/{slug}`
- [ ] Document has correct `merchantId` and `branchId`
- [ ] Firestore rules allow public read on `/slugs/{slug}`

## Security Checklist

Before going live:

- [ ] Remove all `print()` statements
- [ ] Verify Firestore rules are deployed
- [ ] API keys are in environment variables (not code)
- [ ] HTTPS enabled (Firebase Hosting handles this)
- [ ] Test role-based access (owner, staff, customer)
- [ ] Enable Firebase App Check (recommended for production)

## Cost Optimization

### Firebase (Spark Plan - Free Tier)

- Firestore: 50K reads/day, 20K writes/day
- Hosting: 10GB storage, 360MB/day transfer
- Auth: Unlimited

### Cloudflare Workers (Free Tier)

- 100,000 requests/day

### Resend (Free Tier)

- 100 emails/day

**Tip**: Monitor usage in Firebase Console > Usage & Billing
