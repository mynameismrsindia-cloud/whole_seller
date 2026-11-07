import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_user.dart';
import 'models/product.dart';
import 'screens/login_screen.dart';
import 'screens/products_screen.dart';
import 'screens/sales_list_screen.dart';
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
  bool restoringSession = true;
  int page = 0;
  String name = 'Store Owner';
  String email = '';
  List<Product> products = [];
  List<Sale> sales = [];
  String? productCursor;
  String? salesCursor;
  DateTimeRange? salesRange;
  String activeProductQuery = '';
  String? loginError;
  bool loading = false;
  int _productLoadGeneration = 0;
  int _salesLoadGeneration = 0;
  final _desktopVerticalController = ScrollController();
  final _desktopHorizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  @override
  void dispose() {
    _desktopVerticalController.dispose();
    _desktopHorizontalController.dispose();
    super.dispose();
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
      final productPage = await repository.products(forceRefresh: true);
      final salePage = await repository.sales();
      if (!mounted) return;
      setState(() {
        name = user.name.isEmpty ? user.email : user.name;
        email = user.email;
        products = productPage.items;
        productCursor = productPage.nextCursor;
        sales = salePage.items;
        salesCursor = salePage.nextCursor;
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
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
      }
    }
    if (mounted) {
      setState(() {
        signedIn = false;
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
        : DateTime.utc(
            range.start.year,
            range.start.month,
            range.start.day,
          ).subtract(const Duration(hours: 5, minutes: 30));
    final end = range == null
        ? null
        : DateTime.utc(
            range.end.year,
            range.end.month,
            range.end.day + 1,
          ).subtract(const Duration(hours: 5, minutes: 30));
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
    await _runRemote(() async {
      await ref.read(apiRepositoryProvider).createProduct(product);
      await _loadProducts(forceRefresh: true);
    });
  }

  Future<void> _updateProduct(Product product, String newName) async {
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
    await _runRemote(() async {
      await ref
          .read(apiRepositoryProvider)
          .restockProduct(product.id, quantity);
      await _loadProducts(forceRefresh: true);
    });
  }

  Future<void> _setProductActive(Product product, bool active) async {
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
    await _runRemote(() async {
      await ref.read(apiRepositoryProvider).updateSaleStatus(sale, status);
      if (mounted) setState(() => sale.orderStatus = status);
    });
  }

  String get _pageTitle =>
      const ['Owner Workspace', 'Sales Entries'][page.clamp(0, 1).toInt()];

  void _selectPage(int selected) {
    if (selected < 0 || selected > 1 || selected == page) return;
    setState(() => page = selected);
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
      onSearch: (query) => _loadProducts(query: query),
      onLoadMore: productCursor == null
          ? null
          : () => _loadProducts(
              query: activeProductQuery,
              cursor: productCursor,
              append: true,
              forceRefresh: false,
            ),
      onRefresh: () => _loadProducts(forceRefresh: true),
    ),
    _ => SalesListScreen(
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
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: _pageContent(),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page.clamp(0, 1).toInt(),
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
      ],
    ),
  );

  Widget _desktopWorkspace({required bool extended}) => Scaffold(
    body: Row(
      children: [
        NavigationRail(
          extended: extended,
          backgroundColor: const Color(0xFF004D46),
          selectedIndex: page.clamp(0, 1).toInt(),
          onDestinationSelected: _selectPage,
          unselectedIconTheme: const IconThemeData(color: Colors.white70),
          selectedIconTheme: const IconThemeData(color: Colors.white),
          unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
          selectedLabelTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              width: 176,
              height: 82,
              child: Image.asset('assets/bonzar_logo.png', fit: BoxFit.contain),
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
          ],
          trailing: Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/bonzar_logo.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 184,
                    child: FilledButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Log out'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF004D46),
                      ),
                    ),
                  ),
                ],
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
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Scrollbar(
                    controller: _desktopVerticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _desktopVerticalController,
                      child: Scrollbar(
                        controller: _desktopHorizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) =>
                            notification.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _desktopHorizontalController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: constraints.maxWidth < 1000
                                ? 1000
                                : constraints.maxWidth,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: _pageContent(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
        ? LoginScreen(initialError: loginError, onAuthenticated: _signInWithApi)
        : loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth < 700
                  ? _mobileWorkspace()
                  : _desktopWorkspace(extended: true);
            },
          ),
  );
}
