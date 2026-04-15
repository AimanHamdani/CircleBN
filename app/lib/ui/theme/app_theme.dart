import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandGreen = Color(0xFF1F9D6E);

  /// Vibrant purple for Home, All Events, and Event Detail (design mockups).
  static const Color eventPurple = Color(0xFF8B5CF6);
  static const Color eventPurpleDeep = Color(0xFF7C3AED);
  static const Color eventPurpleLightBg = Color(0xFFF5F3FF);

  /// Overrides the seed primary with purple while keeping typography / inputs.
  static ThemeData eventFlowTheme(ThemeData base) {
    final cs = ColorScheme.fromSeed(
      seedColor: eventPurple,
      brightness: Brightness.light,
    );
    return base.copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor: Colors.white,
      // [light] pins FilledButton to brandGreen; override so event screens stay purple.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: brandGreen);
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final nunitoTextTheme = base.textTheme.apply(
      fontFamily: 'Nunito',
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito',
      textTheme: nunitoTextTheme,
      primaryTextTheme: nunitoTextTheme,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: const TextStyle(fontFamily: 'Nunito'),
        labelStyle: const TextStyle(fontFamily: 'Nunito'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandGreen,
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionsBuilder(),
          TargetPlatform.iOS: _FadeThroughTransitionsBuilder(),
          TargetPlatform.windows: _FadeThroughTransitionsBuilder(),
          TargetPlatform.macOS: _FadeThroughTransitionsBuilder(),
          TargetPlatform.linux: _FadeThroughTransitionsBuilder(),
        },
      ),
    );
  }
}

class _FadeThroughTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slideCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(fadeCurve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.03),
          end: Offset.zero,
        ).animate(slideCurve),
        child: child,
      ),
    );
  }
}
