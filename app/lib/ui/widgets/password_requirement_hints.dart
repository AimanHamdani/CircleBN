import 'package:flutter/material.dart';

import '../../utils/password_rules.dart';

/// Live checklist and near-limit warning for Appwrite-aligned passwords (8–256 chars).
class PasswordRequirementHints extends StatelessWidget {
  const PasswordRequirementHints({
    super.key,
    required this.password,
    required this.brandGreen,
  });

  final String password;
  final Color brandGreen;

  @override
  Widget build(BuildContext context) {
    final okMin = PasswordRules.hasMinLength(password);
    final remaining = PasswordRules.charactersUntilMinimum(password);
    final nearMax = PasswordRules.isNearMaxLength(password);

    final muted = brandGreen.withValues(alpha: 0.42);
    final iconColor = okMin ? const Color(0xFF21A97A) : muted;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password requirements',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: brandGreen.withValues(alpha: 0.85),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                okMin ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'At least ${PasswordRules.minLength} characters',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: okMin ? const Color(0xFF1E6B52) : const Color(0xFF5C6360),
                  ),
                ),
              ),
            ],
          ),
          if (password.isNotEmpty && !okMin) ...[
            const SizedBox(height: 6),
            Text(
              remaining == 1 ? '1 more character needed' : '$remaining more characters needed',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB8860B),
              ),
            ),
          ],
          if (nearMax) ...[
            const SizedBox(height: 6),
            Text(
              'You are close to the ${PasswordRules.maxLength} character limit.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB8860B),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
