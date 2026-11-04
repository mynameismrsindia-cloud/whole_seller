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
    late final UserCredential result;
    if (Platform.isWindows) {
      result = await repository.auth.signInWithProvider(GoogleAuthProvider());
    } else {
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
        throw StateError(
          'Google did not return an ID token. Check OAuth setup.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      result = await repository.auth.signInWithCredential(credential);
    }
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

  bool get _isOwner =>
      _currentUser.email?.toLowerCase() == ownerEmail.toLowerCase();

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
    Query<Map<String, dynamic>> query = firestore
        .collection('products')
        .orderBy('createdAt', descending: true);
    if (!_isOwner) query = query.where('active', isEqualTo: true);
    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (document) =>
              Product.fromJson({...document.data(), 'id': document.id}),
        )
        .toList();
  }

  Future<Product> createProduct(Product product) async {
    if (product.id.trim().isEmpty || product.id.contains('/')) {
      throw StateError('Enter a product ID without a slash.');
    }
    if (product.name.trim().isEmpty || product.quantity < 0) {
      throw StateError('Enter a product name and non-negative quantity.');
    }
    await firestore.collection('products').doc(product.id).set({
      'id': product.id,
      'name': product.name,
      'quantity': product.quantity,
      'active': product.active,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return product;
  }

  Future<void> updateProduct(Product product, String name) async {
    await firestore.collection('products').doc(product.id).update({
      'name': name,
      'active': product.active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> restockProduct(String id, int quantity) async {
    if (quantity <= 0) throw StateError('Restock quantity must be positive.');
    final productRef = firestore.collection('products').doc(id);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(productRef);
      final product = snapshot.data();
      if (product == null) throw StateError('Product not found.');
      transaction.update(productRef, {
        'quantity': (product['quantity'] as int) + quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<Sale>> sales({DateTime? start, DateTime? end}) async {
    Query<Map<String, dynamic>> query = firestore
        .collection('sales')
        .orderBy('createdAt', descending: true);
    if (start != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start.toUtc()),
      );
    }
    if (end != null) {
      query = query.where(
        'createdAt',
        isLessThan: Timestamp.fromDate(end.toUtc()),
      );
    }
    final snapshot = await query.get();
    return snapshot.docs.map((document) {
      final data = document.data();
      final createdAt = data['createdAt'];
      return Sale.fromJson({
        ...data,
        'id': document.id,
        'createdAt': createdAt is Timestamp
            ? createdAt.toDate().toIso8601String()
            : createdAt?.toString(),
      });
    }).toList();
  }

  Future<void> updateSaleStatus(Sale sale, OrderStatus status) async {
    if (sale.orderStatus != OrderStatus.pending ||
        status != OrderStatus.approved) {
      throw StateError('An order can only be approved once.');
    }
    await firestore.collection('sales').doc(sale.id).update({
      'orderStatus': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
