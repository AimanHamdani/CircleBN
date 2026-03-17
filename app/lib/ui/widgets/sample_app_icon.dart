import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SampleAppIcon extends StatelessWidget {
  const SampleAppIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sample icon placeholder. Replace later.',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.brandGreen.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.brandGreen.withValues(alpha: 0.55),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.public, size: 34, color: AppTheme.brandGreen),
            SizedBox(height: 6),
            Text(
              'SAMPLE ICON\nreplace later',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: AppTheme.brandGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

