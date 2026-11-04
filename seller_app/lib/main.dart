import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_user.dart';
import 'models/product.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sales_entry_screen.dart';
import 'services/demo_store.dart';
import 'services/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SellerApp()));
}

class SellerApp extends ConsumerStatefulWidget {
  const SellerApp({super.key});

  @override
  ConsumerState<SellerApp> createState() => _SellerAppState();
}

class _SellerAppState extends ConsumerState<SellerApp> {
  bool signedIn = false;
  bool demoMode = false;
  bool restoringSession = true;
  int selectedTab = 0;
  String name = 'Rahul';
  String store = 'Bandel Traders';
  String contact = '98765 43210';
  String location = 'Bandel, West Bengal';
  List<Product> products = DemoStore.products;
  String? productCursor;
  String? loginError;
  bool loading = false;
  int _productLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .restore(expectedRole: 'seller');
      if (user != null && mounted) await _signInWithApi(user);
    } catch (error) {
      if (mounted) setState(() => loginError = appErrorMessage(error));
    } finally {
      if (mounted) setState(() => restoringSession = false);
    }
  }

  Future<void> _signInWithApi(AppUser user) async {
    setState(() => loading = true);
    try {
      final repository = ref.read(apiRepositoryProvider);
      final profile = await repository.me();
      final page = await repository.products(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        name = profile.name.isEmpty ? user.name : profile.name;
        store = profile.storeName;
        contact = profile.contact;
        location = profile.location;
        products = page.items;
        productCursor = page.nextCursor;
        demoMode = false;
        signedIn = true;
      });
    } catch (error) {
      if (mounted) {
        await ref.read(authRepositoryProvider).signOut();
        setState(() => loginError = appErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signOut() async {
    if (!demoMode) {
      try {
        await ref.read(authRepositoryProvider).signOut();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
        }
      }
    }
    if (mounted) {
      setState(() {
        signedIn = false;
        demoMode = false;
      });
    }
  }

  Future<void> _loadProducts({
    String query = '',
    String? cursor,
    bool append = false,
  }) async {
    final generation = ++_productLoadGeneration;
    final page = await ref
        .read(apiRepositoryProvider)
        .products(query: query, cursor: cursor, forceRefresh: true);
    if (!mounted || generation != _productLoadGeneration) return;
    setState(() {
      products = append ? [...products, ...page.items] : page.items;
      productCursor = page.nextCursor;
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Wholesale Seller',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00665D)),
      scaffoldBackgroundColor: const Color(0xFFF3F6F9),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF004D46),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
    home: restoringSession
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : !signedIn
        ? LoginScreen(
            initialError: loginError,
            onContinue: () => setState(() {
              demoMode = true;
              signedIn = true;
            }),
            onAuthenticated: _signInWithApi,
          )
        : Scaffold(
            appBar: AppBar(
              title: Text(selectedTab == 0 ? 'New Sales Entry' : 'My Profile'),
              actions: [
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            body: loading
                ? const Center(child: CircularProgressIndicator())
                : selectedTab == 0
                ? SalesEntryScreen(
                    name: name,
                    store: store,
                    contact: contact,
                    location: location,
                    products: demoMode ? null : products,
                    onSearchProducts: demoMode
                        ? null
                        : (query) => _loadProducts(query: query),
                    onRefreshProducts: demoMode ? null : () => _loadProducts(),
                    onSubmitSale: demoMode
                        ? null
                        : ({
                            required String requestId,
                            required Product product,
                            required int quantity,
                            required int rate,
                            required String store,
                            required String contact,
                            required String location,
                          }) async {
                            final repository = ref.read(apiRepositoryProvider);
                            await repository.submitSale(
                              requestId: requestId,
                              productId: product.id,
                              quantity: quantity,
                              rate: rate,
                              store: store,
                              contact: contact,
                              location: location,
                            );
                            final page = await repository.products(
                              forceRefresh: true,
                            );
                            products = page.items;
                            productCursor = page.nextCursor;
                            if (mounted) setState(() {});
                            return products;
                          },
                    onStoreChanged: (s, c, l) => setState(() {
                      store = s;
                      contact = c;
                      location = l;
                    }),
                  )
                : ProfileScreen(
                    name: name,
                    store: store,
                    contact: contact,
                    location: location,
                    onSaveRemote: !demoMode
                        ? (n, s, c, l) async {
                            await ref
                                .read(apiRepositoryProvider)
                                .updateProfile(
                                  name: n,
                                  store: s,
                                  contact: c,
                                  location: l,
                                );
                          }
                        : null,
                    onSave: (n, s, c, l) => setState(() {
                      name = n;
                      store = s;
                      contact = c;
                      location = l;
                    }),
                  ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedTab,
              onDestinationSelected: (index) {
                if (index < 0 || index > 1 || index == selectedTab) return;
                setState(() => selectedTab = index);
                if (index == 0 && !demoMode) unawaited(_loadProducts());
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.add_box_outlined),
                  label: 'New Entry',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            ),
          ),
  );
}
