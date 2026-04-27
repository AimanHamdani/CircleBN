import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/membership_repository.dart';

class BillingCheckoutScreen extends StatefulWidget {
  static const routeName = '/profile/membership/checkout';

  const BillingCheckoutScreen({super.key});

  @override
  State<BillingCheckoutScreen> createState() => _BillingCheckoutScreenState();
}

class _BillingCheckoutScreenState extends State<BillingCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardholderCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _billingAddressCtrl = TextEditingController();

  String _selectedPlanId = 'yearly';
  String _paymentType = 'Credit Card';
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final maybePlan = (args['planId'] ?? '').toString();
      if (maybePlan == 'monthly' || maybePlan == 'yearly') {
        _selectedPlanId = maybePlan;
      }
    }
  }

  @override
  void dispose() {
    _cardholderCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _billingAddressCtrl.dispose();
    super.dispose();
  }

  String get _planPriceLabel {
    return _selectedPlanId == 'yearly' ? r'$39.99 / year' : r'$4.99 / month';
  }

  String get _planSubtitle {
    return _selectedPlanId == 'yearly'
        ? 'Best value, billed once a year'
        : 'Flexible billing every month';
  }

  Future<void> _confirmPayment() async {
    setState(() => _isSubmitting = true);
    try {
      await _showProcessingDialog();
      await membershipRepository().subscribeWithMockBilling(
        planId: _selectedPlanId,
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F7ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF16A34A),
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Payment Successful',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Thanks for supporting us. Your premium plan is now active.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showProcessingDialog() async {
    final steps = <String>[
      'Validating card details...',
      'Authorizing payment...',
      'Finalizing your premium upgrade...',
    ];

    final setDialogStateCompleter = Completer<StateSetter>();
    String currentText = steps.first;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (!setDialogStateCompleter.isCompleted) {
              setDialogStateCompleter.complete(setState);
            }
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              content: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      currentText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    final setDialogState = await setDialogStateCompleter.future;
    for (final step in steps) {
      await Future<void>.delayed(const Duration(milliseconds: 550));
      if (!mounted) {
        return;
      }
      setDialogState(() {
        currentText = step;
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Billing Checkout'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SummaryCard(
                planId: _selectedPlanId,
                priceLabel: _planPriceLabel,
                subtitle: _planSubtitle,
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Payment Type',
                child: DropdownButtonFormField<String>(
                  initialValue: _paymentType,
                  items: const [
                    DropdownMenuItem(
                      value: 'Credit Card',
                      child: Text('Credit Card'),
                    ),
                    DropdownMenuItem(
                      value: 'Debit Card',
                      child: Text('Debit Card'),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (v) {
                          if (v == null) {
                            return;
                          }
                          setState(() => _paymentType = v);
                        },
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Card Details',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _cardholderCtrl,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Cardholder Name',
                        hintText: 'John Doe',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cardNumberCtrl,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Card Number',
                        hintText: '1234 5678 9012 3456',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryCtrl,
                            enabled: !_isSubmitting,
                            decoration: const InputDecoration(
                              labelText: 'Expiry',
                              hintText: 'MM/YY',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvCtrl,
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'CVV',
                              hintText: '123',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _billingAddressCtrl,
                      enabled: !_isSubmitting,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Billing Address',
                        hintText: 'Street, city, country',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _isSubmitting ? null : _confirmPayment,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFFCFB02C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Confirm Payment • $_planPriceLabel'),
              ),
              const SizedBox(height: 8),
              Text(
                'Mock billing only. No real payment is processed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String planId;
  final String priceLabel;
  final String subtitle;

  const _SummaryCard({
    required this.planId,
    required this.priceLabel,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0B84A), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFA06B00)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planId == 'yearly' ? 'Premium Yearly' : 'Premium Monthly',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2F3A46),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D6773),
                  ),
                ),
              ],
            ),
          ),
          Text(
            priceLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7A5A00),
            ),
          ),
        ],
      ),
    );
  }
}
