import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/all_events_screen.dart';
import 'screens/home/create_event_screen.dart';
import 'screens/home/create_club_screen.dart';
import 'screens/home/club_chat_screen.dart';
import 'screens/home/club_info_screen.dart';
import 'screens/home/event_detail_screen.dart';
import 'screens/home/map_picker_screen.dart';
import 'screens/home/activity_overview_screen.dart';
import 'screens/home/notifications_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/change_password_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/signup/signup_screen.dart';
import 'screens/signup/about_you_screen.dart';
import 'screens/signup/choose_sports_screen.dart';
import 'screens/signup/recommended_clubs_screen.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final qp = Uri.base.queryParameters;
    final hasRecoveryParams = qp['userId']?.isNotEmpty == true && qp['secret']?.isNotEmpty == true;
    final initialRoute = hasRecoveryParams ? ResetPasswordScreen.routeName : LoginScreen.routeName;
    return MaterialApp(
      title: 'CircleBN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: initialRoute,
      routes: {
        LoginScreen.routeName: (_) => const LoginScreen(),
        SignUpScreen.routeName: (_) => const SignUpScreen(),
        AboutYouScreen.routeName: (_) => const AboutYouScreen(),
        ChooseSportsScreen.routeName: (_) => const ChooseSportsScreen(),
        RecommendedClubsScreen.routeName: (_) => const RecommendedClubsScreen(),
        HomeScreen.routeName: (_) => const HomeScreen(),
        AllEventsScreen.routeName: (_) => const AllEventsScreen(),
        CreateEventScreen.routeName: (_) => const CreateEventScreen(),
        CreateClubScreen.routeName: (_) => const CreateClubScreen(),
        ClubChatScreen.routeName: (_) => const ClubChatScreen(),
        ClubInfoScreen.routeName: (_) => const ClubInfoScreen(),
        EventDetailScreen.routeName: (_) => const EventDetailScreen(),
        MapPickerScreen.routeName: (_) => const MapPickerScreen(),
        ActivityOverviewScreen.routeName: (_) => const ActivityOverviewScreen(),
        NotificationsScreen.routeName: (_) => const NotificationsScreen(),
        ProfileScreen.routeName: (_) => const ProfileScreen(),
        EditProfileScreen.routeName: (_) => const EditProfileScreen(),
        ChangePasswordScreen.routeName: (_) => const ChangePasswordScreen(),
        ResetPasswordScreen.routeName: (_) => const ResetPasswordScreen(),
      },
    );
  }
}

