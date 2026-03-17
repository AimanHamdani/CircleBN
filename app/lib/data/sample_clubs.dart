import '../models/club.dart';

class SampleData {
  static const List<String> sports = <String>[
    'Football',
    'Badminton',
    'Basketball',
    'Volleyball',
    'Tennis',
    'Pickleball',
    'Jogging / Running',
    'Swimming',
    'Cycling',
    'Table Tennis',
  ];

  static const List<Club> clubs = <Club>[
    Club(id: 'fc_velocity', name: 'FC Velocity', sports: {'Football'}),
    Club(id: 'smash_bros_sg', name: 'Smash Bros SG', sports: {'Badminton', 'Table Tennis'}),
    Club(id: 'volleyball_sg', name: 'Volleyball SG', sports: {'Volleyball'}),
    Club(id: 'hoop_dreams', name: 'Hoop Dreams', sports: {'Basketball'}),
    Club(id: 'run_collective', name: 'Run Collective', sports: {'Jogging / Running'}),
    Club(id: 'pickle_nation', name: 'Pickle Nation', sports: {'Pickleball', 'Tennis'}),
    Club(id: 'swimming_club_sg', name: 'Swimming Club SG', sports: {'Swimming'}),
    Club(id: 'cycle_together', name: 'Cycle Together', sports: {'Cycling'}),
    Club(id: 'table_tennis_club', name: 'Table Tennis Club', sports: {'Table Tennis'}),
    Club(id: 'tennis_enthusiasts', name: 'Tennis Enthusiasts', sports: {'Tennis'}),
  ];
}

