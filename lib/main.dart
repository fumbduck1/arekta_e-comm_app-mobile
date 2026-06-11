// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/animations/animation_config.dart';
import 'core/animations/custom_page_route.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/cart/cart_provider.dart';
import 'features/profile/profile_provider.dart';

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
  // Do initialization before showing any Dart UI
  try {
    await dotenv.load(fileName: '.env');
    AppConstants.validateEnvVars();

    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );

    // Keep splash visible for at least 1.5 seconds for smooth transition
    await Future.delayed(const Duration(milliseconds: 1500));
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'app bootstrap',
        context: ErrorDescription('while initializing app services'),
      ),
    );
  } finally {}

  runApp(const ArekitaApp());
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
  Object? _startupError;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Keep native splash visible while Dart splash animates, then remove both together
      _doInit();
    });
  }

  Future<void> _doInit() async {
    try {
      await dotenv.load(fileName: '.env');
      AppConstants.validateEnvVars();

      // Ensure splash is visible for at least 2 seconds (covers text animation + transition)
      final initStart = DateTime.now();

      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );

      // Calculate elapsed time and add delay if needed to show splash long enough
      final elapsed = DateTime.now().difference(initStart);
      final minimumSplashDuration = const Duration(seconds: 2);

      if (elapsed < minimumSplashDuration) {
        await Future.delayed(minimumSplashDuration - elapsed);
      }

      if (!mounted) {
        return;
      }

      // Now remove native splash and transition to main app

      setState(() {
        _isReady = true;
      });
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app bootstrap',
          context: ErrorDescription('while initializing app services'),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _startupError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Startup error:\n$_startupError',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (!_isReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _SplashScreen(),
      );
    }

    return const ArekitaApp();
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _taglineController;
  late final AnimationController _progressController;

  late final Animation<double> _logoBounceAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final List<Animation<double>> _taglineWordAnimations;
  late final List<Animation<Offset>> _taglineSlideAnimations;

  @override
  void initState() {
    super.initState();

    // Logo controller: 0-400ms bounce animation
    _logoController = AnimationController(
      duration: AnimationConfig.kSplashLogoDuration,
      vsync: this,
    );

    // Logo scale animation with elasticOut for bouncy effect
    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: AnimationConfig.kBouncyCurve,
      ),
    );

    // Logo opacity animation
    _logoBounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    // Tagline controller: staggered word reveals
    _taglineController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Create staggered animations for each word in tagline
    _initializeTaglineAnimations();

    // Progress indicator controller: continuous animation
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Start animations sequentially
    _startAnimationSequence();
  }

  void _initializeTaglineAnimations() {
    const words = ['Your', 'Premium', 'E-Commerce', 'Destination'];
    _taglineWordAnimations = [];
    _taglineSlideAnimations = [];

    for (int i = 0; i < words.length; i++) {
      final delay = Duration(
        milliseconds:
            i * AnimationConfig.kSplashTaglineWordStagger.inMilliseconds,
      );

      // Fade animation for each word
      final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _taglineController,
          curve: Interval(
            delay.inMilliseconds / _taglineController.duration!.inMilliseconds,
            (delay.inMilliseconds + 200) /
                _taglineController.duration!.inMilliseconds,
            curve: AnimationConfig.kEntryCurve,
          ),
        ),
      );
      _taglineWordAnimations.add(fadeAnimation);

      // Slide animation for each word (slide up 15px)
      final slideAnimation =
          Tween<Offset>(
            begin: const Offset(0.0, 0.5),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _taglineController,
              curve: Interval(
                delay.inMilliseconds /
                    _taglineController.duration!.inMilliseconds,
                (delay.inMilliseconds + 200) /
                    _taglineController.duration!.inMilliseconds,
                curve: AnimationConfig.kEntryCurve,
              ),
            ),
          );
      _taglineSlideAnimations.add(slideAnimation);
    }
  }

  void _startAnimationSequence() async {
    // Sequence 1: Logo bounces (0-400ms)
    await _logoController.forward();

    // Sequence 2: Tagline reveals (overlaps starting at 250ms from start, but we start after logo)
    _taglineController.forward();

    // Sequence 3: Progress indicator fades in after 400ms
    await Future.delayed(const Duration(milliseconds: 400));
    _progressController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _taglineController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with bounce animation
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoBounceAnimation.value,
                      child: Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF000000),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Tagline with staggered word reveal
                _buildTaglineWithStagger(),

                const SizedBox(height: 54),

                // Progress indicator with animation
                _buildAnimatedProgress(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaglineWithStagger() {
    const words = ['Your', 'Premium', 'E-Commerce', 'Destination'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6.0,
        runSpacing: 6.0,
        children: List.generate(
          words.length,
          (index) => AnimatedBuilder(
            animation: Listenable.merge([
              _taglineWordAnimations[index],
              _taglineSlideAnimations[index],
            ]),
            builder: (context, child) {
              return Opacity(
                opacity: _taglineWordAnimations[index].value,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    _taglineSlideAnimations[index].value.dy * -15,
                  ),
                  child: child,
                ),
              );
            },
            child: Text(
              words[index],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedProgress() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          height: 4,
          child: AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              // Linear progress bar animation
              final progress = (_progressController.value % 1.0);
              return LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF6C63FF),
                ),
                minHeight: 4,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            final progress = (_progressController.value % 1.0);
            int displayedProgress = (progress * 100).toInt();

            return Text(
              'Initializing... $displayedProgress%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF999999),
              ),
            );
          },
        ),
      ],
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
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
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
        break;
      case '/register':
        page = const RegisterScreen();
        break;

      // ── Main Tabs ─────────────────────────────────────
      case '/':
        page = const HomeScreen();
        showShell = true;
        shellIndex = 0;
        break;
      case '/products':
        page = const ProductListScreen();
        showShell = true;
        shellIndex = 1;
        break;
      case '/cart':
        page = const _ClientGuard(child: CartScreen());
        showShell = true;
        shellIndex = 2;
        break;
      case '/orders':
        page = const _ClientGuard(child: OrderListScreen());
        showShell = true;
        shellIndex = 3;
        break;
      case '/profile':
        page = const ProfileScreen();
        showShell = true;
        shellIndex = 4;
        break;

      // ── Product Detail ────────────────────────────────
      case '/product':
        final productId = settings.arguments as String;
        page = ProductDetailScreen(productId: productId);
        break;

      // ── Checkout ──────────────────────────────────────
      case '/checkout':
        page = const _ClientGuard(child: CheckoutScreen());
        break;

      // ── Order Detail ──────────────────────────────────
      case '/order':
        final orderId = settings.arguments as String;
        page = OrderDetailScreen(orderId: orderId);
        break;

      // ── Vendor Routes ─────────────────────────────────
      case '/vendor/dashboard':
        page = const _ApprovedVendorGuard(child: VendorDashboardScreen());
        showShell = true;
        shellIndex = 0;
        break;
      case '/vendor/products':
        page = const _ApprovedVendorGuard(child: VendorProductsScreen());
        showShell = true;
        shellIndex = 1;
        break;
      case '/vendor/products/add':
        page = const _ApprovedVendorGuard(child: VendorAddProductScreen());
        break;
      case '/vendor/orders':
        page = const _ApprovedVendorGuard(child: VendorOrdersScreen());
        showShell = true;
        shellIndex = 2;
        break;
      case '/vendor/onboarding':
        page = const _VendorGuard(child: VendorOnboardingScreen());
        break;
      case '/vendor/profile':
        page = const _VendorGuard(child: VendorPendingApprovalScreen());
        showShell = true;
        shellIndex = 3;
        break;

      // ── Admin Routes ──────────────────────────────────
      case '/admin/dashboard':
        page = const _AdminGuard(child: AdminDashboardScreen());
        break;
      case '/admin/vendors':
        page = const _AdminGuard(child: AdminVendorApprovalsScreen());
        break;
      case '/admin/products/moderation':
        page = const _AdminGuard(child: AdminProductModerationScreen());
        break;
      case '/admin/carousels':
        page = const _AdminGuard(child: AdminCarouselScreen());
        break;
      case '/admin/categories':
        page = const _AdminGuard(child: AdminCategoriesScreen());
        break;
      case '/admin/coupons':
        page = const _AdminGuard(child: AdminCouponsScreen());
        break;
      case '/admin/reports':
        page = const _AdminGuard(child: AdminReportsScreen());
        break;

      default:
        page = const Scaffold(
          body: Center(child: Text('404 — Page not found')),
        );
        break;
    }

    final Widget finalPage = showShell
        ? MainShell(currentIndex: shellIndex, child: page)
        : page;

    // Use custom page route with slide+fade transition for all routes
    // Tab routes within MainShell are state-driven, transitions handled there
    return createCustomPageRoute<dynamic>(
      builder: (_) => finalPage,
      settings: settings,
      duration: AnimationConfig.kPageTransitionDuration,
      curve: AnimationConfig.kPageTransitionCurve,
    );
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
