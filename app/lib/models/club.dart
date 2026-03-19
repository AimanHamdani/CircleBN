class Club {
  final String id;
  final String name;
  final Set<String> sports;

  const Club({
    required this.id,
    required this.name,
    required this.sports,
  });

  factory Club.fromMap(Map<String, dynamic> data, {required String id}) {
    final rawSports = data['sports'];
    final parsedSports = rawSports is List
        ? rawSports.map((e) => e.toString()).toSet()
        : rawSports is String
            ? rawSports
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toSet()
            : <String>{};

    return Club(
      id: id,
      name: (data['name'] ?? data['title'] ?? 'Club').toString(),
      sports: parsedSports,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sports': sports.toList(),
    };
  }
}

