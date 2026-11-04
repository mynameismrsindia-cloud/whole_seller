import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/product.dart';
import 'wholesale_api_client.dart';

final apiClientProvider = Provider<WholesaleApiClient>((ref) {
  final client = WholesaleApiClient(storageKey: 'seller_refresh_token');
  ref.onDispose(client.close);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider));
});

final apiRepositoryProvider = Provider<ApiRepository>((ref) {
  return ApiRepository(ref.read(apiClientProvider));
});

String appErrorMessage(Object error) => error.toString();

class ProductPage {
  const ProductPage(this.items, this.nextCursor);

  final List<Product> items;
  final String? nextCursor;
}

class AuthRepository {
  AuthRepository(this.api);

  final WholesaleApiClient api;

  Future<AppUser> login({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    final user = await api.login(email: email, password: password);
    return _validateRole(user, expectedRole);
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = await api.register(
      name: name,
      email: email,
      password: password,
    );
    return AppUser.fromJson(user);
  }

  Future<AppUser?> restore({required String expectedRole}) async {
    if (!await api.restoreSession()) return null;
    final user = api.currentUser;
    if (user == null || user['role'] != expectedRole) {
      await api.logout();
      return null;
    }
    return AppUser.fromJson(user);
  }

  Future<void> signOut() => api.logout();

  Future<AppUser> _validateRole(
    Map<String, dynamic> user,
    String expectedRole,
  ) async {
    if (user['role'] != expectedRole) {
      await api.logout();
      throw StateError(
        expectedRole == 'seller'
            ? 'This account does not have Seller access.'
            : 'This account does not have Owner access.',
      );
    }
    return AppUser.fromJson(user);
  }
}

class ApiRepository {
  ApiRepository(this.api);

  final WholesaleApiClient api;

  Future<AppUser> me() async => AppUser.fromJson(await api.profile());

  Future<AppUser> updateProfile({
    required String name,
    required String store,
    required String contact,
    required String location,
  }) async => AppUser.fromJson(
    await api.updateProfile(
      name: name,
      storeName: store,
      contact: contact,
      location: location,
    ),
  );

  Future<ProductPage> products({
    String query = '',
    String? cursor,
    bool forceRefresh = false,
  }) async {
    final page = await api.products(
      query: query,
      cursor: cursor,
      forceRefresh: forceRefresh,
    );
    return ProductPage(
      page.items.map(Product.fromJson).toList(growable: false),
      page.nextCursor,
    );
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
    await api.submitSale(
      requestId: requestId,
      productId: productId,
      quantity: quantity,
      rate: rate,
      store: store,
      contact: contact,
      location: location,
    );
  }

  void invalidateProducts() => api.invalidateProducts();
}
