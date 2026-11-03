# Owner Desktop

Owner app for inventory, restocking, sales review, order approval, and profile
management. Firebase Authentication with Google and Cloud Firestore are already
configured for project `wholesale-mrsindia-2026`; no Node.js API or MySQL is
required.

The owner account is `mynameismrsindia@gmail.com`. From the repository root,
deploy updated Firestore rules/indexes with:

```sh
firebase deploy --only firestore --project=wholesale-mrsindia-2026
```

```sh
flutter pub get
flutter run -d windows
flutter build windows
flutter run -d <android-device>
flutter build apk
flutter test
```

Firebase app configuration is in `lib/firebase_options.dart` and
`android/app/google-services.json`.
