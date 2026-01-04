# 🚀 Complete Deployment Guide - SweetWeb

## Overview

Deploy both **Customer App** and **Merchant Console** to Firebase Hosting (FREE tier).

**Final URLs:**
- Customer: `https://your-app.web.app` (or custom domain)
- Merchant: `https://your-app.web.app/merchant`
- Slug routing: `https://your-app.web.app/s/your-slug` (works for both)

---

## Prerequisites

1. **Firebase CLI** installed:
   ```bash
   npm install -g firebase-tools
   ```

2. **Flutter** installed (3.9.2+)

3. **Firebase project** created (you already have this)

---

## Step 1: Update Firebase Hosting Configuration

Replace your `firebase.json` with this configuration:

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "/merchant/**",
        "destination": "/merchant/index.html"
      },
      {
        "source": "/s/**",
        "destination": "/index.html"
      },
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(jpg|jpeg|gif|png|svg|webp|js|css|woff|woff2|ttf|eot)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  }
}
```

---

## Step 2: Build Both Apps

### Build Customer App (Default)
```bash
flutter build web --release --base-href "/" -o build/web
```

### Build Merchant Console
```bash
flutter build web --release --base-href "/merchant/" -t lib/merchant/main_merchant.dart -o build/web-merchant
```

### Merge Both Builds
```bash
# Create merchant directory inside customer build
mkdir -p build/web/merchant

# Copy merchant build into customer build
cp -r build/web-merchant/* build/web/merchant/

# Verify structure
ls -la build/web/
ls -la build/web/merchant/
```

**Expected structure:**
```
build/web/
├── index.html              (Customer app)
├── flutter_service_worker.js
├── main.dart.js
├── assets/
├── canvaskit/
└── merchant/
    ├── index.html          (Merchant console)
    ├── flutter_service_worker.js
    ├── main.dart.js
    └── assets/
```

---

## Step 3: Deploy to Firebase

### First time setup:
```bash
firebase login
firebase init hosting
# Choose your Firebase project
# Accept defaults for public directory (build/web)
# Configure as single-page app: Yes
# Don't overwrite index.html
```

### Deploy:
```bash
firebase deploy --only hosting
```

### Deploy with indexes:
```bash
firebase deploy --only hosting,firestore:indexes
```

**Expected output:**
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/your-project/overview
Hosting URL: https://your-project.web.app
```

---

## Step 4: Test Your Deployment

### Customer App:
```
https://your-project.web.app
https://your-project.web.app/s/your-slug
https://your-project.web.app?m=merchantId&b=branchId
```

### Merchant Console:
```
https://your-project.web.app/merchant
https://your-project.web.app/merchant/s/your-slug
```

---

## Step 5: Custom Domain (Optional)

### Add custom domain in Firebase Console:
1. Go to Firebase Console > Hosting
2. Click "Add custom domain"
3. Follow instructions to verify domain ownership
4. Update DNS records (A/CNAME)
5. Wait for SSL certificate (15 min - 24 hours)

**Example:**
- `sweetweb.yourdomain.com` → Customer app
- `sweetweb.yourdomain.com/merchant` → Merchant console

---

## Automated Deployment Script

Create `deploy.sh` in project root:

```bash
#!/bin/bash

echo "🔨 Building Customer App..."
flutter build web --release --base-href "/" -o build/web

echo "🔨 Building Merchant Console..."
flutter build web --release --base-href "/merchant/" -t lib/merchant/main_merchant.dart -o build/web-merchant

echo "📦 Merging builds..."
mkdir -p build/web/merchant
cp -r build/web-merchant/* build/web/merchant/

echo "🚀 Deploying to Firebase..."
firebase deploy --only hosting,firestore:indexes

echo "✅ Deployment complete!"
echo "Customer App: https://your-project.web.app"
echo "Merchant Console: https://your-project.web.app/merchant"
```

Make executable:
```bash
chmod +x deploy.sh
```

Run:
```bash
./deploy.sh
```

---

## Alternative: GitHub Actions Auto-Deploy

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Firebase Hosting

on:
  push:
    branches:
      - main

jobs:
  build_and_deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.9.2'

      - name: Install dependencies
        run: flutter pub get

      - name: Build Customer App
        run: flutter build web --release --base-href "/" -o build/web

      - name: Build Merchant Console
        run: flutter build web --release --base-href "/merchant/" -t lib/merchant/main_merchant.dart -o build/web-merchant

      - name: Merge builds
        run: |
          mkdir -p build/web/merchant
          cp -r build/web-merchant/* build/web/merchant/

      - name: Deploy to Firebase
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: your-firebase-project-id
```

---

## Troubleshooting

### Issue: Slug routing not working
**Solution**: Check `firebase.json` rewrites. Ensure `/s/**` maps to `/index.html`.

### Issue: Merchant console loads customer app
**Solution**: Check that `/merchant/**` maps to `/merchant/index.html`.

### Issue: Assets not loading (404)
**Solution**: Ensure `--base-href` matches deployment path:
- Customer: `--base-href "/"`
- Merchant: `--base-href "/merchant/"`

### Issue: Firebase deploy fails
**Solution**:
```bash
firebase login --reauth
firebase use --add
```

### Issue: Build size too large
**Solution**: Enable code splitting and tree shaking:
```bash
flutter build web --release --split-debug-info=build/debug --web-renderer canvaskit
```

---

## Other Free Hosting Alternatives

If Firebase doesn't work for you:

### 1. **Netlify** (Free tier: 100 GB bandwidth/month)
```bash
# Install Netlify CLI
npm install -g netlify-cli

# Build apps (same as above)
flutter build web --release -o build/web
flutter build web --release --base-href "/merchant/" -t lib/merchant/main_merchant.dart -o build/web-merchant
mkdir -p build/web/merchant
cp -r build/web-merchant/* build/web/merchant/

# Create netlify.toml
cat > netlify.toml << 'EOF'
[build]
  publish = "build/web"

[[redirects]]
  from = "/merchant/*"
  to = "/merchant/index.html"
  status = 200

[[redirects]]
  from = "/s/*"
  to = "/index.html"
  status = 200

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
EOF

# Deploy
netlify deploy --prod
```

### 2. **Vercel** (Free tier: Unlimited bandwidth, 100 GB-hours)
```bash
npm install -g vercel

# Build apps (same as above)

# Create vercel.json
cat > vercel.json << 'EOF'
{
  "rewrites": [
    { "source": "/merchant/(.*)", "destination": "/merchant/index.html" },
    { "source": "/s/(.*)", "destination": "/index.html" },
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
EOF

# Deploy
vercel --prod
```

### 3. **Cloudflare Pages** (Free tier: Unlimited bandwidth)
```bash
# Build apps (same as above)

# Create _redirects file
cat > build/web/_redirects << 'EOF'
/merchant/* /merchant/index.html 200
/s/* /index.html 200
/* /index.html 200
EOF

# Deploy via Cloudflare Pages dashboard
# Connect GitHub repo and set:
# Build command: ./deploy.sh
# Output directory: build/web
```

---

## Performance Optimization

### 1. Enable compression
Already configured in `firebase.json` headers.

### 2. Lazy load images
```dart
Image.network(
  imageUrl,
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return CircularProgressIndicator();
  },
)
```

### 3. Code splitting (reduces initial load)
```bash
flutter build web --release --split-debug-info=build/debug
```

### 4. Use CanvasKit (better performance)
```bash
flutter build web --release --web-renderer canvaskit
```

---

## Cost Estimate (Firebase Free Tier)

| Resource | Free Tier | Your Usage (estimate) | Status |
|----------|-----------|----------------------|--------|
| Hosting Storage | 10 GB | <100 MB | ✅ Free |
| Hosting Bandwidth | 360 MB/day | <100 MB/day | ✅ Free |
| Firestore Reads | 50K/day | <10K/day | ✅ Free |
| Firestore Writes | 20K/day | <5K/day | ✅ Free |
| Firestore Storage | 1 GB | <10 MB | ✅ Free |
| Cloud Functions | 125K invocations/month | 0 (not using yet) | ✅ Free |

**Conclusion**: You'll stay **100% free** with Firebase for months, even with moderate traffic.

---

## Summary

**Recommended**: Firebase Hosting (easiest, already using Firebase)

**Commands**:
```bash
# One-time setup
npm install -g firebase-tools
firebase login
firebase init hosting

# Every deployment
flutter build web --release -o build/web
flutter build web --release --base-href "/merchant/" -t lib/merchant/main_merchant.dart -o build/web-merchant
mkdir -p build/web/merchant && cp -r build/web-merchant/* build/web/merchant/
firebase deploy --only hosting,firestore:indexes
```

**Result**:
- Customer: `https://your-project.web.app`
- Merchant: `https://your-project.web.app/merchant`
- Slug routing works for both
- 100% free (generous limits)
- SSL included
- Custom domain optional

Done! 🎉
