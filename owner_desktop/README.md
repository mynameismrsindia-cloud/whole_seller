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

To create a Windows release from a non-Windows computer, push the project to
GitHub, open **Actions → Build owner Windows app → Run workflow**, then
download the `owner-desktop-windows-x64` artifact. Extract it on Windows and
run `owner_desktop.exe`; keep the bundled DLL and `data` directory beside it.

Firebase app configuration is in `lib/firebase_options.dart` and
`android/app/google-services.json`.
