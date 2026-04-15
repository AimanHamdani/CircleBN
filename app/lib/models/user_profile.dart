import 'dart:convert';

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
    );
  }
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
