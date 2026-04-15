import '../models/club.dart';

class SampleData {
  /// Canonical list for signup, create event, create club, and club filters.
  static const List<String> sports = <String>[
    'Football',
    'Basketball',
    'Badminton',
    'Running / Jogging',
    'Cycling',
    'Pickleball',
    'Swimming',
    'Tennis',
    'Volleyball',
    'Table Tennis',
  ];

  static const List<Club> clubs = <Club>[
    Club(
      id: 'fc_velocity',
      name: 'FC Velocity',
      description: '',
      sports: {'Football'},
    ),
    Club(
      id: 'smash_bros_sg',
      name: 'Smash Bros SG',
      description: '',
      sports: {'Badminton', 'Table Tennis'},
    ),
    Club(
      id: 'volleyball_sg',
      name: 'Volleyball SG',
      description: '',
      sports: {'Volleyball'},
    ),
    Club(
      id: 'hoop_dreams',
      name: 'Hoop Dreams',
      description: '',
      sports: {'Basketball'},
    ),
    Club(
      id: 'run_collective',
      name: 'Run Collective',
      description: '',
      sports: {'Running / Jogging'},
    ),
    Club(
      id: 'pickle_nation',
      name: 'Pickle Nation',
      description: '',
      sports: {'Pickleball', 'Tennis'},
    ),
    Club(
      id: 'swimming_club_sg',
      name: 'Swimming Club SG',
      description: '',
      sports: {'Swimming'},
    ),
    Club(
      id: 'cycle_together',
      name: 'Cycle Together',
      description: '',
      sports: {'Cycling'},
    ),
    Club(
      id: 'table_tennis_club',
      name: 'Table Tennis Club',
      description: '',
      sports: {'Table Tennis'},
    ),
    Club(
      id: 'tennis_enthusiasts',
      name: 'Tennis Enthusiasts',
      description: '',
      sports: {'Tennis'},
    ),
  ];
}
