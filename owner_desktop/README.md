# Owner Desktop

Flutter Windows desktop app for managing products, profiles, and sales. It
connects to the NestJS + PostgreSQL API; Firebase Auth, Firestore, and
Google Sign-In are not required.

On Windows, install Flutter's Windows desktop prerequisites, then run:

```powershell
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter analyze
flutter test
```

For a release build:

```powershell
flutter build windows --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Owner accounts are provisioned privately by the API administrator. There is no
Owner sign-up option in the app. The GitHub Actions Windows workflow requires
the repository variable `API_BASE_URL` to contain the deployed API's HTTPS
URL. It produces an installer artifact with the app and Visual C++ runtime.

See the repository README for API deployment, database, Owner provisioning,
and the Firebase data migration limitation.
