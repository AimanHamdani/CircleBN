import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../auth/current_user.dart';
import '../../../data/event_registration_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/event.dart';
import '../../../models/user_profile.dart';
import '../../theme/app_theme.dart';

class EventScoringArgs {
  final Event event;

  const EventScoringArgs({required this.event});
}

class EventScoringScreen extends StatefulWidget {
  static const routeName = '/event/score';

  const EventScoringScreen({super.key});

  @override
  State<EventScoringScreen> createState() => _EventScoringScreenState();
}

class _EventScoringScreenState extends State<EventScoringScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _forceEnableEditing = false;
  String? _error;
  List<UserProfile> _players = const [];
  final List<_MatchEntry> _matches = <_MatchEntry>[];
  static const List<int> _levelThresholds = <int>[
    10, // 1 -> 2
    15, // 2 -> 3
    20, // 3 -> 4
    25, // 4 -> 5
    35, // 5 -> 6
    45, // 6 -> 7
    60, // 7 -> 8
    80, // 8 -> 9
    100, // 9 -> 10
  ];

  EventScoringArgs _argsFromRoute(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is EventScoringArgs) {
      return args;
    }
    if (args is Event) {
      return EventScoringArgs(event: args);
    }
    return EventScoringArgs(
      event: Event(
        id: 'missing',
        title: 'Event',
        sport: 'Sport',
        startAt: DateTime.now(),
        duration: const Duration(hours: 1),
        location: 'Location',
        joined: 0,
        capacity: 0,
        skillLevel: 'Any',
        entryFeeLabel: 'Free',
        description: '',
        joinedByMe: false,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && _players.isEmpty && _error == null) {
      _loadPlayers();
    }
  }

  @override
  void dispose() {
    for (final match in _matches) {
      match.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    final event = _argsFromRoute(context).event;
    final isCreator = (event.creatorId ?? '').trim() == currentUserId;
    if (!isCreator) {
      setState(() {
        _isLoading = false;
        _error = 'Only the event creator can add scores.';
      });
      return;
    }

    try {
      final ids = await eventRegistrationRepository().listParticipantUserIds(
        event.id,
      );
      final profiles = await profileRepository().getProfilesByIds(ids);
      final merged = <UserProfile>[...profiles];
      if (_isHostAndPlay(event)) {
        final hostId = (event.creatorId ?? currentUserId).trim();
        if (hostId.isNotEmpty && !merged.any((p) => p.userId == hostId)) {
          try {
            final host = await profileRepository().getProfileById(hostId);
            merged.insert(0, host);
          } catch (_) {}
        }
      }
      setState(() {
        _players = merged;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = 'Could not load participants for scoring.';
      });
    }
  }

  Future<void> _addMatchDialog() async {
    var isSingles = true;
    var teamSize = 1;
    var bestOf = 3;
    final created = await showDialog<_MatchSetup>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Add Match'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Match format'),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('1v1'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Team game'),
                        icon: Icon(Icons.groups_2_outlined),
                      ),
                    ],
                    selected: {isSingles},
                    onSelectionChanged: (selected) {
                      final pickedSingles = selected.first;
                      setLocal(() {
                        isSingles = pickedSingles;
                        if (isSingles) {
                          teamSize = 1;
                        } else if (teamSize < 2) {
                          teamSize = 2;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Players per team'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CircleStepButton(
                        icon: Icons.remove,
                        onTap: isSingles
                            ? null
                            : teamSize > 2
                            ? () => setLocal(() => teamSize--)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$teamSize',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _CircleStepButton(
                        icon: Icons.add,
                        onTap: isSingles
                            ? null
                            : teamSize < 20
                            ? () => setLocal(() => teamSize++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Best of'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: bestOf,
                    items: const [1, 3, 5]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('Best of $v'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setLocal(() => bestOf = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _MatchSetup(
                      isSingles: isSingles,
                      teamSize: teamSize,
                      bestOf: bestOf,
                    ),
                  ),
                  child: const Text('Add match'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == null) {
      return;
    }

    setState(() {
      _matches.add(
        _MatchEntry.create(
          matchNumber: _matches.length + 1,
          isSingles: created.isSingles,
          teamSize: created.teamSize,
          bestOf: created.bestOf,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = _argsFromRoute(context);
    final event = args.event;
    final sportRules = _rulesForSport(event.sport);
    final canEditScores = _forceEnableEditing || _canEditForEventTiming(event);
    final isAdvancedTheme =
        sportRules.isFootballAdvanced || sportRules.isBasketballAdvanced;
    final themedPrimary = sportRules.isBasketballAdvanced
        ? const Color(0xFFE85D04)
        : const Color(0xFF0D8A66);

    return Theme(
      data: AppTheme.eventFlowTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: isAdvancedTheme
            ? (sportRules.isBasketballAdvanced
                  ? const Color(0xFFFAF3EE)
                  : const Color(0xFFEFF7F3))
            : const Color(0xFFF7F6FD),
        appBar: AppBar(
          backgroundColor: isAdvancedTheme ? themedPrimary : Colors.white,
          foregroundColor: isAdvancedTheme ? Colors.white : null,
          title: const Text(
            'Match Scores',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorBody(message: _error!)
            : sportRules.disableScoring
            ? _NoScoringBody(
                sport: event.sport,
                reason:
                    'Scoring is disabled for this activity. Running, jogging, swimming, and cycling are not score-based in this app.',
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: _EventScoringHeader(
                      title: event.title,
                      subtitle: '${event.sport} - editable by creator only',
                      themedPrimary: isAdvancedTheme ? themedPrimary : null,
                      helper: canEditScores
                          ? 'Customize match setup, teams, players, points, and assists.'
                          : 'Match has not started yet. Score editing will unlock at event start time.',
                    ),
                  ),
                  if (isAdvancedTheme)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _SportChip(
                          label: sportRules.isBasketballAdvanced
                              ? 'Basketball'
                              : 'Football',
                          color: themedPrimary,
                        ),
                      ),
                    ),
                  if (!_canEditForEventTiming(event))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: _forceEnableEditing
                              ? const Color(0xFFEFFCF4)
                              : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _forceEnableEditing
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFFCD34D),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _forceEnableEditing
                                    ? 'Testing mode enabled: you can edit scores before start time.'
                                    : 'Match has not started yet.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _forceEnableEditing = !_forceEnableEditing;
                                });
                              },
                              child: Text(
                                _forceEnableEditing
                                    ? 'Disable test mode'
                                    : 'Enable test mode',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (sportRules.showPointsSystemCard)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _PointsSystemCard(rules: sportRules),
                    ),
                  Expanded(
                    child: _matches.isEmpty
                        ? _EmptyAddMatchState(
                            enabled: canEditScores,
                            footballTheme: isAdvancedTheme,
                            themedPrimary: themedPrimary,
                            onTap: _addMatchDialog,
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              for (var i = 0; i < _matches.length; i++) ...[
                                _MatchCard(
                                  match: _matches[i],
                                  players: _players,
                                  canEdit: canEditScores,
                                  maxPointsPerEntry:
                                      sportRules.maxPointsPerEntry,
                                  isFootballAdvanced:
                                      sportRules.isFootballAdvanced,
                                  isBasketballAdvanced:
                                      sportRules.isBasketballAdvanced,
                                  onAddPlayerToTeamA: () {
                                    setState(() {
                                      _matches[i].teamA.add(
                                        _PlayerStatEntry.create(),
                                      );
                                    });
                                  },
                                  onAddPlayerToTeamB: () {
                                    setState(() {
                                      _matches[i].teamB.add(
                                        _PlayerStatEntry.create(),
                                      );
                                    });
                                  },
                                  onRemoveMatch: () {
                                    setState(() {
                                      final removed = _matches.removeAt(i);
                                      removed.dispose();
                                      for (
                                        var index = 0;
                                        index < _matches.length;
                                        index++
                                      ) {
                                        _matches[index].matchNumber = index + 1;
                                      }
                                    });
                                  },
                                  onRemoveTeamAPlayer: (playerIndex) {
                                    setState(() {
                                      if (_matches[i].teamA.length <= 1) {
                                        return;
                                      }
                                      final removed = _matches[i].teamA
                                          .removeAt(playerIndex);
                                      removed.dispose();
                                    });
                                  },
                                  onRemoveTeamBPlayer: (playerIndex) {
                                    setState(() {
                                      if (_matches[i].teamB.length <= 1) {
                                        return;
                                      }
                                      final removed = _matches[i].teamB
                                          .removeAt(playerIndex);
                                      removed.dispose();
                                    });
                                  },
                                  onAnyStatChanged: () {
                                    setState(() {});
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (sportRules.isFootballAdvanced ||
                                  sportRules.isBasketballAdvanced) ...[
                                _FootballAwardPreview(
                                  items: _buildAwardPreview(sportRules),
                                  themedPrimary: themedPrimary,
                                ),
                                const SizedBox(height: 12),
                              ],
                              _AddMatchButton(
                                enabled: canEditScores,
                                footballTheme: isAdvancedTheme,
                                themedPrimary: themedPrimary,
                                onTap: _addMatchDialog,
                              ),
                            ],
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: FilledButton(
                        onPressed:
                            !canEditScores || _isSubmitting || _matches.isEmpty
                            ? null
                            : () => _submitScores(event, sportRules),
                        style: FilledButton.styleFrom(
                          backgroundColor: isAdvancedTheme
                              ? themedPrimary
                              : null,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(
                          _isSubmitting ? 'Submitting...' : 'Submit All Scores',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  bool _canEditForEventTiming(Event event) {
    final now = DateTime.now();
    return !now.isBefore(event.startAt);
  }

  bool _isHostAndPlay(Event event) {
    final role = (event.hostRole ?? '').trim().toLowerCase();
    return role == 'host & play' || role == 'host and play';
  }

  Future<void> _submitScores(Event event, _SportScoringRules rules) async {
    final awardedByUser = <String, int>{};
    for (final match in _matches) {
      for (final stat in [...match.teamA, ...match.teamB]) {
        final userId = stat.selectedUserId;
        if (userId == null || userId.trim().isEmpty) {
          continue;
        }
        final awarded = _awardForStat(stat, rules);
        awardedByUser[userId] = (awardedByUser[userId] ?? 0) + awarded;
      }
    }

    if (awardedByUser.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No participant scores found. Pick players and type points/assists first.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    var updatedCount = 0;
    final failedUsers = <String>[];
    final sportKey = event.sport.trim().isEmpty
        ? 'General'
        : event.sport.trim();
    for (final player in _players) {
      final awarded = awardedByUser[player.userId];
      if (awarded == null) {
        continue;
      }
      final currentSportSkill =
          player.sportSkills[sportKey] ?? const SportSkillProgress();
      final progression = _applyLevelProgress(
        currentLevel: currentSportSkill.tierLevel,
        currentProgress: currentSportSkill.tierProgress,
        awardedPoints: awarded,
      );
      final updatedSportSkill = currentSportSkill.copyWith(
        tierLevel: progression.level,
        tierProgress: progression.progress,
        matchesPlayed: currentSportSkill.matchesPlayed + 1,
      );
      final nextSportSkills = Map<String, SportSkillProgress>.from(
        player.sportSkills,
      )..[sportKey] = updatedSportSkill;
      final overall = _overallFromSportSkills(
        fallbackLevel: player.skillTierLevel,
        fallbackProgress: player.skillTierProgress,
        sportSkills: nextSportSkills,
      );
      final nextSkillLevel = _skillLabelFromTierLevel(overall.level);
      final nextProfile = player.copyWith(
        skillLevel: nextSkillLevel,
        sportSkills: nextSportSkills,
      );
      try {
        await profileRepository().saveProfileByUserId(
          nextProfile.copyWith(
            skillTierLevel: overall.level,
            skillTierProgress: overall.progress,
          ),
        );
        updatedCount++;
      } catch (_) {
        final displayName = player.realName.trim().isNotEmpty
            ? player.realName.trim()
            : player.username;
        failedUsers.add(displayName);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (failedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved scorecards for ${_matches.length} match${_matches.length == 1 ? '' : 'es'}. Updated $updatedCount profile${updatedCount == 1 ? '' : 's'}.',
          ),
        ),
      );
      Navigator.of(context).maybePop('scores_submitted');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Updated $updatedCount, failed ${failedUsers.length}: ${failedUsers.join(', ')}',
        ),
      ),
    );
  }

  _LevelProgression _applyLevelProgress({
    required int currentLevel,
    required int currentProgress,
    required int awardedPoints,
  }) {
    var level = currentLevel.clamp(1, 10);
    var progress = currentProgress;
    progress = (progress + awardedPoints).clamp(0, 999999);

    while (level < 10) {
      final threshold = _levelThresholds[level - 1];
      if (progress < threshold) {
        break;
      }
      progress -= threshold;
      level++;
    }

    if (level >= 10) {
      level = 10;
      progress = progress.clamp(0, 999999);
    }

    return _LevelProgression(level: level, progress: progress);
  }

  _LevelProgression _overallFromSportSkills({
    required int fallbackLevel,
    required int fallbackProgress,
    required Map<String, SportSkillProgress> sportSkills,
  }) {
    if (sportSkills.isEmpty) {
      return _LevelProgression(
        level: fallbackLevel.clamp(1, 10),
        progress: fallbackProgress.clamp(0, 999999),
      );
    }
    SportSkillProgress? top;
    for (final value in sportSkills.values) {
      final normalized = value.copyWith(
        tierLevel: value.tierLevel.clamp(1, 10),
        tierProgress: value.tierProgress.clamp(0, 999999),
      );
      if (top == null ||
          normalized.tierLevel > top.tierLevel ||
          (normalized.tierLevel == top.tierLevel &&
              normalized.tierProgress > top.tierProgress)) {
        top = normalized;
      }
    }
    if (top == null) {
      return _LevelProgression(
        level: fallbackLevel.clamp(1, 10),
        progress: fallbackProgress.clamp(0, 999999),
      );
    }
    return _LevelProgression(level: top.tierLevel, progress: top.tierProgress);
  }

  int _awardForStat(_PlayerStatEntry stat, _SportScoringRules rules) {
    if (rules.isFootballAdvanced || rules.isBasketballAdvanced) {
      var points = 0;
      switch (stat.footballResult) {
        case _FootballResult.win:
          points = 3;
          break;
        case _FootballResult.draw:
          points = rules.isFootballAdvanced ? 1 : 0;
          break;
        case _FootballResult.loss:
          points = 0;
          break;
      }

      final lossStreak = rules.isBasketballAdvanced
          ? (stat.hasFiveLossStreak ? 5 : 0)
          : (int.tryParse(stat.lossStreakCtrl.text.trim()) ?? 0);
      points += rules.isFootballAdvanced
          ? _footballStreakPenalty(lossStreak)
          : _basketballStreakPenalty(lossStreak);
      if (stat.isMvp) {
        points += 1;
      }
      return points;
    }

    final points = int.tryParse(stat.pointsCtrl.text.trim()) ?? 0;
    final assists = int.tryParse(stat.assistsCtrl.text.trim()) ?? 0;
    return (points + (assists * 0.5)).round();
  }

  int _footballStreakPenalty(int streak) {
    if (streak >= 7) {
      return -3;
    }
    if (streak >= 5) {
      return -2;
    }
    if (streak >= 3) {
      return -1;
    }
    return 0;
  }

  int _basketballStreakPenalty(int streak) {
    if (streak >= 5) {
      return -2;
    }
    return 0;
  }

  List<_AwardPreviewItem> _buildAwardPreview(_SportScoringRules rules) {
    final map = <String, int>{};
    final names = <String, String>{};
    final labels = <String, String>{};
    for (final stat in _matches.expand((m) => [...m.teamA, ...m.teamB])) {
      final userId = stat.selectedUserId;
      if (userId == null || userId.trim().isEmpty) {
        continue;
      }
      final awarded = _awardForStat(stat, rules);
      map[userId] = (map[userId] ?? 0) + awarded;
      labels[userId] = _awardLabelForStat(stat, rules);
      final profile = _players.where((p) => p.userId == userId);
      if (profile.isNotEmpty) {
        final p = profile.first;
        names[userId] = p.realName.trim().isNotEmpty ? p.realName : p.username;
      }
    }

    final items =
        map.entries
            .map(
              (entry) => _AwardPreviewItem(
                name: names[entry.key] ?? 'Player',
                points: entry.value,
                label: labels[entry.key] ?? '',
              ),
            )
            .toList()
          ..sort((a, b) => b.points.compareTo(a.points));
    return items;
  }

  String _awardLabelForStat(_PlayerStatEntry stat, _SportScoringRules rules) {
    final base = switch (stat.footballResult) {
      _FootballResult.win => 'WIN',
      _FootballResult.draw => rules.isFootballAdvanced ? 'DRAW' : 'LOSS',
      _FootballResult.loss => 'LOSS',
    };
    final streak = int.tryParse(stat.lossStreakCtrl.text.trim()) ?? 0;
    final streakLabel = rules.isFootballAdvanced
        ? (streak >= 7
              ? '7x'
              : streak >= 5
              ? '5x'
              : streak >= 3
              ? '3x'
              : '')
        : (stat.hasFiveLossStreak ? '5x' : '');
    final withPenalty = streakLabel.isEmpty ? base : '$base+$streakLabel';
    if (stat.isMvp) {
      return '$withPenalty+MVP';
    }
    return withPenalty;
  }
}

class _MatchSetup {
  final bool isSingles;
  final int teamSize;
  final int bestOf;

  const _MatchSetup({
    required this.isSingles,
    required this.teamSize,
    required this.bestOf,
  });
}

class _MatchEntry {
  int matchNumber;
  final bool isSingles;
  int bestOf;
  final TextEditingController teamANameCtrl;
  final TextEditingController teamBNameCtrl;
  final List<_PlayerStatEntry> teamA;
  final List<_PlayerStatEntry> teamB;

  _MatchEntry({
    required this.matchNumber,
    required this.isSingles,
    required this.bestOf,
    required this.teamANameCtrl,
    required this.teamBNameCtrl,
    required this.teamA,
    required this.teamB,
  });

  factory _MatchEntry.create({
    required int matchNumber,
    required bool isSingles,
    required int teamSize,
    required int bestOf,
  }) {
    final effectiveTeamSize = isSingles ? 1 : teamSize;
    return _MatchEntry(
      matchNumber: matchNumber,
      isSingles: isSingles,
      bestOf: bestOf,
      teamANameCtrl: TextEditingController(text: 'Team A'),
      teamBNameCtrl: TextEditingController(text: 'Team B'),
      teamA: List.generate(effectiveTeamSize, (_) => _PlayerStatEntry.create()),
      teamB: List.generate(effectiveTeamSize, (_) => _PlayerStatEntry.create()),
    );
  }

  void dispose() {
    teamANameCtrl.dispose();
    teamBNameCtrl.dispose();
    for (final p in teamA) {
      p.dispose();
    }
    for (final p in teamB) {
      p.dispose();
    }
  }
}

class _PlayerStatEntry {
  String? selectedUserId;
  final TextEditingController nameCtrl;
  final TextEditingController pointsCtrl;
  final TextEditingController assistsCtrl;
  final TextEditingController reboundsCtrl;
  final TextEditingController stealsCtrl;
  final TextEditingController blocksCtrl;
  final TextEditingController turnoversCtrl;
  final TextEditingController lossStreakCtrl;
  _FootballResult footballResult;
  bool isMvp;
  bool hasFiveLossStreak;

  _PlayerStatEntry({
    required this.selectedUserId,
    required this.nameCtrl,
    required this.pointsCtrl,
    required this.assistsCtrl,
    required this.reboundsCtrl,
    required this.stealsCtrl,
    required this.blocksCtrl,
    required this.turnoversCtrl,
    required this.lossStreakCtrl,
    required this.footballResult,
    required this.isMvp,
    required this.hasFiveLossStreak,
  });

  factory _PlayerStatEntry.create() {
    return _PlayerStatEntry(
      selectedUserId: null,
      nameCtrl: TextEditingController(),
      pointsCtrl: TextEditingController(text: '0'),
      assistsCtrl: TextEditingController(text: '0'),
      reboundsCtrl: TextEditingController(text: '0'),
      stealsCtrl: TextEditingController(text: '0'),
      blocksCtrl: TextEditingController(text: '0'),
      turnoversCtrl: TextEditingController(text: '0'),
      lossStreakCtrl: TextEditingController(text: '0'),
      footballResult: _FootballResult.draw,
      isMvp: false,
      hasFiveLossStreak: false,
    );
  }

  void dispose() {
    nameCtrl.dispose();
    pointsCtrl.dispose();
    assistsCtrl.dispose();
    reboundsCtrl.dispose();
    stealsCtrl.dispose();
    blocksCtrl.dispose();
    turnoversCtrl.dispose();
    lossStreakCtrl.dispose();
  }
}

enum _FootballResult { win, draw, loss }

class _EventScoringHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String helper;
  final Color? themedPrimary;

  const _EventScoringHeader({
    required this.title,
    required this.subtitle,
    required this.helper,
    this.themedPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: themedPrimary == null
              ? const [Color(0xFF7A2FD0), Color(0xFFA365EB)]
              : <Color>[
                  themedPrimary!,
                  Color.lerp(themedPrimary!, Colors.white, 0.2)!,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Skill thresholds map directly to ranks: Beginner -> Novice -> Intermediate -> Advanced -> Pro/Master.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SportChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SportChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _PointsSystemCard extends StatelessWidget {
  final _SportScoringRules rules;

  const _PointsSystemCard({required this.rules});

  @override
  Widget build(BuildContext context) {
    final accent = rules.isBasketballAdvanced
        ? const Color(0xFFC2410C)
        : const Color(0xFF0F766E);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rules.pointsSystemTitle,
            style: TextStyle(fontWeight: FontWeight.w900, color: accent),
          ),
          const SizedBox(height: 8),
          for (final line in rules.pointsSystemLines) ...[
            Text(
              line,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 6),
          Text(
            'Level threshold means rank tier progression (Beginner to Pro/Master).',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAddMatchState extends StatelessWidget {
  final bool enabled;
  final bool footballTheme;
  final Color themedPrimary;
  final VoidCallback onTap;

  const _EmptyAddMatchState({
    required this.enabled,
    required this.onTap,
    this.footballTheme = false,
    this.themedPrimary = const Color(0xFF0D8A66),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _AddMatchButton(
          enabled: enabled,
          onTap: onTap,
          footballTheme: footballTheme,
          themedPrimary: themedPrimary,
        ),
      ),
    );
  }
}

class _AddMatchButton extends StatelessWidget {
  final bool enabled;
  final bool footballTheme;
  final Color themedPrimary;
  final VoidCallback onTap;

  const _AddMatchButton({
    required this.enabled,
    required this.onTap,
    this.footballTheme = false,
    this.themedPrimary = const Color(0xFF0D8A66),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? (footballTheme
                      ? themedPrimary.withValues(alpha: 0.5)
                      : const Color(0xFFCEB2F9))
                : const Color(0xFFE3E5E8),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: enabled
                    ? (footballTheme
                          ? themedPrimary.withValues(alpha: 0.12)
                          : const Color(0xFFF1E8FF))
                    : const Color(0xFFF2F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add,
                color: enabled
                    ? (footballTheme ? themedPrimary : const Color(0xFF8B5CF6))
                    : const Color(0xFFAAB2BA),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Add match',
              style: TextStyle(
                color: enabled
                    ? (footballTheme ? themedPrimary : const Color(0xFF8B5CF6))
                    : const Color(0xFFAAB2BA),
                fontWeight: FontWeight.w900,
                fontSize: 20 / 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final _MatchEntry match;
  final List<UserProfile> players;
  final bool canEdit;
  final int? maxPointsPerEntry;
  final bool isFootballAdvanced;
  final bool isBasketballAdvanced;
  final VoidCallback onAddPlayerToTeamA;
  final VoidCallback onAddPlayerToTeamB;
  final VoidCallback onRemoveMatch;
  final ValueChanged<int> onRemoveTeamAPlayer;
  final ValueChanged<int> onRemoveTeamBPlayer;
  final VoidCallback onAnyStatChanged;

  const _MatchCard({
    required this.match,
    required this.players,
    required this.canEdit,
    required this.maxPointsPerEntry,
    required this.isFootballAdvanced,
    required this.isBasketballAdvanced,
    required this.onAddPlayerToTeamA,
    required this.onAddPlayerToTeamB,
    required this.onRemoveMatch,
    required this.onRemoveTeamAPlayer,
    required this.onRemoveTeamBPlayer,
    required this.onAnyStatChanged,
  });

  @override
  Widget build(BuildContext context) {
    void applyTeamResult({
      required bool isFromTeamA,
      required _FootballResult selected,
    }) {
      final ownTeam = isFromTeamA ? match.teamA : match.teamB;
      final opposingTeam = isFromTeamA ? match.teamB : match.teamA;
      _FootballResult ownResult;
      _FootballResult opposingResult;
      switch (selected) {
        case _FootballResult.draw:
          ownResult = _FootballResult.draw;
          opposingResult = _FootballResult.draw;
          break;
        case _FootballResult.win:
          ownResult = _FootballResult.win;
          opposingResult = _FootballResult.loss;
          break;
        case _FootballResult.loss:
          ownResult = _FootballResult.loss;
          opposingResult = _FootballResult.win;
          break;
      }
      for (final stat in ownTeam) {
        stat.footballResult = ownResult;
      }
      for (final stat in opposingTeam) {
        stat.footballResult = opposingResult;
      }
      onAnyStatChanged();
    }

    if (match.isSingles) {
      return _SinglesMatchCard(
        match: match,
        players: players,
        canEdit: canEdit,
        maxPointsPerEntry: maxPointsPerEntry,
        isFootballAdvanced: isFootballAdvanced,
        isBasketballAdvanced: isBasketballAdvanced,
        onRemoveMatch: onRemoveMatch,
        onAnyStatChanged: onAnyStatChanged,
        onTeamResultSelected: applyTeamResult,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFootballAdvanced
              ? const Color(0xFF67C7A5)
              : (isBasketballAdvanced
                    ? const Color(0xFFF59E66)
                    : const Color(0xFFCFB6F6)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Text(
                  'Match ${match.matchNumber}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isFootballAdvanced
                        ? const Color(0xFF0F766E)
                        : (isBasketballAdvanced
                              ? const Color(0xFFC2410C)
                              : const Color(0xFF6D28D9)),
                  ),
                ),
                const Spacer(),
                Text(
                  'Best of ${match.bestOf}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isFootballAdvanced
                        ? const Color(0xFF0F766E)
                        : (isBasketballAdvanced
                              ? const Color(0xFFC2410C)
                              : const Color(0xFF8B5CF6)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: canEdit ? onRemoveMatch : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: match.teamANameCtrl,
                    readOnly: !canEdit,
                    decoration: const InputDecoration(
                      labelText: 'Team A name',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'vs',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: match.teamBNameCtrl,
                    readOnly: !canEdit,
                    decoration: const InputDecoration(
                      labelText: 'Team B name',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.teamANameCtrl.text.trim().isNotEmpty
                      ? match.teamANameCtrl.text.trim()
                      : 'Team A',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < match.teamA.length; i++) ...[
                  _PlayerStatRow(
                    entry: match.teamA[i],
                    players: players,
                    canEdit: canEdit,
                    maxPointsPerEntry: maxPointsPerEntry,
                    isFootballAdvanced: isFootballAdvanced,
                    isBasketballAdvanced: isBasketballAdvanced,
                    onChanged: onAnyStatChanged,
                    onResultChanged: (result) =>
                        applyTeamResult(isFromTeamA: true, selected: result),
                    onRemove: canEdit && match.teamA.length > 1
                        ? () => onRemoveTeamAPlayer(i)
                        : null,
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: canEdit ? onAddPlayerToTeamA : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add player'),
                  ),
                ),
                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  match.teamBNameCtrl.text.trim().isNotEmpty
                      ? match.teamBNameCtrl.text.trim()
                      : 'Team B',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < match.teamB.length; i++) ...[
                  _PlayerStatRow(
                    entry: match.teamB[i],
                    players: players,
                    canEdit: canEdit,
                    maxPointsPerEntry: maxPointsPerEntry,
                    isFootballAdvanced: isFootballAdvanced,
                    isBasketballAdvanced: isBasketballAdvanced,
                    onChanged: onAnyStatChanged,
                    onResultChanged: (result) =>
                        applyTeamResult(isFromTeamA: false, selected: result),
                    onRemove: canEdit && match.teamB.length > 1
                        ? () => onRemoveTeamBPlayer(i)
                        : null,
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: canEdit ? onAddPlayerToTeamB : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add player'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SinglesMatchCard extends StatelessWidget {
  final _MatchEntry match;
  final List<UserProfile> players;
  final bool canEdit;
  final int? maxPointsPerEntry;
  final bool isFootballAdvanced;
  final bool isBasketballAdvanced;
  final VoidCallback onRemoveMatch;
  final VoidCallback onAnyStatChanged;
  final void Function({
    required bool isFromTeamA,
    required _FootballResult selected,
  })
  onTeamResultSelected;

  const _SinglesMatchCard({
    required this.match,
    required this.players,
    required this.canEdit,
    required this.maxPointsPerEntry,
    required this.isFootballAdvanced,
    required this.isBasketballAdvanced,
    required this.onRemoveMatch,
    required this.onAnyStatChanged,
    required this.onTeamResultSelected,
  });

  @override
  Widget build(BuildContext context) {
    final playerA = match.teamA.first;
    final playerB = match.teamB.first;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFootballAdvanced
              ? const Color(0xFF67C7A5)
              : (isBasketballAdvanced
                    ? const Color(0xFFF59E66)
                    : const Color(0xFFCFB6F6)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Match ${match.matchNumber} - 1v1',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isFootballAdvanced
                      ? const Color(0xFF0F766E)
                      : (isBasketballAdvanced
                            ? const Color(0xFFC2410C)
                            : const Color(0xFF6D28D9)),
                ),
              ),
              const Spacer(),
              Text(
                'Best of ${match.bestOf}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isFootballAdvanced
                      ? const Color(0xFF0F766E)
                      : (isBasketballAdvanced
                            ? const Color(0xFFC2410C)
                            : const Color(0xFF8B5CF6)),
                ),
              ),
              IconButton(
                onPressed: canEdit ? onRemoveMatch : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          _PlayerStatRow(
            entry: playerA,
            players: players,
            canEdit: canEdit,
            maxPointsPerEntry: maxPointsPerEntry,
            isFootballAdvanced: isFootballAdvanced,
            isBasketballAdvanced: isBasketballAdvanced,
            onChanged: onAnyStatChanged,
            onResultChanged: (result) =>
                onTeamResultSelected(isFromTeamA: true, selected: result),
            playerLabel: 'A',
          ),
          const SizedBox(height: 6),
          const Text(
            'vs',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 6),
          _PlayerStatRow(
            entry: playerB,
            players: players,
            canEdit: canEdit,
            maxPointsPerEntry: maxPointsPerEntry,
            isFootballAdvanced: isFootballAdvanced,
            isBasketballAdvanced: isBasketballAdvanced,
            onChanged: onAnyStatChanged,
            onResultChanged: (result) =>
                onTeamResultSelected(isFromTeamA: false, selected: result),
            playerLabel: 'B',
          ),
        ],
      ),
    );
  }
}

class _PlayerStatRow extends StatelessWidget {
  static const String _manualUserValue = '__manual__';

  final _PlayerStatEntry entry;
  final List<UserProfile> players;
  final bool canEdit;
  final int? maxPointsPerEntry;
  final bool isFootballAdvanced;
  final bool isBasketballAdvanced;
  final VoidCallback? onChanged;
  final ValueChanged<_FootballResult>? onResultChanged;
  final String? playerLabel;
  final VoidCallback? onRemove;

  const _PlayerStatRow({
    required this.entry,
    required this.players,
    required this.canEdit,
    required this.maxPointsPerEntry,
    required this.isFootballAdvanced,
    required this.isBasketballAdvanced,
    this.onChanged,
    this.onResultChanged,
    this.playerLabel,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final dropdownValue = entry.selectedUserId ?? _manualUserValue;
    final selectedResult =
        (!isFootballAdvanced &&
            isBasketballAdvanced &&
            entry.footballResult == _FootballResult.draw)
        ? _FootballResult.loss
        : entry.footballResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 4,
              child: DropdownButtonFormField<String>(
                initialValue: dropdownValue,
                isExpanded: true,
                onChanged: !canEdit
                    ? null
                    : (value) {
                        if (value == null || value == _manualUserValue) {
                          entry.selectedUserId = null;
                          return;
                        }
                        entry.selectedUserId = value;
                        final match = players.where((p) => p.userId == value);
                        if (match.isNotEmpty) {
                          final p = match.first;
                          entry.nameCtrl.text = p.realName.trim().isNotEmpty
                              ? p.realName.trim()
                              : p.username;
                        }
                      },
                items: [
                  const DropdownMenuItem(
                    value: _manualUserValue,
                    child: Text('Manual player'),
                  ),
                  ...players.map((p) {
                    final label = p.realName.trim().isNotEmpty
                        ? p.realName.trim()
                        : p.username;
                    return DropdownMenuItem(
                      value: p.userId,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Player',
                ),
              ),
            ),
            if (playerLabel != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text(
                  playerLabel!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: entry.nameCtrl,
                readOnly: !canEdit || entry.selectedUserId != null,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Name',
                ),
              ),
            ),
            if (isFootballAdvanced) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 58,
                child: TextField(
                  controller: entry.pointsCtrl,
                  readOnly: !canEdit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (_) {
                    _clampScoreController(
                      entry.pointsCtrl,
                      max: maxPointsPerEntry,
                    );
                    onChanged?.call();
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Pts',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 58,
                child: TextField(
                  controller: entry.assistsCtrl,
                  readOnly: !canEdit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  onChanged: (_) {
                    _clampScoreController(entry.assistsCtrl, max: 200);
                    onChanged?.call();
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Ast',
                  ),
                ),
              ),
            ],
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
            ],
          ],
        ),
        if (isFootballAdvanced || isBasketballAdvanced) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (isFootballAdvanced) ...[
                SizedBox(
                  width: 82,
                  child: TextField(
                    controller: entry.lossStreakCtrl,
                    readOnly: !canEdit,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'L-Stk',
                    ),
                    onChanged: (_) => onChanged?.call(),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isBasketballAdvanced) ...[
                FilterChip(
                  selected: entry.hasFiveLossStreak,
                  label: const Text('5-loss streak'),
                  onSelected: canEdit
                      ? (selected) {
                          entry.hasFiveLossStreak = selected;
                          onChanged?.call();
                        }
                      : null,
                ),
                const SizedBox(width: 10),
              ],
              _ResultSelector(
                selected: selectedResult,
                showDraw: isFootballAdvanced,
                enabled: canEdit,
                onSelected: (value) {
                  if (onResultChanged != null) {
                    onResultChanged!(value);
                  } else {
                    entry.footballResult = value;
                    onChanged?.call();
                  }
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: entry.isMvp,
                label: const Text('MVP'),
                onSelected: canEdit
                    ? (selected) {
                        entry.isMvp = selected;
                        onChanged?.call();
                      }
                    : null,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _BasketballStatField(
                label: 'PTS',
                controller: entry.pointsCtrl,
                canEdit: canEdit,
                max: maxPointsPerEntry,
                onChanged: onChanged,
              ),
              const SizedBox(width: 6),
              _BasketballStatField(
                label: 'AST',
                controller: entry.assistsCtrl,
                canEdit: canEdit,
                max: 200,
                onChanged: onChanged,
              ),
              const SizedBox(width: 6),
              _BasketballStatField(
                label: 'REB',
                controller: entry.reboundsCtrl,
                canEdit: canEdit,
                max: 200,
                onChanged: onChanged,
              ),
              const SizedBox(width: 6),
              _BasketballStatField(
                label: 'STL',
                controller: entry.stealsCtrl,
                canEdit: canEdit,
                max: 200,
                onChanged: onChanged,
              ),
              const SizedBox(width: 6),
              _BasketballStatField(
                label: 'BLK',
                controller: entry.blocksCtrl,
                canEdit: canEdit,
                max: 200,
                onChanged: onChanged,
              ),
              const SizedBox(width: 6),
              _BasketballStatField(
                label: 'TO',
                controller: entry.turnoversCtrl,
                canEdit: canEdit,
                max: 200,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BasketballStatField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool canEdit;
  final int? max;
  final VoidCallback? onChanged;

  const _BasketballStatField({
    required this.label,
    required this.controller,
    required this.canEdit,
    required this.max,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.5),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            readOnly: !canEdit,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (_) {
              _clampScoreController(controller, max: max);
              onChanged?.call();
            },
            decoration: const InputDecoration(isDense: true),
          ),
        ],
      ),
    );
  }
}

class _ResultSelector extends StatelessWidget {
  final _FootballResult selected;
  final bool showDraw;
  final bool enabled;
  final ValueChanged<_FootballResult> onSelected;

  const _ResultSelector({
    required this.selected,
    this.showDraw = true,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ResultPill(
          label: 'W',
          isSelected: selected == _FootballResult.win,
          selectedBg: const Color(0xFF16A34A),
          selectedFg: Colors.white,
          idleBg: const Color(0xFFE8F8EE),
          idleFg: const Color(0xFF16A34A),
          onTap: enabled ? () => onSelected(_FootballResult.win) : null,
        ),
        if (showDraw) ...[
          const SizedBox(width: 6),
          _ResultPill(
            label: 'D',
            isSelected: selected == _FootballResult.draw,
            selectedBg: const Color(0xFFF59E0B),
            selectedFg: Colors.white,
            idleBg: const Color(0xFFFFF4DE),
            idleFg: const Color(0xFFD97706),
            onTap: enabled ? () => onSelected(_FootballResult.draw) : null,
          ),
          const SizedBox(width: 6),
        ] else
          const SizedBox(width: 6),
        _ResultPill(
          label: 'L',
          isSelected: selected == _FootballResult.loss,
          selectedBg: const Color(0xFFDC2626),
          selectedFg: Colors.white,
          idleBg: const Color(0xFFFDE8E8),
          idleFg: const Color(0xFFDC2626),
          onTap: enabled ? () => onSelected(_FootballResult.loss) : null,
        ),
      ],
    );
  }
}

class _ResultPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color selectedBg;
  final Color selectedFg;
  final Color idleBg;
  final Color idleFg;
  final VoidCallback? onTap;

  const _ResultPill({
    required this.label,
    required this.isSelected,
    required this.selectedBg,
    required this.selectedFg,
    required this.idleBg,
    required this.idleFg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? selectedBg : idleBg;
    final fg = isSelected ? selectedFg : idleFg;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

void _clampScoreController(TextEditingController controller, {int? max}) {
  final raw = controller.text.trim();
  if (raw.isEmpty) {
    return;
  }
  final parsed = int.tryParse(raw);
  if (parsed == null) {
    controller.value = const TextEditingValue(
      text: '0',
      selection: TextSelection.collapsed(offset: 1),
    );
    return;
  }
  final clamped = max == null ? parsed : parsed.clamp(0, max);
  if (clamped.toString() != raw) {
    final next = clamped.toString();
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
}

class _CircleStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleStepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onTap == null
              ? const Color(0xFFF1F3F4)
              : const Color(0xFFF4EDFF),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: onTap == null
                ? const Color(0xFFDEE2E6)
                : const Color(0xFFD0B3FA),
          ),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _AwardPreviewItem {
  final String name;
  final int points;
  final String label;

  const _AwardPreviewItem({
    required this.name,
    required this.points,
    required this.label,
  });
}

class _FootballAwardPreview extends StatelessWidget {
  final List<_AwardPreviewItem> items;
  final Color themedPrimary;

  const _FootballAwardPreview({
    required this.items,
    required this.themedPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themedPrimary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POINTS TO BE AWARDED',
            style: TextStyle(fontWeight: FontWeight.w900, color: themedPrimary),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text(
              'Select players and set W/D/L to preview awarded points.',
              style: TextStyle(fontWeight: FontWeight.w600),
            )
          else
            for (final item in items) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (item.label.trim().isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: item.points >= 0
                            ? themedPrimary.withValues(alpha: 0.14)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: item.points >= 0
                              ? themedPrimary
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                  Text(
                    '${item.points >= 0 ? '+' : ''}${item.points} pts',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: item.points >= 0
                          ? themedPrimary
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;

  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _NoScoringBody extends StatelessWidget {
  final String sport;
  final String reason;

  const _NoScoringBody({required this.sport, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCCDF6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$sport does not require score entry',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF6D28D9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.66),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SportScoringRules {
  final bool disableScoring;
  final int? maxPointsPerEntry;
  final bool isFootballAdvanced;
  final bool isBasketballAdvanced;
  final bool showPointsSystemCard;
  final String pointsSystemTitle;
  final List<String> pointsSystemLines;
  final String Function(int points) skillFromPoints;

  const _SportScoringRules({
    required this.disableScoring,
    required this.maxPointsPerEntry,
    this.isFootballAdvanced = false,
    this.isBasketballAdvanced = false,
    this.showPointsSystemCard = false,
    this.pointsSystemTitle = 'Points system',
    this.pointsSystemLines = const <String>[],
    required this.skillFromPoints,
  });
}

_SportScoringRules _rulesForSport(String rawSport) {
  final sport = rawSport.trim().toLowerCase();
  if (sport.contains('run') ||
      sport.contains('jog') ||
      sport.contains('swim') ||
      sport.contains('cycl') ||
      sport.contains('walk') ||
      sport.contains('hike')) {
    return const _SportScoringRules(
      disableScoring: true,
      maxPointsPerEntry: null,
      isFootballAdvanced: false,
      isBasketballAdvanced: false,
      showPointsSystemCard: false,
      skillFromPoints: _defaultSkillByPoints,
    );
  }

  if (sport.contains('volley')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: 25,
      isFootballAdvanced: false,
      isBasketballAdvanced: false,
      showPointsSystemCard: false,
      skillFromPoints: _volleyballSkillByPoints,
    );
  }

  if (sport.contains('badminton')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: 21,
      isFootballAdvanced: false,
      isBasketballAdvanced: false,
      showPointsSystemCard: false,
      skillFromPoints: _badmintonSkillByPoints,
    );
  }

  if (sport.contains('table tennis') || sport.contains('ping pong')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: 11,
      isFootballAdvanced: false,
      isBasketballAdvanced: false,
      showPointsSystemCard: false,
      skillFromPoints: _tableTennisSkillByPoints,
    );
  }

  if (sport.contains('basketball')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: 999,
      isFootballAdvanced: false,
      isBasketballAdvanced: true,
      showPointsSystemCard: true,
      pointsSystemTitle: 'Basketball points system',
      pointsSystemLines: <String>[
        'Win: +3 pts',
        'Loss: 0 pt',
        '5-loss streak: -2 pts',
        'MVP bonus: +1 pt',
      ],
      skillFromPoints: _basketballSkillByPoints,
    );
  }

  if (sport.contains('football') ||
      sport.contains('soccer') ||
      sport.contains('futsal')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: 99,
      isFootballAdvanced: true,
      isBasketballAdvanced: false,
      showPointsSystemCard: true,
      pointsSystemTitle: 'Football points system',
      pointsSystemLines: <String>[
        'Win: +3 pts',
        'Draw: +1 pt',
        'Loss: 0 pt',
        'Losing streak penalties: 3L=-1, 5L=-2, 7L=-3 (milestone-based)',
        'MVP bonus: +1 pt',
      ],
      skillFromPoints: _footballSkillByPoints,
    );
  }

  if (sport.contains('pickleball')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: null,
      isFootballAdvanced: false,
      isBasketballAdvanced: false,
      showPointsSystemCard: false,
      skillFromPoints: _defaultSkillByPoints,
    );
  }

  if (sport.contains('tennis')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: null,
      isFootballAdvanced: false,
      isBasketballAdvanced: false,
      showPointsSystemCard: false,
      skillFromPoints: _defaultSkillByPoints,
    );
  }

  return const _SportScoringRules(
    disableScoring: false,
    maxPointsPerEntry: 200,
    isFootballAdvanced: false,
    isBasketballAdvanced: false,
    showPointsSystemCard: false,
    skillFromPoints: _defaultSkillByPoints,
  );
}

String _volleyballSkillByPoints(int points) {
  if (points <= 5) {
    return 'Beginner';
  }
  if (points <= 10) {
    return 'Novice';
  }
  if (points <= 15) {
    return 'Intermediate';
  }
  if (points <= 20) {
    return 'Advanced';
  }
  return 'Pro/Master';
}

String _badmintonSkillByPoints(int points) {
  if (points <= 4) {
    return 'Beginner';
  }
  if (points <= 8) {
    return 'Novice';
  }
  if (points <= 13) {
    return 'Intermediate';
  }
  if (points <= 17) {
    return 'Advanced';
  }
  return 'Pro/Master';
}

String _tableTennisSkillByPoints(int points) {
  if (points <= 2) {
    return 'Beginner';
  }
  if (points <= 4) {
    return 'Novice';
  }
  if (points <= 7) {
    return 'Intermediate';
  }
  if (points <= 9) {
    return 'Advanced';
  }
  return 'Pro/Master';
}

String _basketballSkillByPoints(int points) {
  if (points <= 5) {
    return 'Beginner';
  }
  if (points <= 11) {
    return 'Novice';
  }
  if (points <= 19) {
    return 'Intermediate';
  }
  if (points <= 28) {
    return 'Advanced';
  }
  return 'Pro/Master';
}

String _footballSkillByPoints(int points) {
  if (points <= 1) {
    return 'Beginner';
  }
  if (points <= 3) {
    return 'Novice';
  }
  if (points <= 5) {
    return 'Intermediate';
  }
  if (points <= 7) {
    return 'Advanced';
  }
  return 'Pro/Master';
}

String _defaultSkillByPoints(int points) {
  if (points <= 3) {
    return 'Beginner';
  }
  if (points <= 6) {
    return 'Novice';
  }
  if (points <= 10) {
    return 'Intermediate';
  }
  if (points <= 14) {
    return 'Advanced';
  }
  return 'Pro/Master';
}

class _LevelProgression {
  final int level;
  final int progress;

  const _LevelProgression({required this.level, required this.progress});
}

String _skillLabelFromTierLevel(int level) {
  final normalized = level.clamp(1, 10);
  if (normalized <= 2) {
    return 'Beginner';
  }
  if (normalized <= 4) {
    return 'Novice';
  }
  if (normalized <= 6) {
    return 'Intermediate';
  }
  if (normalized <= 8) {
    return 'Advanced';
  }
  return 'Pro/Master';
}
