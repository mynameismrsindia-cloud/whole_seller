# Owner Desktop

Flutter Windows desktop app for managing products and sales. It
connects to the NestJS + PostgreSQL API; Firebase Auth, Firestore, and
Google Sign-In are not required.

On Windows, install Flutter's Windows desktop prerequisites, then run:

```powershell
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=https://wholesellerbackend-production.up.railway.app/api/v1
flutter analyze
flutter test
```

If `API_BASE_URL` is omitted, the app uses the production API:
`https://wholesellerbackend-production.up.railway.app/api/v1`.

For local development, set `API_BASE_URL` to your local API URL. For a release
build, the production URL is used by default; to override it:

```powershell
flutter build windows --release --dart-define=API_BASE_URL=https://wholesellerbackend-production.up.railway.app/api/v1
```

Owner accounts are provisioned privately by the API administrator. There is no
Owner sign-up option in the app. The GitHub Actions Windows workflow uses the
production URL by default; `PRODUCTION_API_BASE_URL` can override it. It
produces an installer artifact with the app and Visual C++ runtime.

See the repository README for API deployment, database, Owner provisioning,
and the Firebase data migration limitation.

See [FUNCTIONS_AND_LOGIC.md](./FUNCTIONS_AND_LOGIC.md) for a one-page list of
Owner app features and business logic.
