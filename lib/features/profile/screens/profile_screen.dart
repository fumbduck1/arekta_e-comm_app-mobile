import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../auth/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          // ── Not signed in → show sign-in prompt ────────
          if (!auth.isAuthenticated) {
            return _GuestProfileView(theme: theme);
          }

          final user = auth.user;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Avatar & Name ─────────────────────────────
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        (user?.name ?? user?.email ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.name ?? 'User',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user?.role.label ?? 'Customer',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Menu Items ────────────────────────────────
              _ProfileMenuItem(
                icon: Icons.person_outlined,
                title: 'Edit Profile',
                onTap: () {
                  // Navigate to edit profile
                },
              ),

              // Client-specific menu
              if (user is ClientUser) ...[
                _ProfileMenuItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'My Orders',
                  onTap: () => Navigator.of(context).pushNamed('/orders'),
                ),
                _ProfileMenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'Shipping Addresses',
                  onTap: () {
                    // Navigate to addresses
                  },
                ),
              ],

              // Vendor-specific menu ─────────────────────────
              if (user is VendorUser) ...[
                const SizedBox(height: 16),
                Text(
                  'Vendor Account',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),

                // Approval Status Card
                if (user.vendor != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: user.vendor!.isApproved
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: user.vendor!.isApproved
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          user.vendor!.isApproved
                              ? Icons.check_circle
                              : Icons.hourglass_empty,
                          color: user.vendor!.isApproved
                              ? Colors.green
                              : Colors.amber[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.vendor!.isApproved
                                    ? 'Approved'
                                    : 'Pending Approval',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: user.vendor!.isApproved
                                      ? Colors.green
                                      : Colors.amber[700],
                                ),
                              ),
                              Text(
                                user.vendor!.shopName,
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Vendor Dashboard (if approved)
                if (user.vendor != null && user.vendor!.isApproved)
                  _ProfileMenuItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Seller Dashboard',
                    subtitle: 'Manage shop',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/vendor/dashboard'),
                  ),

                // View Shop Profile
                _ProfileMenuItem(
                  icon: Icons.store_outlined,
                  title: 'Shop Profile',
                  subtitle: user.vendor?.shopName ?? 'View details',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/vendor/profile'),
                ),

                // View Products (if approved)
                if (user.vendor != null && user.vendor!.isApproved)
                  _ProfileMenuItem(
                    icon: Icons.inventory_2_outlined,
                    title: 'Manage Products',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/vendor/products'),
                  ),

                // View Orders (if approved)
                if (user.vendor != null && user.vendor!.isApproved)
                  _ProfileMenuItem(
                    icon: Icons.receipt_long_outlined,
                    title: 'Manage Orders',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/vendor/orders'),
                  ),
              ],

              // Admin-specific menu ──────────────────────────
              if (user is AdminUser) ...[
                const SizedBox(height: 16),
                Text(
                  'Administration',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                _ProfileMenuItem(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin Dashboard',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/admin/dashboard'),
                ),
                _ProfileMenuItem(
                  icon: Icons.checklist_outlined,
                  title: 'Vendor Approvals',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/admin/vendors'),
                ),
                _ProfileMenuItem(
                  icon: Icons.image_outlined,
                  title: 'Manage Carousels',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/admin/carousels'),
                ),
                _ProfileMenuItem(
                  icon: Icons.category_outlined,
                  title: 'Manage Categories',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/admin/categories'),
                ),
                _ProfileMenuItem(
                  icon: Icons.local_offer_outlined,
                  title: 'Manage Coupons',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/admin/coupons'),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),

              // ── Logout ────────────────────────────────────
              _ProfileMenuItem(
                icon: Icons.logout,
                title: 'Sign Out',
                color: theme.colorScheme.error,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                          ),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    context.read<AuthProvider>().signOut();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Guest profile view (not signed in) ──────────────────────
class _GuestProfileView extends StatelessWidget {
  final ThemeData theme;
  const _GuestProfileView({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Arekta',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to manage orders, save addresses,\nand access your profile.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                child: const Text('Sign In'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed('/register'),
                child: const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemColor = color ?? theme.colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: itemColor),
      title: Text(
        title,
        style: TextStyle(color: itemColor, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: Icon(
        Icons.chevron_right,
        color: itemColor.withValues(alpha: 0.4),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
