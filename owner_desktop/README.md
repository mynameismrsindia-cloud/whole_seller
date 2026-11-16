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
produces an installer artifact with the app and Visual C++ runtime. If the
signing secrets below are configured, it signs and verifies the app and
installer. Without them, the installer is unsigned and Smart App Control may
block it.

Windows Smart App Control may block unsigned installers. Before running the
Windows workflow, configure these repository Actions secrets with a trusted
Windows code-signing certificate issued by a certificate authority:

- `WINDOWS_SIGNING_CERTIFICATE`: the PFX/P12 certificate file encoded as one
  Base64 string.
- `WINDOWS_SIGNING_PASSWORD`: the certificate's password.

Create these secrets under **Settings > Secrets and variables > Actions**.
Never commit the certificate or share it in chat. Configure both secrets
together; the workflow rejects a partially configured certificate. Smart App
Control may still take time to establish reputation for a newly issued signing
certificate.

See the repository README for API deployment, database, Owner provisioning,
and the Firebase data migration limitation.

See [FUNCTIONS_AND_LOGIC.md](./FUNCTIONS_AND_LOGIC.md) for a one-page list of
Owner app features and business logic.
