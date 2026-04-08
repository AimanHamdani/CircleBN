import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AuthBrandPlaceholder extends StatelessWidget {
  final double size;

  const AuthBrandPlaceholder({super.key, this.size = 78});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.brandGreen.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
    );
  }
}

