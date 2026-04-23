import 'dart:developer' as developer;

import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../auth/current_user.dart';
import '../models/user_profile.dart';

class ProfileRepository {
  Future<UserProfile> getMyProfile() async {
    final userId = currentUserId;
    String accountEmail = '';
    String accountName = '';
    try {
      final me = await AppwriteService.account.get();
      accountEmail = me.email;
      accountName = me.name;
    } catch (_) {}

    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return UserProfile.empty(userId).copyWith(
        email: accountEmail,
        realName: accountName.isNotEmpty ? accountName : null,
      );
    }

    try {
      final doc = await AppwriteService.getDocument(
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
      );
      final profile = UserProfile.fromMap(
        Map<String, dynamic>.from(doc.data),
        userId: userId,
      );
      final hydratedProfile = profile.copyWith(
        email: accountEmail.isNotEmpty ? accountEmail : null,
        realName: profile.realName == 'Name' && accountName.isNotEmpty
            ? accountName
            : null,
      );
      _tryMigrateSportSkillsField(hydratedProfile);
      _tryMigrateLegacyMatchHistory(hydratedProfile);
      return hydratedProfile;
    } catch (_) {
      return UserProfile.empty(userId).copyWith(
        email: accountEmail,
        realName: accountName.isNotEmpty ? accountName : null,
      );
    }
  }

  Future<UserProfile> saveMyProfile(UserProfile profile) async {
    try {
      if (profile.realName.trim().isNotEmpty) {
        await AppwriteService.account.updateName(name: profile.realName.trim());
      }
    } catch (_) {}

    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return profile;
    }

    final doc = await AppwriteService.createOrUpdateDocument(
      collectionId: AppwriteConfig.profilesCollectionId,
      documentId: profile.userId,
      data: profile.copyWith(sportSkillsNeedsMigration: false).toMap(),
    );

    return UserProfile.fromMap(
      Map<String, dynamic>.from(doc.data),
      userId: profile.userId,
    );
  }

  Future<UserProfile> saveProfileByUserId(UserProfile profile) async {
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return profile;
    }

    final doc = await AppwriteService.createOrUpdateDocument(
      collectionId: AppwriteConfig.profilesCollectionId,
      documentId: profile.userId,
      data: profile.copyWith(sportSkillsNeedsMigration: false).toMap(),
    );

    return UserProfile.fromMap(
      Map<String, dynamic>.from(doc.data),
      userId: profile.userId,
    );
  }

  Future<List<UserProfile>> getProfilesByIds(List<String> userIds) async {
    final uniqueIds = userIds
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) {
      return const [];
    }

    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return uniqueIds.map((id) => UserProfile.empty(id)).toList();
    }

    final profiles = <UserProfile>[];
    for (final userId in uniqueIds) {
      try {
        final doc = await AppwriteService.getDocument(
          collectionId: AppwriteConfig.profilesCollectionId,
          documentId: userId,
        );
        profiles.add(
          UserProfile.fromMap(
            Map<String, dynamic>.from(doc.data),
            userId: userId,
          ),
        );
        _tryMigrateSportSkillsField(profiles.last);
      } catch (_) {
        profiles.add(UserProfile.empty(userId));
      }
    }

    return profiles;
  }

  Future<UserProfile> getProfileById(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return UserProfile.empty('');
    }
    final profiles = await getProfilesByIds([normalized]);
    if (profiles.isEmpty) {
      return UserProfile.empty(normalized);
    }
    return profiles.first;
  }

  /// Prefix search on **username** and **realName** for invite pickers (Appwrite
  /// needs usable indexes / attributes on both fields for both queries to work).
  Future<List<UserProfile>> searchProfilesForInvite(
    String query, {
    int limit = 12,
  }) async {
    final q = query.trim();
    if (q.length < 2) {
      return const [];
    }
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return const [];
    }
    final me = currentUserId.trim();
    final seen = <String>{};
    final out = <UserProfile>[];

    Future<void> appendFromQueries(List<String> queries) async {
      if (out.length >= limit) {
        return;
      }
      try {
        final docs = await AppwriteService.listDocuments(
          collectionId: AppwriteConfig.profilesCollectionId,
          queries: queries,
        );
        for (final d in docs.documents) {
          if (out.length >= limit) {
            return;
          }
          final id = d.$id.trim();
          if (id.isEmpty || id == me || seen.contains(id)) {
            continue;
          }
          seen.add(id);
          out.add(
            UserProfile.fromMap(
              Map<String, dynamic>.from(d.data),
              userId: id,
            ),
          );
        }
      } catch (_) {
        // e.g. attribute or index missing for this field — skip this branch.
      }
    }

    await appendFromQueries([
      Query.startsWith('username', q),
      Query.limit(25),
    ]);
    await appendFromQueries([
      Query.startsWith('realName', q),
      Query.limit(25),
    ]);
    return out;
  }

  Future<void> _tryMigrateSportSkillsField(UserProfile profile) async {
    if (!profile.sportSkillsNeedsMigration) {
      return;
    }
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return;
    }
    try {
      await AppwriteService.createOrUpdateDocument(
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: profile.userId,
        data: profile.copyWith(sportSkillsNeedsMigration: false).toMap(),
      );
    } catch (_) {}
  }

  Future<void> _tryMigrateLegacyMatchHistory(UserProfile profile) async {
    if (profile.matchHistory.isEmpty) {
      return;
    }
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return;
    }

    var changed = false;
    var statValuesBackfilled = 0;
    var formatBackfilled = 0;
    final migrated = <ProfileMatchRecord>[];

    for (final row in profile.matchHistory) {
      var next = row;
      final sport = row.sport.trim().toLowerCase();
      if (row.statValues.isEmpty) {
        changed = true;
        statValuesBackfilled++;
        final inferred = _inferLegacyStatValues(row, sport);
        next = next.copyWith(statValues: inferred);
      }
      if ((next.formatLabel ?? '').trim().isEmpty &&
          _sportUsesSinglesDoubles(sport)) {
        final inferredFormat = _inferFormatLabelFromTitle(next.eventTitle);
        if (inferredFormat != null) {
          changed = true;
          formatBackfilled++;
          next = next.copyWith(formatLabel: inferredFormat);
        }
      }
      migrated.add(next);
    }

    if (!changed) {
      return;
    }

    try {
      await AppwriteService.createOrUpdateDocument(
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: profile.userId,
        data: profile.copyWith(matchHistory: migrated).toMap(),
      );
      developer.log(
        'Legacy matchHistory migration applied for ${profile.userId}: '
        '$statValuesBackfilled statValues backfilled, '
        '$formatBackfilled format labels inferred.',
        name: 'ProfileRepository',
      );
    } catch (_) {}
  }

  bool _sportUsesSinglesDoubles(String sport) {
    return sport.contains('badminton') ||
        sport.contains('tennis') ||
        sport.contains('table tennis') ||
        sport.contains('ping pong') ||
        sport.contains('pickle');
  }

  String? _inferFormatLabelFromTitle(String title) {
    final t = title.trim().toLowerCase();
    if (t.isEmpty) {
      return null;
    }
    if (t.contains('singles')) {
      return 'Singles';
    }
    if (t.contains('doubles')) {
      return 'Doubles';
    }
    return null;
  }

  Map<String, num> _inferLegacyStatValues(
    ProfileMatchRecord row,
    String sport,
  ) {
    final outcome = row.outcome.toLowerCase();
    final awarded = row.pointsAwarded;
    final winBaseline = outcome == 'win' ? 1 : 0;
    final safeAwarded = awarded < 0 ? 0 : awarded;

    if (sport.contains('football')) {
      return <String, num>{
        'goals': safeAwarded > 0 ? safeAwarded : winBaseline,
        'assists': 0,
        'passes': 0,
        'tackles': 0,
        'saves': 0,
      };
    }
    if (sport.contains('basketball')) {
      return <String, num>{
        'points': safeAwarded,
        'assists': 0,
        'rebounds': 0,
        'steals': 0,
        'blocks': 0,
        'turnovers': 0,
      };
    }
    if (sport.contains('volleyball')) {
      return <String, num>{
        'points': safeAwarded,
        'assists': 0,
        'blocks': 0,
        'digs': 0,
      };
    }
    if (sport.contains('table tennis') || sport.contains('ping pong')) {
      return <String, num>{
        'gamesWon': outcome == 'win' ? 2 : 0,
        'pointsWon': safeAwarded,
        'aces': 0,
      };
    }
    if (sport.contains('pickle')) {
      return <String, num>{
        'gamesWon': outcome == 'win' ? 2 : 0,
        'pointsWon': safeAwarded,
        'aces': 0,
      };
    }
    if (sport.contains('tennis')) {
      return <String, num>{
        'setsWon': outcome == 'win' ? 2 : 0,
        'gamesWon': safeAwarded,
        'aces': 0,
      };
    }
    if (sport.contains('badminton')) {
      return <String, num>{
        'gamesWon': outcome == 'win' ? 2 : 0,
        'pointsWon': safeAwarded,
        'aces': 0,
      };
    }
    return <String, num>{
      'points': safeAwarded,
      'assists': 0,
    };
  }
}

ProfileRepository profileRepository() => ProfileRepository();
