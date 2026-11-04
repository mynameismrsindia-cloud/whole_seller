import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/product.dart';
import 'wholesale_api_client.dart';

final apiClientProvider = Provider<WholesaleApiClient>((ref) {
  final client = WholesaleApiClient(storageKey: 'owner_refresh_token');
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

class SalePage {
  const SalePage(this.items, this.nextCursor);

  final List<Sale> items;
  final String? nextCursor;
}

class AuthRepository {
  AuthRepository(this.api);

  final WholesaleApiClient api;

  Future<AppUser> signIn({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    final user = await api.login(email: email, password: password);
    if (user['role'] != expectedRole) {
      await api.logout();
      throw StateError(
        expectedRole == 'owner'
            ? 'This account does not have Owner access.'
            : 'This account does not have Seller access.',
      );
    }
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

  Future<void> createProduct(Product product) async {
    await api.createProduct({
      'id': product.id,
      'name': product.name,
      'quantity': product.quantity,
      'active': product.active,
    });
  }

  Future<void> updateProduct(Product product, String name) =>
      api.updateProduct(product.id, name: name, active: product.active);

  Future<void> restockProduct(String id, int quantity) =>
      api.restockProduct(id, quantity);

  Future<SalePage> sales({
    DateTime? start,
    DateTime? end,
    String? cursor,
  }) async {
    final page = await api.sales(
      start: start?.toUtc().toIso8601String(),
      end: end?.toUtc().toIso8601String(),
      cursor: cursor,
    );
    return SalePage(
      page.items.map(Sale.fromJson).toList(growable: false),
      page.nextCursor,
    );
  }

  Future<void> updateSaleStatus(Sale sale, OrderStatus status) async {
    if (status != OrderStatus.approved) {
      throw StateError('A sale can only be approved.');
    }
    await api.approveSale(sale.id);
  }

  void invalidateProducts() => api.invalidateProducts();
}
