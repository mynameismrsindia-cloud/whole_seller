import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'models/app_user.dart';
import 'models/product.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sales_entry_screen.dart';
import 'services/demo_store.dart';
import 'services/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace),
    );
    runApp(_FirebaseSetupErrorApp(error: error));
    return;
  }
  runApp(const ProviderScope(child: SellerApp()));
}

class _FirebaseSetupErrorApp extends StatelessWidget {
  const _FirebaseSetupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            'Firebase setup failed. Configure this app with FlutterFire, '
            'then restart it.\n\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

class SellerApp extends ConsumerStatefulWidget {
  const SellerApp({super.key});

  @override
  ConsumerState<SellerApp> createState() => _SellerAppState();
}

class _SellerAppState extends ConsumerState<SellerApp> {
  bool signedIn = false;
  int selectedTab = 0;
  String name = 'Rahul';
  String store = 'Bandel Traders';
  String contact = '98765 43210';
  String location = 'Bandel, West Bengal';
  List<Product> products = DemoStore.products;
  bool loading = false;

  Future<void> _signInWithFirebase(AppUser user) async {
    setState(() => loading = true);
    try {
      final repository = ref.read(firebaseRepositoryProvider);
      final profile = await repository.me();
      final loadedProducts = await repository.products();
      if (!mounted) return;
      setState(() {
        name = profile.name.isEmpty ? user.name : profile.name;
        store = profile.storeName;
        contact = profile.contact;
        location = profile.location;
        products = loadedProducts;
        signedIn = true;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
    home: !signedIn
        ? LoginScreen(
            onContinue: () => setState(() => signedIn = true),
            onAuthenticated: _signInWithFirebase,
          )
        : Scaffold(
            appBar: AppBar(
              title: Text(selectedTab == 0 ? 'New Sales Entry' : 'My Profile'),
              actions: [
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: () {
                    if (firebaseConfigured) {
                      unawaited(ref.read(authRepositoryProvider).signOut());
                    }
                    setState(() => signedIn = false);
                  },
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
                    products: firebaseConfigured ? products : null,
                    onSubmitSale: firebaseConfigured
                        ? ({
                            required String requestId,
                            required Product product,
                            required int quantity,
                            required int rate,
                            required String store,
                            required String contact,
                            required String location,
                          }) async {
                            final repository = ref.read(
                              firebaseRepositoryProvider,
                            );
                            await repository.submitSale(
                              requestId: requestId,
                              productId: product.id,
                              quantity: quantity,
                              rate: rate,
                              store: store,
                              contact: contact,
                              location: location,
                            );
                            products = await repository.products();
                            if (mounted) setState(() {});
                            return products;
                          }
                        : null,
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
                    onSaveRemote: firebaseConfigured
                        ? (n, s, c, l) async {
                            await ref
                                .read(firebaseRepositoryProvider)
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
              onDestinationSelected: (index) =>
                  setState(() => selectedTab = index),
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
