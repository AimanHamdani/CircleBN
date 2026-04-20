import 'package:flutter/material.dart';

import 'auth_gate_screen.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/all_events_screen.dart';
import 'screens/home/create_event_screen.dart';
import 'screens/home/create_club_screen.dart';
import 'screens/home/club_chat_screen.dart';
import 'screens/home/club_info_screen.dart';
import 'screens/home/event_detail_screen.dart';
import 'screens/home/event_scoring_screen.dart';
import 'screens/home/map_picker_screen.dart';
import 'screens/home/activity_overview_screen.dart';
import 'screens/home/notifications_screen.dart';
import 'screens/home/streak_screen.dart';
import 'screens/home/private_events_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/change_password_screen.dart';
import 'screens/profile/achievements_screen.dart';
import 'screens/profile/membership_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/free_stats_screen.dart';
import 'screens/profile/pro_stats_screen.dart';
import 'screens/profile/user_profile_view_screen.dart';
import 'screens/reset_password_screen.dart';
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
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = constraints.maxWidth;
            final maxWidth = viewportWidth >= 1600
                ? 1440.0
                : viewportWidth >= 1200
                ? viewportWidth * 0.94
                : viewportWidth >= 900
                ? viewportWidth * 0.97
                : viewportWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: child,
              ),
            );
          },
        );
      },
      home: const AuthGateScreen(),
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
        EventScoringScreen.routeName: (_) => const EventScoringScreen(),
        MapPickerScreen.routeName: (_) => const MapPickerScreen(),
        ActivityOverviewScreen.routeName: (_) => const ActivityOverviewScreen(),
        NotificationsScreen.routeName: (_) => const NotificationsScreen(),
        StreakScreen.routeName: (_) => const StreakScreen(),
        PrivateEventsScreen.routeName: (_) => const PrivateEventsScreen(),
        AchievementsScreen.routeName: (_) => const AchievementsScreen(),
        ProfileScreen.routeName: (_) => const ProfileScreen(),
        FreeStatsScreen.routeName: (_) => const FreeStatsScreen(),
        ProStatsHubScreen.routeName: (_) => const ProStatsHubScreen(),
        ProMatchHistoryScreen.routeName: (_) => const ProMatchHistoryScreen(),
        MembershipScreen.routeName: (_) => const MembershipScreen(),
        UserProfileViewScreen.routeName: (_) => const UserProfileViewScreen(),
        EditProfileScreen.routeName: (_) => const EditProfileScreen(),
        ChangePasswordScreen.routeName: (_) => const ChangePasswordScreen(),
        ResetPasswordScreen.routeName: (_) => const ResetPasswordScreen(),
      },
    );
  }
}
