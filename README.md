# Sweets App

A full-featured Flutter web application for restaurant ordering with customer and merchant interfaces, built with Firebase and Riverpod.

## 🎯 Features

### Customer App
- Browse menu by categories
- Add items to cart with optional notes
- Place orders with loyalty rewards
- Real-time order status tracking
- Slug-based routing for easy sharing (`/s/your-slug`)

### Merchant Console
- Product management (add, edit, delete menu items)
- Order management (view, update status, cancel orders)
- Analytics dashboard (revenue, top products, hourly trends)
- Loyalty program configuration
- Branding customization (colors, logo, name)
- Email notifications for new and cancelled orders

## 🏗️ Architecture

- **Frontend**: Flutter 3.9.2+ (Web-focused, mobile platforms scaffolded)
- **State Management**: Riverpod 2.6.1
- **Backend**: Firebase (Firestore + Auth)
- **Email**: Cloudflare Worker + Resend API
- **Routing**: URL-based with slug support

## 📋 Prerequisites

- Flutter SDK 3.9.2 or higher
- Firebase project (https://console.firebase.google.com)
- Cloudflare account (for email worker)
- Resend API key (https://resend.com)

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd menuApp
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

**For Web (already configured):**
The web platform is pre-configured in `lib/firebase_options.dart`.

**For iOS/Android (optional):**
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure all platforms
flutterfire configure
```

### 4. Set Up Email Service

1. Deploy the Cloudflare Worker:
   ```bash
   cd cloudflare-worker
   # Follow Cloudflare Workers deployment guide
   # Set RESEND_API_KEY environment variable in Cloudflare dashboard
   ```

2. Update email configuration in `lib/core/config/email_config.dart`:
   ```dart
   static const String workerUrl = 'https://your-worker.workers.dev';
   static const String defaultEmail = 'your-email@example.com';
   ```

### 5. Configure Environment (Optional)

Copy `.env.example` to `.env` and fill in your values (note: Flutter doesn't use .env files natively; update configs in code):

```bash
cp .env.example .env
```

### 6. Set Up Firestore

1. Enable Firestore in Firebase Console
2. Deploy security rules:
   ```bash
   firebase deploy --only firestore:rules
   firebase deploy --only firestore:indexes
   ```

3. Create initial data structure:
   - Add a merchant document
   - Add a branch under that merchant
   - Add menu items, categories, branding config

### 7. Run the Apps

**Customer App:**
```bash
flutter run -d chrome
# Or build for production
flutter build web --release
```

**Merchant Console:**
```bash
flutter run -t lib/merchant/main_merchant.dart -d chrome
# Or build for production
flutter build web --release -t lib/merchant/main_merchant.dart
```

## 🔗 URL Routing

### Customer App
- **Slug routing**: `https://your-domain.com/s/your-slug`
- **Direct IDs**: `https://your-domain.com?m=merchantId&b=branchId`

### Merchant Console
- **Slug routing**: `https://your-domain.com/s/your-slug` (requires authentication)
- **Direct IDs**: `https://your-domain.com?m=merchantId&b=branchId`

## 📦 Build & Deploy

### Build for Web

**Customer App:**
```bash
flutter build web --release --base-href "/" -o build/web
```

**Merchant Console:**
```bash
flutter build web --release --base-href "/" -t lib/merchant/main_merchant.dart -o build/web-merchant
```

### Deploy to Firebase Hosting

```bash
# Deploy customer app
firebase deploy --only hosting

# Deploy merchant console (configure separate hosting target in firebase.json)
firebase hosting:channel:deploy merchant --only hosting:merchant
```

## 🧪 Testing

Run tests:
```bash
flutter test
```

Run with Firebase Emulators:
```bash
# Start emulators
firebase emulators:start

# Run app with emulators
flutter run --dart-define=USE_EMULATORS=true
```

## 🔒 Security

- Firestore security rules enforce role-based access (owner/staff/customer)
- Anonymous authentication for customers
- Email/password authentication for merchants
- API keys stored as environment variables (never in code)

## 📁 Project Structure

```
lib/
├── main.dart                    # Customer app entry point
├── app.dart                     # Customer app root widget
├── merchant/
│   ├── main_merchant.dart       # Merchant console entry point
│   └── screens/                 # Merchant UI screens
├── features/
│   ├── cart/                    # Shopping cart
│   ├── orders/                  # Order placement and tracking
│   ├── sweets/                  # Menu items (products)
│   ├── categories/              # Category management
│   ├── loyalty/                 # Loyalty program
│   └── analytics/               # Analytics dashboard
├── core/
│   ├── config/                  # App configuration
│   ├── services/                # Email, notifications
│   ├── branding/                # Branding customization
│   └── theme/                   # UI theme
└── firebase_options.dart        # Firebase configuration

cloudflare-worker/
└── worker.js                    # Email notification service
```

## 🛠️ Configuration Files

- `pubspec.yaml` - Flutter dependencies
- `firebase.json` - Firebase hosting & Firestore config
- `firestore.rules` - Database security rules
- `firestore.indexes.json` - Database indexes
- `lib/core/config/email_config.dart` - Email service URLs
- `lib/core/config/app_config.dart` - App-wide configuration

## 📊 Analytics & Reports

The merchant console includes:
- Revenue tracking
- Order statistics
- Top-selling products
- Hourly order trends
- Customer loyalty insights
- Email reports (daily/weekly)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📝 License

[Your License Here]

## 🆘 Support

For issues or questions, please create an issue in the GitHub repository.

## 🔄 Version

Current version: 1.0.0

## 📞 Contact

[Your Contact Information]
