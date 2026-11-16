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
Owner sign-up option in the app. The existing
`.github/workflows/build-owner-windows.yml` workflow builds the Inno Setup
installer. The separate `.github/workflows/build-owner-msix.yml` workflow builds
a Store-submission MSIX on a Windows runner; it uses the production API URL by
default, and `PRODUCTION_API_BASE_URL` can override it. Its package identity is
`PushpenduDas.WholeSalerOwnerPackage`, published by
`CN=84FCF719-D297-45CF-B542-80907008BEBC`.

The MSIX workflow creates an unsigned package for Partner Center submission;
Microsoft Store signs packages distributed through the Store. GitHub Actions
only builds an artifact and does not submit or publish it. Customers receive
automatic app updates through Microsoft Store after you submit and publish
each new version there. Increase the Store package version with each release;
the workflow uses its monotonically increasing GitHub run number for that
version. Existing users of the separate Inno Setup installation must install
the Store version once; Store updates apply to the Store-installed package.

To create and download an MSIX, push the changes to GitHub and open
**Actions → Build Owner MSIX for Microsoft Store → Run workflow**, select
`production`, and run it. After the run succeeds, download the
`owner-desktop-msix-<run number>` artifact. The workflow unpacks the MSIX to
validate its manifest identity, version, architecture, and referenced images.
Upload the `.msix` file from the downloaded artifact to the app's **Packages**
page in Partner Center; then complete the listing and submission steps there.

The executable is unsigned for private testing. Windows Smart App Control may
still block new or unrecognized builds because they have no publisher
signature or established reputation.

See the repository README for API deployment, database, Owner provisioning,
and the Firebase data migration limitation.

See [FUNCTIONS_AND_LOGIC.md](./FUNCTIONS_AND_LOGIC.md) for a one-page list of
Owner app features and business logic.
