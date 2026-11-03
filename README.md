# Wholesale Manager

The owner and seller Flutter apps use Firebase Authentication and Cloud
Firestore directly. Node.js/NestJS and MySQL are not required.

- [Owner desktop app](owner_desktop/README.md): Windows desktop and Android.
- [Seller app](seller_app/README.md): Android.

## Firebase project

The Firebase project is configured: `wholesale-mrsindia-2026`.

- Google sign-in is enabled.
- Firestore is created in Mumbai (`asia-south1`).
- Firestore security rules and indexes are deployed.
- Owner: verified Google account `mynameismrsindia@gmail.com`.
- Other verified Google accounts are sellers.

The Firebase app configuration is in each app's `lib/firebase_options.dart`
and Android `google-services.json`. The Android debug/release signing SHA-1 is
registered for both apps. The owner app is configured for Android and Windows.

Run the apps:

```sh
cd owner_desktop && flutter run -d windows
cd seller_app && flutter run
```

The owner signs in first and adds products; sellers can then submit sales.
Firestore transactions check and decrement stock atomically.

To redeploy rules/indexes after changing them, use the Firebase CLI while
signed in to the owner account:

```sh
firebase deploy --only firestore --project=wholesale-mrsindia-2026
```

Never commit Firebase service-account keys or share Google passwords.
