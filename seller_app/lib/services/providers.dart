import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import '../models/product.dart';

const ownerEmail = 'mynameismrsindia@gmail.com';
final firebaseConfigured = Firebase.apps.isNotEmpty;

String appErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return error.message ?? 'Firebase sign-in failed (${error.code}).';
  }
  if (error is FirebaseException) {
    return error.message ?? 'Firebase error (${error.code}).';
  }
  if (error is StateError) return error.message;
  return error.toString();
}

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final firebaseRepositoryProvider = Provider<FirebaseRepository>((ref) {
  return FirebaseRepository(
    ref.read(firebaseAuthProvider),
    ref.read(firestoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(firebaseRepositoryProvider));
});

class AuthRepository {
  AuthRepository(this.repository);

  final FirebaseRepository repository;
  bool _initialized = false;

  Future<AppUser> signIn({required String expectedRole}) async {
    if (Platform.isWindows || Platform.isLinux) {
      throw StateError(
        'Google sign-in is currently supported on Android and macOS only.',
      );
    }

    final signIn = GoogleSignIn.instance;
    if (!_initialized) {
      await signIn.initialize();
      _initialized = true;
    }
    if (!signIn.supportsAuthenticate()) {
      throw StateError('Google sign-in is unavailable on this platform.');
    }

    final account = await signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google did not return an ID token. Check OAuth setup.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await repository.auth.signInWithCredential(credential);
    final firebaseUser = result.user;
    if (firebaseUser == null) {
      throw StateError('Firebase did not return a signed-in user.');
    }

    final user = await repository.loadOrCreateUser(firebaseUser);
    if (user.role != expectedRole) {
      await signOut();
      throw StateError(
        expectedRole == 'owner'
            ? 'This Google account is not configured as the owner.'
            : 'This account does not have salesman access.',
      );
    }
    return user;
  }

  Future<void> signOut() async {
    await repository.auth.signOut();
    if (_initialized) await GoogleSignIn.instance.signOut();
  }
}

class FirebaseRepository {
  FirebaseRepository(this.auth, this.firestore);

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  User get _currentUser {
    final user = auth.currentUser;
    if (user == null) throw StateError('Please sign in again.');
    return user;
  }

  Future<AppUser> loadOrCreateUser(User user) async {
    final userRef = firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    if (!snapshot.exists) {
      final email = user.email;
      if (email == null || !user.emailVerified) {
        throw StateError('Use a verified Google email to sign in.');
      }
      final role = email.toLowerCase() == ownerEmail.toLowerCase()
          ? 'owner'
          : 'seller';
      await userRef.set({
        'id': user.uid,
        'email': email,
        'name': user.displayName ?? '',
        'role': role,
        'storeName': '',
        'contact': '',
        'location': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return AppUser(
        id: user.uid,
        email: email,
        name: user.displayName ?? '',
        role: role,
      );
    }
    return AppUser.fromJson(snapshot.data()!);
  }

  Future<AppUser> me() async {
    final user = _currentUser;
    final snapshot = await firestore.collection('users').doc(user.uid).get();
    final data = snapshot.data();
    if (data == null) throw StateError('The Firebase profile was not found.');
    return AppUser.fromJson(data);
  }

  Future<AppUser> updateProfile({
    required String name,
    required String store,
    required String contact,
    required String location,
  }) async {
    await firestore.collection('users').doc(_currentUser.uid).update({
      'name': name,
      'storeName': store,
      'contact': contact,
      'location': location,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return me();
  }

  Future<List<Product>> products() async {
    final snapshot = await firestore
        .collection('products')
        .where('active', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((document) => Product.fromJson({
              ...document.data(),
              'id': document.id,
            }))
        .toList();
  }

  Future<void> submitSale({
    required String requestId,
    required String productId,
    required int quantity,
    required int rate,
    required String store,
    required String contact,
    required String location,
  }) async {
    if (quantity <= 0 || rate < 0) {
      throw StateError('Enter a valid quantity and rate.');
    }
    final user = _currentUser;
    final saleRef = firestore.collection('sales').doc(requestId);
    final productRef = firestore.collection('products').doc(productId);
    await firestore.runTransaction((transaction) async {
      final existing = await transaction.get(saleRef);
      if (existing.exists) {
        final sale = existing.data()!;
        final matches = sale['sellerId'] == user.uid &&
            sale['productId'] == productId &&
            sale['quantity'] == quantity &&
            sale['rate'] == rate &&
            sale['store'] == store &&
            sale['contact'] == contact &&
            sale['location'] == location;
        if (!matches) {
          throw StateError(
            'This sale request ID was already used for different data.',
          );
        }
        return;
      }

      final productSnapshot = await transaction.get(productRef);
      final product = productSnapshot.data();
      if (product == null) throw StateError('Product not found.');
      if (product['active'] != true) throw StateError('Product is inactive.');
      final stock = product['quantity'] as int;
      if (stock <= 0) throw StateError('Product is out of stock.');
      if (quantity > stock) {
        throw StateError('Only $stock units are remaining.');
      }
      final profile = await transaction.get(
        firestore.collection('users').doc(user.uid),
      );
      final profileData = profile.data();
      if (profileData == null || profileData['role'] != 'seller') {
        throw StateError('A seller account is required.');
      }

      transaction.update(productRef, {
        'quantity': stock - quantity,
        'lastSaleId': requestId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(saleRef, {
        'requestId': requestId,
        'sellerId': user.uid,
        'salesman': profileData['name'] ?? user.displayName ?? 'Salesman',
        'store': store,
        'contact': contact,
        'location': location,
        'productId': productId,
        'productName': product['name'],
        'quantity': quantity,
        'rate': rate,
        'totalAmount': quantity * rate,
        'createdAt': FieldValue.serverTimestamp(),
        'orderStatus': 'pending',
      });
    });
  }
}
