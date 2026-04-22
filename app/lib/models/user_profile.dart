import 'dart:convert';

/// One scored match row persisted on the profile (newest entries first in [UserProfile.matchHistory]).
class ProfileMatchRecord {
  final String eventId;
  final String eventTitle;
  final String sport;
  /// Lowercase: win | draw | loss
  final String outcome;
  final int pointsAwarded;
  final DateTime recordedAt;
  /// Short scoring summary for Pro stats (e.g. award label from finalize).
  final String? statSnippet;
  /// Optional match format (e.g. Singles/Doubles) for racket-sport splits.
  final String? formatLabel;
  /// Raw per-match stat values keyed by stat id (real aggregation source).
  final Map<String, num> statValues;

  const ProfileMatchRecord({
    required this.eventId,
    required this.eventTitle,
    required this.sport,
    required this.outcome,
    required this.pointsAwarded,
    required this.recordedAt,
    this.statSnippet,
    this.formatLabel,
    this.statValues = const <String, num>{},
  });

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'eventTitle': eventTitle,
      'sport': sport,
      'outcome': outcome,
      'pointsAwarded': pointsAwarded,
      'recordedAt': recordedAt.toIso8601String(),
      if (statSnippet != null && statSnippet!.trim().isNotEmpty)
        'statSnippet': statSnippet,
      if (formatLabel != null && formatLabel!.trim().isNotEmpty)
        'formatLabel': formatLabel,
      if (statValues.isNotEmpty) 'statValues': statValues,
    };
  }

  factory ProfileMatchRecord.fromJson(Map<String, dynamic> m) {
    final at = m['recordedAt']?.toString() ?? '';
    final sn = m['statSnippet']?.toString().trim();
    final format = m['formatLabel']?.toString().trim();
    final statsRaw = m['statValues'];
    final parsedStats = <String, num>{};
    if (statsRaw is Map) {
      for (final entry in statsRaw.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) {
          continue;
        }
        final value = entry.value;
        if (value is num) {
          parsedStats[key] = value;
        } else if (value is String) {
          final asNum = num.tryParse(value.trim());
          if (asNum != null) {
            parsedStats[key] = asNum;
          }
        }
      }
    }
    return ProfileMatchRecord(
      eventId: m['eventId']?.toString() ?? '',
      eventTitle: m['eventTitle']?.toString() ?? '',
      sport: m['sport']?.toString() ?? '',
      outcome: m['outcome']?.toString().toLowerCase() ?? 'loss',
      pointsAwarded: _parseInt(m['pointsAwarded'], fallback: 0),
      recordedAt: DateTime.tryParse(at) ?? DateTime.now().toUtc(),
      statSnippet: (sn != null && sn.isNotEmpty) ? sn : null,
      formatLabel: (format != null && format.isNotEmpty) ? format : null,
      statValues: parsedStats,
    );
  }

  ProfileMatchRecord copyWith({
    String? eventId,
    String? eventTitle,
    String? sport,
    String? outcome,
    int? pointsAwarded,
    DateTime? recordedAt,
    String? statSnippet,
    String? formatLabel,
    Map<String, num>? statValues,
  }) {
    return ProfileMatchRecord(
      eventId: eventId ?? this.eventId,
      eventTitle: eventTitle ?? this.eventTitle,
      sport: sport ?? this.sport,
      outcome: outcome ?? this.outcome,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      recordedAt: recordedAt ?? this.recordedAt,
      statSnippet: statSnippet ?? this.statSnippet,
      formatLabel: formatLabel ?? this.formatLabel,
      statValues: statValues ?? this.statValues,
    );
  }
}

class UserProfile {
  final String userId;
  final String username;
  final String realName;
  final String email;
  final String? avatarFileId;
  final int? age;
  final String gender;
  final int? heightCm;
  final String
  skillLevel; // Beginner | Novice | Intermediate | Advanced | Pro/Master
  final int skillTierLevel; // 1..10
  final int skillTierProgress; // points within current level
  final Map<String, SportSkillProgress> sportSkills;
  final bool sportSkillsNeedsMigration;
  final Set<String> preferredSports;
  final String emergencyContact;
  final String bio;
  final bool notificationsEnabled;
  final int matchWins;
  final int matchDraws;
  final int matchLosses;
  final List<ProfileMatchRecord> matchHistory;

  const UserProfile({
    required this.userId,
    required this.username,
    required this.realName,
    required this.email,
    this.avatarFileId,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.skillLevel,
    this.skillTierLevel = 1,
    this.skillTierProgress = 0,
    this.sportSkills = const <String, SportSkillProgress>{},
    this.sportSkillsNeedsMigration = false,
    required this.preferredSports,
    required this.emergencyContact,
    required this.bio,
    required this.notificationsEnabled,
    this.matchWins = 0,
    this.matchDraws = 0,
    this.matchLosses = 0,
    this.matchHistory = const [],
  });

  static UserProfile empty(String userId) {
    return UserProfile(
      userId: userId,
      username: 'Username',
      realName: 'Name',
      email: '',
      avatarFileId: null,
      age: null,
      gender: 'Male',
      heightCm: null,
      skillLevel: 'Beginner',
      skillTierLevel: 1,
      skillTierProgress: 0,
      sportSkills: const <String, SportSkillProgress>{},
      sportSkillsNeedsMigration: false,
      preferredSports: const {},
      emergencyContact: '',
      bio: '',
      notificationsEnabled: true,
      matchWins: 0,
      matchDraws: 0,
      matchLosses: 0,
      matchHistory: const [],
    );
  }

  factory UserProfile.fromMap(
    Map<String, dynamic> data, {
    required String userId,
  }) {
    final notif = data['notificationsEnabled'];
    final h = data['heightCm'];
    final ageVal = data['age'];
    final sportsRaw = data['preferredSports'];
    final preferredSports = sportsRaw is List
        ? sportsRaw
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toSet()
        : <String>{};
    final sportSkillsRaw = data['sportSkills'];
    final sportSkills = <String, SportSkillProgress>{};
    var sportSkillsNeedsMigration = false;
    Map<String, dynamic>? sportSkillsMap;
    if (sportSkillsRaw is String && sportSkillsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(sportSkillsRaw);
        if (decoded is Map) {
          sportSkillsMap = Map<String, dynamic>.from(decoded);
        } else {
          sportSkillsNeedsMigration = true;
        }
      } catch (_) {
        sportSkillsNeedsMigration = true;
      }
    } else if (sportSkillsRaw is Map) {
      // Backward-compatible read in case old docs stored an object directly.
      sportSkillsMap = Map<String, dynamic>.from(sportSkillsRaw);
      sportSkillsNeedsMigration = true;
    } else if (sportSkillsRaw != null) {
      sportSkillsNeedsMigration = true;
    }
      if (sportSkillsMap != null) {
      for (final entry in sportSkillsMap.entries) {
        final key = entry.key.trim();
        if (key.isEmpty || entry.value is! Map) {
          continue;
        }
        sportSkills[key] = SportSkillProgress.fromMap(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    final matchHistory = _parseMatchHistoryList(data['matchHistory']);
    return UserProfile(
      userId: userId,
      username: (data['username'] ?? 'Username').toString(),
      realName: (data['realName'] ?? data['fullName'] ?? 'Name').toString(),
      email: (data['email'] ?? '').toString(),
      avatarFileId:
          data['avatarFileId']?.toString() ?? data['avatarBase64']?.toString(),
      age: ageVal is int
          ? ageVal
          : (ageVal is num
                ? ageVal.toInt()
                : int.tryParse((ageVal ?? '').toString())),
      gender: (data['gender'] ?? 'Male').toString(),
      heightCm: h is int
          ? h
          : (h is num ? h.toInt() : int.tryParse((h ?? '').toString())),
      skillLevel: (data['skillLevel'] ?? 'Beginner').toString(),
      skillTierLevel: _parseInt(
        data['skillTierLevel'],
        fallback: 1,
      ).clamp(1, 10),
      skillTierProgress: _parseInt(data['skillTierProgress'], fallback: 0),
      sportSkills: sportSkills,
      sportSkillsNeedsMigration: sportSkillsNeedsMigration,
      preferredSports: preferredSports,
      emergencyContact: (data['emergencyContact'] ?? '').toString(),
      bio: (data['bio'] ?? '').toString(),
      notificationsEnabled: notif is bool
          ? notif
          : (notif is String ? notif.toLowerCase() == 'true' : true),
      matchWins: _parseInt(data['matchWins'], fallback: 0).clamp(0, 999999),
      matchDraws: _parseInt(data['matchDraws'], fallback: 0).clamp(0, 999999),
      matchLosses: _parseInt(data['matchLosses'], fallback: 0).clamp(0, 999999),
      matchHistory: matchHistory,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'realName': realName,
      'email': email,
      'avatarFileId': avatarFileId,
      'age': age,
      'gender': gender,
      'heightCm': heightCm,
      'skillLevel': skillLevel,
      'skillTierLevel': skillTierLevel,
      'skillTierProgress': skillTierProgress,
      'sportSkills': jsonEncode(
        sportSkills.map((key, value) => MapEntry(key, value.toMap())),
      ),
      'preferredSports': preferredSports.toList(),
      'emergencyContact': emergencyContact,
      'bio': bio,
      'notificationsEnabled': notificationsEnabled,
      'matchWins': matchWins,
      'matchDraws': matchDraws,
      'matchLosses': matchLosses,
      'matchHistory': jsonEncode(matchHistory.map((e) => e.toJson()).toList()),
    };
  }

  UserProfile copyWith({
    String? username,
    String? realName,
    String? email,
    String? avatarFileId,
    int? age,
    String? gender,
    int? heightCm,
    String? skillLevel,
    int? skillTierLevel,
    int? skillTierProgress,
    Map<String, SportSkillProgress>? sportSkills,
    bool? sportSkillsNeedsMigration,
    Set<String>? preferredSports,
    String? emergencyContact,
    String? bio,
    bool? notificationsEnabled,
    int? matchWins,
    int? matchDraws,
    int? matchLosses,
    List<ProfileMatchRecord>? matchHistory,
  }) {
    return UserProfile(
      userId: userId,
      username: username ?? this.username,
      realName: realName ?? this.realName,
      email: email ?? this.email,
      avatarFileId: avatarFileId ?? this.avatarFileId,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      skillLevel: skillLevel ?? this.skillLevel,
      skillTierLevel: skillTierLevel ?? this.skillTierLevel,
      skillTierProgress: skillTierProgress ?? this.skillTierProgress,
      sportSkills: sportSkills ?? this.sportSkills,
      sportSkillsNeedsMigration:
          sportSkillsNeedsMigration ?? this.sportSkillsNeedsMigration,
      preferredSports: preferredSports ?? this.preferredSports,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      bio: bio ?? this.bio,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      matchWins: matchWins ?? this.matchWins,
      matchDraws: matchDraws ?? this.matchDraws,
      matchLosses: matchLosses ?? this.matchLosses,
      matchHistory: matchHistory ?? this.matchHistory,
    );
  }
}

List<ProfileMatchRecord> _parseMatchHistoryList(Object? raw) {
  if (raw == null) {
    return const [];
  }
  try {
    if (raw is String && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      return _matchHistoryFromDecoded(decoded);
    }
    return _matchHistoryFromDecoded(raw);
  } catch (_) {
    return const [];
  }
}

List<ProfileMatchRecord> _matchHistoryFromDecoded(Object? decoded) {
  if (decoded is! List) {
    return const [];
  }
  final out = <ProfileMatchRecord>[];
  for (final item in decoded) {
    if (item is Map) {
      out.add(
        ProfileMatchRecord.fromJson(Map<String, dynamic>.from(item)),
      );
    }
  }
  return out;
}

class SportSkillProgress {
  final int tierLevel; // 1..10
  final int tierProgress; // points within current tier
  final int matchesPlayed;

  const SportSkillProgress({
    this.tierLevel = 1,
    this.tierProgress = 0,
    this.matchesPlayed = 0,
  });

  factory SportSkillProgress.fromMap(Map<String, dynamic> data) {
    return SportSkillProgress(
      tierLevel: _parseInt(data['tierLevel'], fallback: 1).clamp(1, 10),
      tierProgress: _parseInt(
        data['tierProgress'],
        fallback: 0,
      ).clamp(0, 999999),
      matchesPlayed: _parseInt(
        data['matchesPlayed'],
        fallback: 0,
      ).clamp(0, 999999),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tierLevel': tierLevel,
      'tierProgress': tierProgress,
      'matchesPlayed': matchesPlayed,
    };
  }

  SportSkillProgress copyWith({
    int? tierLevel,
    int? tierProgress,
    int? matchesPlayed,
  }) {
    return SportSkillProgress(
      tierLevel: tierLevel ?? this.tierLevel,
      tierProgress: tierProgress ?? this.tierProgress,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
    );
  }
}

int _parseInt(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}
