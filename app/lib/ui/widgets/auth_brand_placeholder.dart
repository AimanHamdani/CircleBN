import 'package:flutter/material.dart';

/// Brand mark from `assets/branding/circlebn_logo.png` (no card; sits on scaffold).
class AuthBrandPlaceholder extends StatelessWidget {
  static const String assetPath = 'assets/branding/circlebn_logo.png';

  final double size;

  const AuthBrandPlaceholder({super.key, this.size = 78});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(size * 0.06),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'CircleBN logo',
        ),
      ),
    );
  }
}
