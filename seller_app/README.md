# Seller App

Flutter Android app for Seller registration, sales entry, and profile
management. It connects to the NestJS + PostgreSQL API; Firebase Auth,
Firestore, and Google Sign-In are not required.

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
flutter analyze
flutter test
```

For release builds, use the HTTPS API URL:

```sh
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

New users register with name, email, and password. Registration always creates
a Seller account. Existing users sign in with email/password. Access tokens
remain in memory; rotating refresh tokens are stored using Android secure
storage.

For a GitHub Actions APK, configure the repository variable `API_BASE_URL` as
an HTTPS URL. See the repository README for API deployment, database, owner
provisioning, and the Firebase data migration limitation.
