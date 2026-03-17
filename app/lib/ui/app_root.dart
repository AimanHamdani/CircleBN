import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/all_events_screen.dart';
import 'screens/home/event_detail_screen.dart';
import 'screens/signup/signup_screen.dart';
import 'screens/signup/about_you_screen.dart';
import 'screens/signup/choose_sports_screen.dart';
import 'screens/signup/recommended_clubs_screen.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CircleBN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: LoginScreen.routeName,
      routes: {
        LoginScreen.routeName: (_) => const LoginScreen(),
        SignUpScreen.routeName: (_) => const SignUpScreen(),
        AboutYouScreen.routeName: (_) => const AboutYouScreen(),
        ChooseSportsScreen.routeName: (_) => const ChooseSportsScreen(),
        RecommendedClubsScreen.routeName: (_) => const RecommendedClubsScreen(),
        HomeScreen.routeName: (_) => const HomeScreen(),
        AllEventsScreen.routeName: (_) => const AllEventsScreen(),
        EventDetailScreen.routeName: (_) => const EventDetailScreen(),
      },
    );
  }
}

