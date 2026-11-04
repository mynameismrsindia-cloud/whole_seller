# Wholesale Manager

The Seller Android and Owner Flutter apps use the NestJS API in `api/` and
PostgreSQL. Each app keeps its own API client under its `lib/services/` folder.
Firebase is no longer used by the app builds. The existing remote Firebase
project and its data have not been deleted or modified.

## Run the API locally

Requirements: Node.js 20+, npm, and PostgreSQL 15+.

```sh
createdb wholesale
cd api
npm ci
cp .env.example .env
```

Set `DATABASE_URL` in `api/.env` to a PostgreSQL role/database you control.
Generate `JWT_ACCESS_SECRET` with `openssl rand -base64 48`; do not commit
`api/.env`. Apply migrations and start the API:

```sh
npm run migrate
npm run start:dev
```

The API listens on port 3000 under `/api/v1`. Use HTTPS for deployed API
endpoints. Configure TLS at the hosting/reverse-proxy layer and set
`DATABASE_SSL=true` when the PostgreSQL provider requires TLS.

### Provision the Owner account

Public registration only creates Sellers. After migrating the database, run
the one-time CLI with an administrator-controlled Owner email/name and a
password of at least 14 characters:

```sh
cd api
read -r OWNER_EMAIL
read -r OWNER_NAME
read -rs OWNER_PASSWORD
export OWNER_EMAIL OWNER_NAME OWNER_PASSWORD
npm run owner:create
unset OWNER_EMAIL OWNER_NAME OWNER_PASSWORD
```

The password is Argon2id-hashed. Owner creation refuses an already-used email;
there is no public Owner registration route.

## Run the apps

Both apps use `API_BASE_URL` as a Dart define. For local development, the
default is `http://10.0.2.2:3000/api/v1` on Android emulators and
`http://127.0.0.1:3000/api/v1` on desktop. Override it explicitly when needed.
Production builds must use the HTTPS API URL:

```sh
cd seller_app
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter analyze
flutter test
```

```sh
cd owner_desktop
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter build windows --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter analyze
flutter test
```

The Owner Windows workflow prompts for `production` (default) or `localhost`.
For production, set the `PRODUCTION_API_BASE_URL` repository variable (or the
legacy `API_BASE_URL`) under **Settings → Secrets and variables → Actions →
Variables** to the HTTPS API URL. A localhost installer connects only to the
API running on that same Windows PC at `127.0.0.1:3000`; do not distribute it
to production users. Release builds reject plain HTTP URLs other than
localhost.

## API security and data behavior

- Seller sign-up accepts name, email, and password and always provisions the
  `seller` role. Owner accounts are created only with the private CLI.
- Passwords use Argon2id. Short-lived JWT access tokens are paired with rotating
  opaque refresh tokens; refresh tokens are hashed in PostgreSQL and stored by
  the apps in platform secure storage.
- Backend role guards protect Owner inventory/status actions. Sales update stock
  with a conditional SQL update in the same transaction as the sale record.
  Insufficient stock is rejected; an idempotency key prevents duplicate sale
  deductions.
- Product and sales endpoints use indexed, cursor-paginated queries capped at
  100 records. Product pages are cached in each app for 30 seconds, invalidated
  on mutations, and refreshed on screen entry/manual refresh. Product search is
  debounced.

## Existing Firebase data

The current Firebase project is suspended, so its Firestore records could not
be exported or migrated during this change. No data migration has been run.
The remote Firebase project and data remain untouched, but are not copied into
PostgreSQL; arrange an authorized export/import before switching production
users to this API. Do not delete the Firebase project or its data as part of
this migration.
