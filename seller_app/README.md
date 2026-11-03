# Seller App

Android app for seller profiles and sales entry. Firebase Authentication with
Google and Cloud Firestore are configured for project
`wholesale-mrsindia-2026`; no Node.js server is needed.

```sh
flutter pub get
flutter run
flutter build apk
flutter test
```

Sellers can view active products and submit sales. Firestore checks stock and
records the sale atomically. Firebase app configuration is in
`lib/firebase_options.dart` and `android/app/google-services.json`.
