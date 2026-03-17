import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/graphql/graphql_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/cart/cart_provider.dart';

// ── Screens ────────────────────────────────────────────────
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/products/screens/home_screen.dart';
import 'features/products/screens/product_list_screen.dart';
import 'features/products/screens/product_detail_screen.dart';
import 'features/cart/screens/cart_screen.dart';
import 'features/checkout/screens/checkout_screen.dart';
import 'features/orders/screens/order_list_screen.dart';
import 'features/orders/screens/order_detail_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/vendor/screens/vendor_dashboard_screen.dart';
import 'features/vendor/screens/vendor_products_screen.dart';
import 'features/vendor/screens/vendor_orders_screen.dart';
import 'features/vendor/screens/vendor_add_product_screen.dart';
import 'features/vendor/screens/vendor_onboarding_screen.dart';
import 'features/vendor/screens/vendor_pending_approval_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/admin/screens/admin_vendor_approvals_screen.dart';
import 'features/admin/screens/admin_carousel_screen.dart';
import 'features/admin/screens/admin_categories_screen.dart';
import 'features/admin/screens/admin_coupons_screen.dart';
import 'features/admin/screens/admin_reports_screen.dart';
import 'features/admin/screens/admin_product_moderation_screen.dart';
import 'widgets/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Run app immediately — splash renders while heavy init runs in background.
  runApp(const _BootstrapApp());
}

/// Renders a branded splash while dotenv + Supabase init runs async,
/// then replaces itself with [ArekitaApp]. This keeps timeAfterFrameworkInit
/// near zero by not blocking runApp() on network/disk calls.
class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<void> _init = _doInit();

  Future<void> _doInit() async {
    await dotenv.load(fileName: '.env');
    AppConstants.validateEnvVars();
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    GraphQLService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Text(
                  'Startup error:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _SplashScreen(),
          );
        }
        return const ArekitaApp();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArekitaApp extends StatelessWidget {
  const ArekitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: GraphQLProvider(
        client: GraphQLService.instance.client,
        child: MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system, // Follow system dark/light mode
          // Always start on home — sign-in lives in Profile tab
          initialRoute: '/',
          onGenerateRoute: _onGenerateRoute,
        ),
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    Widget page;
    bool showShell = false;
    int shellIndex = 0;

    switch (settings.name) {
      // ── Auth ──────────────────────────────────────────
      case '/login':
        page = const LoginScreen();
      case '/register':
        page = const RegisterScreen();

      // ── Main Tabs ─────────────────────────────────────
      case '/':
        page = const HomeScreen();
        showShell = true;
        shellIndex = 0;
      case '/products':
        page = const ProductListScreen();
        showShell = true;
        shellIndex = 1;
      case '/cart':
        page = const _ClientGuard(child: CartScreen());
        showShell = true;
        shellIndex = 2;
      case '/orders':
        page = const _ClientGuard(child: OrderListScreen());
        showShell = true;
        shellIndex = 3;
      case '/profile':
        page = const ProfileScreen();
        showShell = true;
        shellIndex = 4;

      // ── Product Detail ────────────────────────────────
      case '/product':
        final productId = settings.arguments as String;
        page = ProductDetailScreen(productId: productId);

      // ── Checkout ──────────────────────────────────────
      case '/checkout':
        page = const _ClientGuard(child: CheckoutScreen());

      // ── Order Detail ──────────────────────────────────
      case '/order':
        final orderId = settings.arguments as String;
        page = OrderDetailScreen(orderId: orderId);

      // ── Vendor Routes ─────────────────────────────────
      case '/vendor/dashboard':
        page = const _ApprovedVendorGuard(child: VendorDashboardScreen());
        showShell = true;
        shellIndex = 0;
      case '/vendor/products':
        page = const _ApprovedVendorGuard(child: VendorProductsScreen());
        showShell = true;
        shellIndex = 1;
      case '/vendor/products/add':
        page = const _ApprovedVendorGuard(child: VendorAddProductScreen());
      case '/vendor/orders':
        page = const _ApprovedVendorGuard(child: VendorOrdersScreen());
        showShell = true;
        shellIndex = 2;
      case '/vendor/onboarding':
        page = const _VendorGuard(child: VendorOnboardingScreen());
      case '/vendor/profile':
        page = const _VendorGuard(child: VendorPendingApprovalScreen());
        showShell = true;
        shellIndex = 3;

      // ── Admin Routes ──────────────────────────────────
      case '/admin/dashboard':
        page = const _AdminGuard(child: AdminDashboardScreen());
      case '/admin/vendors':
        page = const _AdminGuard(child: AdminVendorApprovalsScreen());
      case '/admin/products/moderation':
        page = const _AdminGuard(child: AdminProductModerationScreen());
      case '/admin/carousels':
        page = const _AdminGuard(child: AdminCarouselScreen());
      case '/admin/categories':
        page = const _AdminGuard(child: AdminCategoriesScreen());
      case '/admin/coupons':
        page = const _AdminGuard(child: AdminCouponsScreen());
      case '/admin/reports':
        page = const _AdminGuard(child: AdminReportsScreen());

      default:
        page = const Scaffold(
          body: Center(child: Text('404 — Page not found')),
        );
    }

    final Widget finalPage = showShell
        ? MainShell(currentIndex: shellIndex, child: page)
        : page;

    return MaterialPageRoute(builder: (_) => finalPage, settings: settings);
  }
}

/// Requires: Authenticated + Client role
class _ClientGuard extends StatelessWidget {
  final Widget child;
  const _ClientGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Not authenticated → show sign in prompt
        if (!auth.isAuthenticated) {
          return _buildNotAuthenticatedUI(context);
        }

        if (auth.user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // Authenticated client/admin can access → show page
        final user = auth.user;
        if (user != null && (user.isClient || user.isAdmin)) {
          return child;
        }

        // Vendor cannot access client pages
        return _buildUnauthorizedUI(
          context,
          title: 'Not Available',
          message: 'Vendor accounts cannot access shopping features.',
        );
      },
    );
  }
}

/// Requires: Authenticated + Vendor role (pending or approved)
class _VendorGuard extends StatelessWidget {
  final Widget child;
  const _VendorGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Not authenticated → show sign in prompt
        if (!auth.isAuthenticated) {
          return _buildNotAuthenticatedUI(context);
        }

        if (auth.user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = auth.user;

        // Must be vendor
        if (user != null && user.isVendor) {
          return child;
        }

        // Not a vendor
        return _buildUnauthorizedUI(
          context,
          title: 'Vendor Access Only',
          message: 'This feature is available only to registered vendors.',
        );
      },
    );
  }
}

/// Requires: Authenticated + Vendor role + Vendor profile approved
class _ApprovedVendorGuard extends StatelessWidget {
  final Widget child;
  const _ApprovedVendorGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Not authenticated → show sign in prompt
        if (!auth.isAuthenticated) {
          return _buildNotAuthenticatedUI(context);
        }

        if (auth.user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = auth.user;

        // Must be vendor with profile created
        if (user != null && user.isVendor && user.vendor != null) {
          // Check if approved
          if (user.vendor!.isApproved) {
            return child;
          }

          // Vendor exists but not approved yet
          return _buildPendingApprovalUI(context);
        }

        // Either not a vendor or vendor profile not created
        if (user != null && user.isVendor) {
          // Vendor role but no profile → redirect to onboarding
          return _buildOnboardingNeededUI(context);
        }

        // Not a vendor
        return _buildUnauthorizedUI(
          context,
          title: 'Vendor Access Only',
          message: 'This feature is available only to approved vendors.',
        );
      },
    );
  }
}

/// Requires: Authenticated + SuperAdmin role
class _AdminGuard extends StatelessWidget {
  final Widget child;
  const _AdminGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Not authenticated → show sign in prompt
        if (!auth.isAuthenticated) {
          return _buildNotAuthenticatedUI(context);
        }

        if (auth.user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = auth.user;

        // Must be admin
        if (user != null && user.isAdmin) {
          return child;
        }

        // Not an admin
        return _buildUnauthorizedUI(
          context,
          title: 'Admin Access Only',
          message: 'Only administrators can access this area.',
        );
      },
    );
  }
}

// ── Guard UI Builders ───────────────────────────────────────

Widget _buildNotAuthenticatedUI(BuildContext context) {
  final theme = Theme.of(context);
  return Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in required',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign in to access this feature.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/login'),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildUnauthorizedUI(
  BuildContext context, {
  required String title,
  required String message,
}) {
  final theme = Theme.of(context);
  return Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block_outlined,
              size: 64,
              color: theme.colorScheme.error.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/profile', (_) => false),
              child: const Text('Go to Profile'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildPendingApprovalUI(BuildContext context) {
  final theme = Theme.of(context);
  return Scaffold(
    appBar: AppBar(title: const Text('Approval Pending')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_empty_outlined,
              size: 64,
              color: Colors.orange.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Your vendor account is pending approval',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Our team is reviewing your vendor application. You will be notified via email once approved.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/vendor/profile', (_) => false),
              child: const Text('View Profile'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildOnboardingNeededUI(BuildContext context) {
  final theme = Theme.of(context);
  return Scaffold(
    appBar: AppBar(title: const Text('Complete Vendor Setup')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Set up your vendor shop',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your vendor profile to start selling.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/vendor/onboarding', (_) => false),
              child: const Text('Set Up Shop'),
            ),
          ],
        ),
      ),
    ),
  );
}
