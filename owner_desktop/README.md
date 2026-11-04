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

To create a Windows installer from a non-Windows computer, push the project to
GitHub, open **Actions → Build owner Windows app → Run workflow**, then download
the `owner-desktop-Setup` artifact. Run `owner-desktop-Setup.exe` on Windows.
It installs the complete app bundle, creates Start Menu and Desktop shortcuts,
and installs Microsoft's signed Visual C++ x64 Redistributable when the
required version is missing. If the runtime requires a restart, Setup will
prompt to restart Windows. The app can then be opened from either shortcut.

Firebase app configuration is in `lib/firebase_options.dart` and
`android/app/google-services.json`.
