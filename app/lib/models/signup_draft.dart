class SignUpDraft {
  final String? email;
  final String? password;

  final String? fullName;
  final String? username;
  final DateTime? dateOfBirth;
  final String? gender; // 'Male' | 'Female'
  final int? heightCm;
  final String? emergencyContact;

  final Set<String> sports;
  final Set<String> clubIds;

  const SignUpDraft({
    this.email,
    this.password,
    this.fullName,
    this.username,
    this.dateOfBirth,
    this.gender,
    this.heightCm,
    this.emergencyContact,
    this.sports = const {},
    this.clubIds = const {},
  });

  SignUpDraft copyWith({
    String? email,
    String? password,
    String? fullName,
    String? username,
    DateTime? dateOfBirth,
    String? gender,
    int? heightCm,
    String? emergencyContact,
    Set<String>? sports,
    Set<String>? clubIds,
  }) {
    return SignUpDraft(
      email: email ?? this.email,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      sports: sports ?? this.sports,
      clubIds: clubIds ?? this.clubIds,
    );
  }
}

