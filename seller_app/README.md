# Seller App

Flutter Android app for Seller registration, sales entry with a product
dropdown, and a profile card showing the seller's name and email. It connects
to the NestJS + PostgreSQL API; Firebase Auth, Firestore, and Google Sign-In
are not required.

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
flutter analyze
flutter test
```

If `API_BASE_URL` is omitted, the app uses the production API:
`https://wholesellerbackend-production.up.railway.app/api/v1`.

For release builds, the production URL is used by default. To override it:

```sh
flutter build apk --release --dart-define=API_BASE_URL=https://wholesellerbackend-production.up.railway.app/api/v1
```

New users register with name, email, and password. Registration always creates
a Seller account. Existing users sign in with email/password. Access tokens
remain in memory; rotating refresh tokens are stored using Android secure
storage.

For a GitHub Actions APK, `API_BASE_URL` can override the default production
URL. See the repository README for API deployment, database, owner provisioning,
and the Firebase data migration limitation.

See [FUNCTIONS_AND_LOGIC.md](./FUNCTIONS_AND_LOGIC.md) for a one-page list of
Seller app features and validation/business logic.
