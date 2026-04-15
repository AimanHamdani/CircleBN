import '../models/event.dart';

class SampleEvents {
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _atDaysFromToday(int daysFromToday, int hour, int minute) {
    final d = _today().add(Duration(days: daysFromToday));
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  static const String _creatorId = 'current_user_placeholder';

  // 5 upcoming sample events (today + future only).
  static final List<Event> all = <Event>[
    Event(
      id: 'morning_run',
      title: 'Morning Run',
      sport: 'Running / Jogging',
      startAt: _atDaysFromToday(0, 7, 0),
      duration: const Duration(hours: 1, minutes: 30),
      location: 'City Park',
      joined: 6,
      capacity: 20,
      skillLevel: '1 - 3',
      entryFeeLabel: 'Free',
      description:
          'Easy pace group run. Meet at the park entrance for warm-up and route briefing.',
      joinedByMe: true,
      creatorId: _creatorId,
      thumbnailFileId: null,
    ),
    Event(
      id: 'badminton_social',
      title: 'Badminton Social',
      sport: 'Badminton',
      startAt: _atDaysFromToday(1, 18, 30),
      duration: const Duration(hours: 2),
      location: 'Community Hall',
      joined: 10,
      capacity: 16,
      skillLevel: '1 - 4',
      entryFeeLabel: '\$3',
      description:
          'Friendly doubles rotation. Shuttlecocks provided. Bring your own racket.',
      joinedByMe: false,
      thumbnailFileId: null,
    ),
    Event(
      id: 'lets_go_volley',
      title: 'Let’s Go Volley!',
      sport: 'Volleyball',
      startAt: _atDaysFromToday(3, 19, 0),
      duration: const Duration(hours: 3),
      location: 'Stadium',
      joined: 7,
      capacity: 20,
      skillLevel: '1 - 4',
      entryFeeLabel: 'Free',
      description:
          'Casual games. We’ll split into teams, rotate, and keep it beginner-friendly.',
      joinedByMe: true,
      creatorId: _creatorId,
      thumbnailFileId: null,
    ),
    Event(
      id: 'cycle_together',
      title: 'Cycle Together',
      sport: 'Cycling',
      startAt: _atDaysFromToday(6, 8, 0),
      duration: const Duration(hours: 2),
      location: 'East Coast Loop',
      joined: 5,
      capacity: 12,
      skillLevel: '2 - 4',
      entryFeeLabel: 'Free',
      description:
          'Chill ride with regroup points. Helmet required. Bring water.',
      joinedByMe: false,
      thumbnailFileId: null,
    ),
    Event(
      id: 'swim_session',
      title: 'Swimming Session',
      sport: 'Swimming',
      startAt: _atDaysFromToday(10, 20, 0),
      duration: const Duration(hours: 1, minutes: 30),
      location: 'Sports Complex Pool',
      joined: 4,
      capacity: 10,
      skillLevel: '1 - 3',
      entryFeeLabel: '\$2',
      description:
          'Laps + technique drills. Any pace welcome; we’ll split lanes by speed.',
      joinedByMe: false,
      thumbnailFileId: null,
    ),
  ]..sort((a, b) => a.startAt.compareTo(b.startAt));
}
