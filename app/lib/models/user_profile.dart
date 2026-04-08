class UserProfile {
  final String userId;
  final String username;
  final String realName;
  final String email;
  final String? avatarFileId;
  final int? age;
  final String gender;
  final int? heightCm;
  final String skillLevel; // Beginner | Novice | Intermediate | Advanced | Pro/Master
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
      preferredSports: const {},
      emergencyContact: '',
      bio: '',
      notificationsEnabled: true,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> data, {required String userId}) {
    final notif = data['notificationsEnabled'];
    final h = data['heightCm'];
    final ageVal = data['age'];
    final sportsRaw = data['preferredSports'];
    final preferredSports = sportsRaw is List
        ? sportsRaw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toSet()
        : <String>{};
    return UserProfile(
      userId: userId,
      username: (data['username'] ?? 'Username').toString(),
      realName: (data['realName'] ?? data['fullName'] ?? 'Name').toString(),
      email: (data['email'] ?? '').toString(),
      avatarFileId: data['avatarFileId']?.toString() ?? data['avatarBase64']?.toString(),
      age: ageVal is int ? ageVal : (ageVal is num ? ageVal.toInt() : int.tryParse((ageVal ?? '').toString())),
      gender: (data['gender'] ?? 'Male').toString(),
      heightCm: h is int ? h : (h is num ? h.toInt() : int.tryParse((h ?? '').toString())),
      skillLevel: (data['skillLevel'] ?? 'Beginner').toString(),
      preferredSports: preferredSports,
      emergencyContact: (data['emergencyContact'] ?? '').toString(),
      bio: (data['bio'] ?? '').toString(),
      notificationsEnabled: notif is bool ? notif : (notif is String ? notif.toLowerCase() == 'true' : true),
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
      preferredSports: preferredSports ?? this.preferredSports,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      bio: bio ?? this.bio,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

