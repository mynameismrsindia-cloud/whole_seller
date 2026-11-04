import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  runApp(const ProviderScope(child: OwnerApp()));
}

class OwnerApp extends ConsumerStatefulWidget {
  const OwnerApp({super.key});

  @override
  ConsumerState<OwnerApp> createState() => _OwnerAppState();
}

class _OwnerAppState extends ConsumerState<OwnerApp> {
  bool signedIn = false;
  bool demoMode = false;
  bool restoringSession = true;
  int page = 0;
  String name = 'Store Owner';
  String store = 'Bandel Traders';
  String contact = '98765 43210';
  String location = 'Bandel, West Bengal';
  List<Product> products = DemoStore.products;
  List<Sale> sales = DemoStore.sales;
  String? productCursor;
  String? salesCursor;
  DateTimeRange? salesRange;
  String activeProductQuery = '';
  String? loginError;
  bool loading = false;
  int _productLoadGeneration = 0;
  int _salesLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .restore(expectedRole: 'owner');
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
      final productPage = await repository.products(forceRefresh: true);
      final salePage = await repository.sales();
      if (!mounted) return;
      setState(() {
        name = profile.name.isEmpty ? user.name : profile.name;
        store = profile.storeName;
        contact = profile.contact;
        location = profile.location;
        products = productPage.items;
        productCursor = productPage.nextCursor;
        sales = salePage.items;
        salesCursor = salePage.nextCursor;
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
    bool forceRefresh = true,
  }) async {
    final generation = ++_productLoadGeneration;
    if (!append) activeProductQuery = query;
    final loaded = await ref
        .read(apiRepositoryProvider)
        .products(query: query, cursor: cursor, forceRefresh: forceRefresh);
    if (!mounted || generation != _productLoadGeneration) return;
    setState(() {
      products = append ? [...products, ...loaded.items] : loaded.items;
      productCursor = loaded.nextCursor;
    });
  }

  Future<void> _loadSales({
    DateTimeRange? range,
    String? cursor,
    bool append = false,
  }) async {
    final generation = ++_salesLoadGeneration;
    final start = range == null
        ? null
        : DateTime(range.start.year, range.start.month, range.start.day);
    final end = range == null
        ? null
        : DateTime(range.end.year, range.end.month, range.end.day + 1);
    final loaded = await ref
        .read(apiRepositoryProvider)
        .sales(start: start, end: end, cursor: cursor);
    if (!mounted || generation != _salesLoadGeneration) return;
    setState(() {
      sales = append ? [...sales, ...loaded.items] : loaded.items;
      salesCursor = loaded.nextCursor;
      salesRange = range;
    });
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
    if (demoMode) {
      setState(() => DemoStore.products.insert(0, product));
      return;
    }
    await _runRemote(() async {
      await ref.read(apiRepositoryProvider).createProduct(product);
      await _loadProducts(forceRefresh: true);
    });
  }

  Future<void> _updateProduct(Product product, String newName) async {
    if (demoMode) {
      setState(() => product.name = newName);
      return;
    }
    final oldName = product.name;
    product.name = newName;
    await _runRemote(() async {
      try {
        await ref.read(apiRepositoryProvider).updateProduct(product, newName);
        await _loadProducts(forceRefresh: true);
      } catch (_) {
        product.name = oldName;
        rethrow;
      }
    });
  }

  Future<void> _restockProduct(Product product, int quantity) async {
    if (demoMode) {
      setState(() => product.quantity += quantity);
      return;
    }
    await _runRemote(() async {
      await ref
          .read(apiRepositoryProvider)
          .restockProduct(product.id, quantity);
      await _loadProducts(forceRefresh: true);
    });
  }

  Future<void> _setProductActive(Product product, bool active) async {
    if (demoMode) {
      setState(() => product.active = active);
      return;
    }
    final oldValue = product.active;
    product.active = active;
    await _runRemote(() async {
      try {
        await ref
            .read(apiRepositoryProvider)
            .updateProduct(product, product.name);
        await _loadProducts(forceRefresh: true);
      } catch (_) {
        product.active = oldValue;
        rethrow;
      }
    });
  }

  Future<void> _setSaleStatus(Sale sale, OrderStatus status) async {
    if (demoMode) {
      setState(() => sale.orderStatus = status);
      return;
    }
    await _runRemote(() async {
      await ref.read(apiRepositoryProvider).updateSaleStatus(sale, status);
      await _loadSales(range: salesRange);
    });
  }

  String get _pageTitle => const [
    'Owner Workspace',
    'Sales Entries',
    'Profile',
  ][page.clamp(0, 2).toInt()];

  void _selectPage(int selected) {
    if (selected < 0 || selected > 2 || selected == page) return;
    setState(() => page = selected);
    if (demoMode) return;
    if (selected == 0) {
      unawaited(_loadProducts(forceRefresh: true));
    } else if (selected == 1) {
      unawaited(_loadSales(range: salesRange));
    }
  }

  Widget _pageContent() => switch (page) {
    0 => ProductsScreen(
      products: products,
      onAdd: _createProduct,
      onUpdate: _updateProduct,
      onRestock: _restockProduct,
      onSetActive: _setProductActive,
      onSearch: demoMode ? null : (query) => _loadProducts(query: query),
      onLoadMore: productCursor == null
          ? null
          : () => _loadProducts(
              query: activeProductQuery,
              cursor: productCursor,
              append: true,
              forceRefresh: false,
            ),
      onRefresh: demoMode ? null : () => _loadProducts(forceRefresh: true),
    ),
    1 => SalesListScreen(
      sales: sales,
      onStatusChanged: _setSaleStatus,
      initialRange: salesRange,
      hasMore: salesCursor != null,
      onRangeChanged: (range) => _loadSales(range: range),
      onLoadMore: salesCursor == null
          ? null
          : () => _loadSales(
              range: salesRange,
              cursor: salesCursor,
              append: true,
            ),
      onRefresh: () => _loadSales(range: salesRange),
    ),
    _ => ProfileScreen(
      name: name,
      store: store,
      contact: contact,
      location: location,
      onSaveRemote: !demoMode
          ? (n, s, c, l) async {
              await ref
                  .read(apiRepositoryProvider)
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
          onPressed: _signOut,
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
      onDestinationSelected: _selectPage,
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
          onDestinationSelected: _selectPage,
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
                onPressed: _signOut,
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
