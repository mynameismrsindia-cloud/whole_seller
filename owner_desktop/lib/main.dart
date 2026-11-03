import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'models/app_user.dart';
import 'models/product.dart';
import 'screens/login_screen.dart';
import 'screens/products_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sales_list_screen.dart';
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
  runApp(const ProviderScope(child: OwnerApp()));
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

class OwnerApp extends ConsumerStatefulWidget {
  const OwnerApp({super.key});

  @override
  ConsumerState<OwnerApp> createState() => _OwnerAppState();
}

class _OwnerAppState extends ConsumerState<OwnerApp> {
  bool signedIn = false;
  int page = 0;
  String name = 'Store Owner';
  String store = 'Bandel Traders';
  String contact = '98765 43210';
  String location = 'Bandel, West Bengal';
  List<Product> products = DemoStore.products;
  List<Sale> sales = DemoStore.sales;
  bool loading = false;

  Future<void> _signInWithFirebase(AppUser user) async {
    setState(() => loading = true);
    try {
      final repository = ref.read(firebaseRepositoryProvider);
      final profile = await repository.me();
      final loadedProducts = await repository.products();
      final loadedSales = await repository.sales();
      if (!mounted) return;
      setState(() {
        name = profile.name.isEmpty ? user.name : profile.name;
        store = profile.storeName;
        contact = profile.contact;
        location = profile.location;
        products = loadedProducts;
        sales = loadedSales;
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

  Future<void> _runRemote(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
      }
    }
  }

  Future<void> _createProduct(Product product) async {
    if (!firebaseConfigured) {
      setState(() => DemoStore.products.insert(0, product));
      return;
    }
    await _runRemote(() async {
      await ref.read(firebaseRepositoryProvider).createProduct(product);
      final updated = await ref.read(firebaseRepositoryProvider).products();
      if (mounted) setState(() => products = updated);
    });
  }

  Future<void> _updateProduct(Product product, String newName) async {
    if (!firebaseConfigured) {
      setState(() => product.name = newName);
      return;
    }
    final oldName = product.name;
    product.name = newName;
    await _runRemote(() async {
      try {
        await ref.read(firebaseRepositoryProvider).updateProduct(
          product,
          newName,
        );
        final updated = await ref.read(firebaseRepositoryProvider).products();
        if (mounted) setState(() => products = updated);
      } catch (_) {
        product.name = oldName;
        rethrow;
      }
    });
  }

  Future<void> _restockProduct(Product product, int quantity) async {
    if (!firebaseConfigured) {
      setState(() => product.quantity += quantity);
      return;
    }
    await _runRemote(() async {
      await ref
          .read(firebaseRepositoryProvider)
          .restockProduct(product.id, quantity);
      final updated = await ref.read(firebaseRepositoryProvider).products();
      if (mounted) setState(() => products = updated);
    });
  }

  Future<void> _setProductActive(Product product, bool active) async {
    if (!firebaseConfigured) {
      setState(() => product.active = active);
      return;
    }
    final oldValue = product.active;
    product.active = active;
    await _runRemote(() async {
      try {
        await ref.read(firebaseRepositoryProvider).updateProduct(
          product,
          product.name,
        );
        final updated = await ref.read(firebaseRepositoryProvider).products();
        if (mounted) setState(() => products = updated);
      } catch (_) {
        product.active = oldValue;
        rethrow;
      }
    });
  }

  Future<void> _setSaleStatus(Sale sale, OrderStatus status) async {
    if (!firebaseConfigured) {
      setState(() => sale.orderStatus = status);
      return;
    }
    await _runRemote(() async {
      await ref
          .read(firebaseRepositoryProvider)
          .updateSaleStatus(sale, status);
      final updated = await ref.read(firebaseRepositoryProvider).sales();
      if (mounted) setState(() => sales = updated);
    });
  }

  String get _pageTitle => const [
    'Owner Workspace',
    'Sales Entries',
    'Profile',
  ][page.clamp(0, 2).toInt()];

  Widget _pageContent() => switch (page) {
    0 => ProductsScreen(
      products: products,
      onAdd: _createProduct,
      onUpdate: _updateProduct,
      onRestock: _restockProduct,
      onSetActive: _setProductActive,
    ),
    1 => SalesListScreen(sales: sales, onStatusChanged: _setSaleStatus),
    _ => ProfileScreen(
      name: name,
      store: store,
      contact: contact,
      location: location,
      onSaveRemote: firebaseConfigured
          ? (n, s, c, l) async {
              await ref
                  .read(firebaseRepositoryProvider)
                  .updateProfile(name: n, store: s, contact: c, location: l);
            }
          : null,
      onSave: (n, s, c, l) => setState(() {
        name = n;
        store = s;
        contact = c;
        location = l;
      }),
    ),
  };

  Widget _mobileWorkspace() => Scaffold(
    appBar: AppBar(
      title: Text(_pageTitle),
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
    body: page == 2
        ? _pageContent()
        : SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _pageContent(),
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page.clamp(0, 2).toInt(),
      onDestinationSelected: (index) => setState(() => page = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Products',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Sales',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );

  Widget _desktopWorkspace({required bool extended}) => Scaffold(
    body: Row(
      children: [
        NavigationRail(
          extended: extended,
          backgroundColor: const Color(0xFF004D46),
          selectedIndex: page.clamp(0, 2).toInt(),
          onDestinationSelected: (index) => setState(() => page = index),
          unselectedIconTheme: const IconThemeData(color: Colors.white70),
          selectedIconTheme: const IconThemeData(color: Colors.white),
          unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
          selectedLabelTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          leading: const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.inventory_2_outlined),
              label: Text('Products'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.receipt_long_outlined),
              label: Text('Sales Entries'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person_outline),
              label: Text('Profile'),
            ),
          ],
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: IconButton(
                tooltip: 'Sign out',
                onPressed: () {
                  if (firebaseConfigured) {
                    unawaited(ref.read(authRepositoryProvider).signOut());
                  }
                  setState(() => signedIn = false);
                },
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Container(
                height: 68,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      _pageTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const CircleAvatar(child: Icon(Icons.person_outline)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: page == 2
                    ? _pageContent()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _pageContent(),
                      ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Wholesale Owner',
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
        : loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth < 700
                  ? _mobileWorkspace()
                  : _desktopWorkspace(extended: constraints.maxWidth >= 1000);
            },
          ),
  );
}
