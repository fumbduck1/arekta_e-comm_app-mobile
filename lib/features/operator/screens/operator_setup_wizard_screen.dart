import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../operator_provider.dart';

class OperatorSetupWizardScreen extends StatefulWidget {
  const OperatorSetupWizardScreen({super.key});

  @override
  State<OperatorSetupWizardScreen> createState() =>
      _OperatorSetupWizardScreenState();
}

class _OperatorSetupWizardScreenState
    extends State<OperatorSetupWizardScreen> {
  int _currentStep = 0;
  String? _selectedPlanId;
  bool _isSubscribing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OperatorProvider>().loadPlans();
    });
  }

  Future<void> _subscribe() async {
    if (_selectedPlanId == null) return;

    setState(() => _isSubscribing = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated')),
        );
        return;
      }

      final marketplace = await supabase
          .from('marketplaces')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();

      if (!mounted) return;

      if (marketplace == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No marketplace found. Register first.')),
        );
        return;
      }

      final marketplaceId = marketplace['id'] as String;
      final provider = context.read<OperatorProvider>();

      final success = await provider.createMarketplaceSubscription(
        marketplaceId: marketplaceId,
        planId: _selectedPlanId!,
        paymentMethod: 'sslcommerz',
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marketplace setup complete!')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Subscription failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setup failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Your Marketplace')),
      body: Consumer<OperatorProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep < 2) {
                setState(() => _currentStep++);
              } else {
                _subscribe();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              }
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: _isSubscribing ? null : details.onStepContinue,
                      child: _isSubscribing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _currentStep < 2 ? 'Continue' : 'Complete Setup',
                            ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Welcome'),
                isActive: _currentStep >= 0,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your marketplace is registered!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a subscription plan to activate your marketplace. '
                      'You can upgrade or cancel at any time.',
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Choose a Plan'),
                isActive: _currentStep >= 1,
                content: provider.plans.isEmpty
                    ? const Text('Loading plans...')
                    : Column(
                        children: provider.plans.map((plan) {
                          final isSelected = _selectedPlanId == plan.id;
                          return Card(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isSelected
                                  ? BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    )
                                  : BorderSide.none,
                            ),
                            child: InkWell(
                              onTap: () => setState(() => _selectedPlanId = plan.id),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Radio<String>(
                                      value: plan.id,
                                      groupValue: _selectedPlanId,
                                      onChanged: (v) => setState(() => _selectedPlanId = v),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            plan.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          if (plan.description != null) ...[
                                            const SizedBox(height: 2),
                                            Text(plan.description!, style: theme.textTheme.bodySmall),
                                          ],
                                          const SizedBox(height: 8),
                                          Text(
                                            plan.priceFormatted,
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${plan.maxVendors} vendors, ${plan.maxProducts} products',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          ...plan.features.map((f) => Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Row(
                                              children: [
                                                Icon(Icons.check, size: 16, color: Colors.green),
                                                const SizedBox(width: 6),
                                                Text(f, style: theme.textTheme.bodySmall),
                                              ],
                                            ),
                                          )),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              Step(
                title: const Text('Payment'),
                isActive: _currentStep >= 2,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete your subscription',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.payment),
                        title: const Text('SSLCommerz'),
                        subtitle: const Text('Pay with bKash, Nagad, or cards'),
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You will be redirected to SSLCommerz to complete payment. '
                      'For demo purposes, the subscription will be activated immediately.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
