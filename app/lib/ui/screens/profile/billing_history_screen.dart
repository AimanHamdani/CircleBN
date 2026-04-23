import 'package:flutter/material.dart';

import '../../../data/membership_repository.dart';

class BillingHistoryScreen extends StatelessWidget {
  static const routeName = '/profile/membership/billing-history';

  const BillingHistoryScreen({super.key});

  String _formatAmount(MembershipBillingRecord record) {
    final dollars = (record.amountCents / 100).toStringAsFixed(2);
    return '\$$dollars ${record.currency}';
  }

  String _formatPlan(String planId) {
    if (planId == 'yearly') {
      return 'Yearly';
    }
    if (planId == 'monthly') {
      return 'Monthly';
    }
    if (planId == 'cancel') {
      return 'Cancellation';
    }
    return planId;
  }

  String _formatDate(DateTime dt) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = dt.toLocal();
    final mm = months[local.month - 1];
    final dd = local.day.toString().padLeft(2, '0');
    final yy = local.year;
    final hour12 = ((local.hour + 11) % 12) + 1;
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$mm $dd, $yy  $hour12:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Billing History (Mock)',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<MembershipBillingRecord>>(
        future: membershipRepository().listBillingHistory(limit: 200),
        builder: (context, snap) {
          final records = snap.data ?? const <MembershipBillingRecord>[];
          if (snap.connectionState != ConnectionState.done && records.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (records.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No billing records yet.\nStart a mock subscription to generate invoices.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = records[i];
              final statusColor = r.status == 'paid'
                  ? const Color(0xFF15803D)
                  : r.status == 'cancelled'
                  ? const Color(0xFFB45309)
                  : const Color(0xFF6B7280);
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3E7EE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatPlan(r.planId),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            r.status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatAmount(r),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.description,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Invoice: ${r.id}',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _formatDate(r.createdAt),
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
