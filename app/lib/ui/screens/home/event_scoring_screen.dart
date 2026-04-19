import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../auth/current_user.dart';
import '../../../data/profile_repository.dart';
import '../../../models/event.dart';
import '../../../models/user_profile.dart';
import '../../../services/attendance_service.dart';
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
  bool _isFinalized = false;
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
      final attendance = await AttendanceService.getAttendanceList(event.id);
      final attendedIds = attendance.map((item) => item.userId).toList();
      final profiles = await profileRepository().getProfilesByIds(attendedIds);
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
        _error = merged.isEmpty
            ? 'No attended participants available for scoring yet.'
            : null;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = 'Could not load participants for scoring.';
      });
    }
  }

  Future<void> _addMatchDialog() async {
    final sport = _argsFromRoute(context).event.sport.trim().toLowerCase();
    final isRacketSport =
        sport.contains('badminton') ||
        sport.contains('tennis') ||
        sport.contains('pickle') ||
        sport.contains('table tennis') ||
        sport.contains('ping pong');
    var isSingles = true;
    var teamSize = 1;
    var bestOf = 3;
    if (isRacketSport) {
      if (sport.contains('pickle')) {
        isSingles = false;
        teamSize = 2;
        bestOf = 3;
      } else if (sport.contains('table tennis') ||
          sport.contains('ping pong')) {
        isSingles = true;
        teamSize = 1;
        bestOf = 5;
      } else {
        isSingles = true;
        teamSize = 1;
        bestOf = 3;
      }
    }
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
                        } else if (isRacketSport) {
                          teamSize = 2;
                        } else if (teamSize < 2) {
                          teamSize = 2;
                        }
                      });
                    },
                  ),
                  if (!isRacketSport) ...[
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
                  ],
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
    final sportKey = event.sport.trim().toLowerCase();
    final canEditScores =
        !_isFinalized && (_forceEnableEditing || _canEditForEventTiming(event));
    final isAdvancedTheme =
        sportRules.isFootballAdvanced ||
        sportRules.isBasketballAdvanced ||
        sportRules.isVolleyballAdvanced ||
        sportRules.isBadmintonAdvanced;
    final themedPrimary = sportRules.isBasketballAdvanced
        ? const Color(0xFFE85D04)
        : sportRules.isFootballAdvanced
        ? const Color(0xFF0D8A66)
        : sportRules.isBadmintonAdvanced && sportKey.contains('tennis')
        ? const Color(0xFF0E9F6E)
        : sportRules.isBadmintonAdvanced &&
              (sportKey.contains('pickle') || sportKey.contains('paddle'))
        ? const Color(0xFFE09C00)
        : sportRules.isBadmintonAdvanced &&
              (sportKey.contains('table tennis') ||
                  sportKey.contains('ping pong'))
        ? const Color(0xFFE11D48)
        : sportRules.isVolleyballAdvanced
        ? AppTheme.eventPurpleDeep
        : sportRules.isBadmintonAdvanced
        ? const Color(0xFF2B78C5)
        : AppTheme.eventPurple;

    return Theme(
      data: AppTheme.eventFlowTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: isAdvancedTheme
            ? (sportRules.isBasketballAdvanced
                  ? const Color(0xFFFAF3EE)
                  : sportRules.isFootballAdvanced
                  ? const Color(0xFFEFF7F3)
                  : sportRules.isBadmintonAdvanced
                  ? const Color(0xFFF1F7FF)
                  : const Color(0xFFF5F3FF))
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
            : ListView(
                padding: const EdgeInsets.only(top: 0, bottom: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: [
                        _EventScoringHeader(
                          title: event.title,
                          subtitle: '${event.sport} - editable by creator only',
                          themedPrimary: isAdvancedTheme ? themedPrimary : null,
                          helper: canEditScores
                              ? 'Customize match setup, teams, players, points, and assists.'
                              : 'Match has not started yet. Score editing will unlock at event start time.',
                        ),
                        if (isAdvancedTheme) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _SportChip(
                              label: sportRules.isBasketballAdvanced
                                  ? 'Basketball'
                                  : sportRules.isFootballAdvanced
                                  ? 'Football'
                                  : sportRules.isVolleyballAdvanced
                                  ? 'Volleyball'
                                  : sportRules.isBadmintonAdvanced
                                  ? event.sport
                                  : event.sport,
                              color: themedPrimary,
                            ),
                          ),
                        ],
                        if (!_canEditForEventTiming(event)) ...[
                          const SizedBox(height: 10),
                          Container(
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
                                      _forceEnableEditing =
                                          !_forceEnableEditing;
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
                        ],
                        if (_isFinalized) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFFCF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF86EFAC),
                              ),
                            ),
                            child: const Text(
                              'All scores are finalized. Editing is locked.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                        if (sportRules.showPointsSystemCard) ...[
                          const SizedBox(height: 10),
                          _PointsSystemCard(rules: sportRules),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        if (_matches.isEmpty) ...[
                          _EmptyAddMatchState(
                            enabled: canEditScores,
                            footballTheme: isAdvancedTheme,
                            themedPrimary: themedPrimary,
                            onTap: _addMatchDialog,
                          ),
                        ] else ...[
                          for (var i = 0; i < _matches.length; i++) ...[
                            _MatchCard(
                              match: _matches[i],
                              players: _players,
                              canEdit: canEditScores,
                              accentColor: themedPrimary,
                              sportKey: sportKey,
                              maxPointsPerEntry: sportRules.maxPointsPerEntry,
                              isFootballAdvanced: sportRules.isFootballAdvanced,
                              isBasketballAdvanced:
                                  sportRules.isBasketballAdvanced,
                              isVolleyballAdvanced:
                                  sportRules.isVolleyballAdvanced,
                              isBadmintonAdvanced:
                                  sportRules.isBadmintonAdvanced,
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
                                  final removed = _matches[i].teamA.removeAt(
                                    playerIndex,
                                  );
                                  removed.dispose();
                                });
                              },
                              onRemoveTeamBPlayer: (playerIndex) {
                                setState(() {
                                  if (_matches[i].teamB.length <= 1) {
                                    return;
                                  }
                                  final removed = _matches[i].teamB.removeAt(
                                    playerIndex,
                                  );
                                  removed.dispose();
                                });
                              },
                              onAnyStatChanged: () {
                                _recomputeAutoStreaks();
                                setState(() {});
                                _matches[i].isDraftSubmitted = false;
                              },
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _matches[i].isDraftSubmitted
                                      ? Text(
                                          'Match ${_matches[i].matchNumber} draft submitted (still editable)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: themedPrimary,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                TextButton.icon(
                                  onPressed: canEditScores && !_isSubmitting
                                      ? () => _submitSingleMatchDraft(i)
                                      : null,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Submit match'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (sportRules.isFootballAdvanced ||
                              sportRules.isBasketballAdvanced ||
                              sportRules.isVolleyballAdvanced ||
                              sportRules.isBadmintonAdvanced) ...[
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
                        const SizedBox(height: 10),
                        SafeArea(
                          top: false,
                          child: FilledButton(
                            onPressed:
                                !canEditScores ||
                                    _isSubmitting ||
                                    _matches.isEmpty
                                ? null
                                : () async {
                                    final confirm =
                                        await _confirmFinalizeAllScores();
                                    if (!confirm) {
                                      return;
                                    }
                                    if (!mounted) {
                                      return;
                                    }
                                    await _submitScores(event, sportRules);
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: isAdvancedTheme
                                  ? themedPrimary
                                  : null,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: Text(
                              _isSubmitting
                                  ? 'Submitting...'
                                  : (_isFinalized
                                        ? 'Scores Finalized'
                                        : 'Submit All Scores'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  String _streakKeyForStat(_PlayerStatEntry stat) {
    final selectedId = (stat.selectedUserId ?? '').trim();
    if (selectedId.isNotEmpty) {
      return 'id:$selectedId';
    }
    final manualName = stat.nameCtrl.text.trim().toLowerCase();
    if (manualName.isNotEmpty) {
      return 'name:$manualName';
    }
    return '';
  }

  void _recomputeAutoStreaks() {
    final running = <String, ({int wins, int losses})>{};
    for (final match in _matches) {
      for (final stat in [...match.teamA, ...match.teamB]) {
        final key = _streakKeyForStat(stat);
        if (key.isEmpty) {
          stat.winStreak = 0;
          stat.lossStreakCtrl.text = '0';
          continue;
        }
        final prev = running[key] ?? (wins: 0, losses: 0);
        var wins = prev.wins;
        var losses = prev.losses;
        switch (stat.footballResult) {
          case _FootballResult.win:
            wins += 1;
            losses = 0;
            break;
          case _FootballResult.loss:
            losses += 1;
            wins = 0;
            break;
          case _FootballResult.draw:
            wins = 0;
            losses = 0;
            break;
        }
        stat.winStreak = wins;
        stat.lossStreakCtrl.text = '$losses';
        running[key] = (wins: wins, losses: losses);
      }
    }
  }

  Future<void> _submitScores(Event event, _SportScoringRules rules) async {
    _recomputeAutoStreaks();
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
      setState(() {
        _isFinalized = true;
        _forceEnableEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All scores finalized. Updated $updatedCount profile${updatedCount == 1 ? '' : 's'}. Editing is now locked.',
          ),
        ),
      );
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

  Future<bool> _confirmFinalizeAllScores() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit all scores?'),
        content: const Text(
          'This will finalize all submitted match data and lock score editing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (first != true) {
      return false;
    }
    if (!mounted) {
      return false;
    }

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final confirmation'),
        content: const Text(
          'After final submission, scores cannot be changed in this session. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Submit all'),
          ),
        ],
      ),
    );

    return second == true;
  }

  void _submitSingleMatchDraft(int index) {
    if (index < 0 || index >= _matches.length) {
      return;
    }
    final match = _matches[index];
    final selectedCount = [
      ...match.teamA.map((e) => e.selectedUserId),
      ...match.teamB.map((e) => e.selectedUserId),
    ].where((id) => (id ?? '').trim().isNotEmpty).length;

    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Match ${match.matchNumber} has no selected players yet.',
          ),
        ),
      );
      return;
    }

    setState(() {
      match.isDraftSubmitted = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Match ${match.matchNumber} submitted as draft. You can still edit it before final submit.',
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
    if (rules.isBadmintonAdvanced) {
      var points = 0;
      switch (stat.footballResult) {
        case _FootballResult.win:
          points = 3;
          break;
        case _FootballResult.draw:
          points = 0;
          break;
        case _FootballResult.loss:
          points = 0;
          break;
      }
      final streak = int.tryParse(stat.lossStreakCtrl.text.trim()) ?? 0;
      points += _footballStreakPenalty(streak);
      if (stat.isMvp) {
        points += 1;
      }
      return points;
    }
    if (rules.isVolleyballAdvanced) {
      var points = 0;
      switch (stat.footballResult) {
        case _FootballResult.win:
          points = 3;
          break;
        case _FootballResult.draw:
          points = 1;
          break;
        case _FootballResult.loss:
          points = 0;
          break;
      }
      final streak = int.tryParse(stat.lossStreakCtrl.text.trim()) ?? 0;
      if (streak >= 3) {
        points -= 1;
      }
      if (stat.isMvp) {
        points += 1;
      }
      return points;
    }
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

      final lossStreak = int.tryParse(stat.lossStreakCtrl.text.trim()) ?? 0;
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
    // Basketball no longer applies streak penalties.
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
    if (rules.isBadmintonAdvanced) {
      final base = switch (stat.footballResult) {
        _FootballResult.win => 'WIN',
        _FootballResult.draw => 'LOSS',
        _FootballResult.loss => 'LOSS',
      };
      final streak = int.tryParse(stat.lossStreakCtrl.text.trim()) ?? 0;
      final streakLabel = streak >= 7
          ? '7L'
          : streak >= 5
          ? '5L'
          : streak >= 3
          ? '3L'
          : '';
      final withPenalty = streakLabel.isEmpty ? base : '$base+$streakLabel';
      if (stat.isMvp) {
        return '$withPenalty+MVP';
      }
      return withPenalty;
    }
    if (rules.isVolleyballAdvanced) {
      final base = switch (stat.footballResult) {
        _FootballResult.win => 'WIN',
        _FootballResult.draw => 'DRAW',
        _FootballResult.loss => 'LOSS',
      };
      final streak = int.tryParse(stat.lossStreakCtrl.text.trim()) ?? 0;
      final streakLabel = streak >= 3 ? '3L' : '';
      final withPenalty = streakLabel.isEmpty ? base : '$base+$streakLabel';
      if (stat.isMvp) {
        return '$withPenalty+MVP';
      }
      return withPenalty;
    }
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
        : (streak >= 5 ? '5x' : '');
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
  bool isSingles;
  int bestOf;
  final TextEditingController teamANameCtrl;
  final TextEditingController teamBNameCtrl;
  final TextEditingController activeSetScoreACtrl;
  final TextEditingController activeSetScoreBCtrl;
  final List<_PlayerStatEntry> teamA;
  final List<_PlayerStatEntry> teamB;
  final List<_SavedSetScore?> savedSets;
  int activeSetIndex;
  int? editingSetIndex;

  _MatchEntry({
    required this.matchNumber,
    required this.isSingles,
    required this.bestOf,
    required this.teamANameCtrl,
    required this.teamBNameCtrl,
    required this.activeSetScoreACtrl,
    required this.activeSetScoreBCtrl,
    required this.teamA,
    required this.teamB,
    required this.savedSets,
    required this.activeSetIndex,
    required this.editingSetIndex,
    this.isDraftSubmitted = false,
  });

  bool isDraftSubmitted;

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
      activeSetScoreACtrl: TextEditingController(text: '0'),
      activeSetScoreBCtrl: TextEditingController(text: '0'),
      teamA: List.generate(effectiveTeamSize, (_) => _PlayerStatEntry.create()),
      teamB: List.generate(effectiveTeamSize, (_) => _PlayerStatEntry.create()),
      savedSets: List<_SavedSetScore?>.filled(bestOf, null),
      activeSetIndex: 0,
      editingSetIndex: null,
      isDraftSubmitted: false,
    );
  }

  void dispose() {
    teamANameCtrl.dispose();
    teamBNameCtrl.dispose();
    activeSetScoreACtrl.dispose();
    activeSetScoreBCtrl.dispose();
    for (final p in teamA) {
      p.dispose();
    }
    for (final p in teamB) {
      p.dispose();
    }
  }
}

class _SavedSetScore {
  final int index;
  int scoreA;
  int scoreB;

  _SavedSetScore({
    required this.index,
    required this.scoreA,
    required this.scoreB,
  });
}

class _PlayerStatEntry {
  String? selectedUserId;
  final TextEditingController nameCtrl;
  final TextEditingController pointsCtrl;
  final TextEditingController assistsCtrl;
  final TextEditingController badmintonSet1Ctrl;
  final TextEditingController badmintonSet2Ctrl;
  final TextEditingController badmintonPointsCtrl;
  final TextEditingController badmintonAceCtrl;
  final TextEditingController reboundsCtrl;
  final TextEditingController stealsCtrl;
  final TextEditingController blocksCtrl;
  final TextEditingController turnoversCtrl;
  final TextEditingController lossStreakCtrl;
  int winStreak;
  _FootballResult footballResult;
  bool isMvp;
  bool hasFiveLossStreak;

  _PlayerStatEntry({
    required this.selectedUserId,
    required this.nameCtrl,
    required this.pointsCtrl,
    required this.assistsCtrl,
    required this.badmintonSet1Ctrl,
    required this.badmintonSet2Ctrl,
    required this.badmintonPointsCtrl,
    required this.badmintonAceCtrl,
    required this.reboundsCtrl,
    required this.stealsCtrl,
    required this.blocksCtrl,
    required this.turnoversCtrl,
    required this.lossStreakCtrl,
    required this.winStreak,
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
      badmintonSet1Ctrl: TextEditingController(text: '0'),
      badmintonSet2Ctrl: TextEditingController(text: '0'),
      badmintonPointsCtrl: TextEditingController(text: '0'),
      badmintonAceCtrl: TextEditingController(text: '0'),
      reboundsCtrl: TextEditingController(text: '0'),
      stealsCtrl: TextEditingController(text: '0'),
      blocksCtrl: TextEditingController(text: '0'),
      turnoversCtrl: TextEditingController(text: '0'),
      lossStreakCtrl: TextEditingController(text: '0'),
      winStreak: 0,
      footballResult: _FootballResult.draw,
      isMvp: false,
      hasFiveLossStreak: false,
    );
  }

  void dispose() {
    nameCtrl.dispose();
    pointsCtrl.dispose();
    assistsCtrl.dispose();
    badmintonSet1Ctrl.dispose();
    badmintonSet2Ctrl.dispose();
    badmintonPointsCtrl.dispose();
    badmintonAceCtrl.dispose();
    reboundsCtrl.dispose();
    stealsCtrl.dispose();
    blocksCtrl.dispose();
    turnoversCtrl.dispose();
    lossStreakCtrl.dispose();
  }
}

enum _FootballResult { win, draw, loss }

bool _isSetLikeSport({
  required bool isVolleyballAdvanced,
  required bool isBadmintonAdvanced,
}) {
  return isVolleyballAdvanced || isBadmintonAdvanced;
}

bool _usesSetTerm({
  required String sportKey,
  required bool isVolleyballAdvanced,
}) {
  final normalized = sportKey.trim().toLowerCase();
  return isVolleyballAdvanced ||
      (normalized.contains('tennis') &&
          !normalized.contains('table tennis') &&
          !normalized.contains('ping pong'));
}

String _setUnitLabel({
  required String sportKey,
  required bool isVolleyballAdvanced,
  required int index,
}) {
  final usesSet = _usesSetTerm(
    sportKey: sportKey,
    isVolleyballAdvanced: isVolleyballAdvanced,
  );
  return '${usesSet ? 'Set' : 'Game'} ${index + 1}';
}

String _setSectionTitle({
  required String sportKey,
  required bool isVolleyballAdvanced,
}) {
  return _usesSetTerm(
        sportKey: sportKey,
        isVolleyballAdvanced: isVolleyballAdvanced,
      )
      ? 'SETS — PROGRESSIVE SAVE'
      : 'GAMES — PROGRESSIVE SAVE';
}

int _savedUnitWins(_MatchEntry match, {required bool forTeamA}) {
  var wins = 0;
  for (final item in match.savedSets) {
    if (item == null) {
      continue;
    }
    if (forTeamA && item.scoreA > item.scoreB) {
      wins += 1;
    } else if (!forTeamA && item.scoreB > item.scoreA) {
      wins += 1;
    }
  }
  return wins;
}

void _syncResultsFromSavedSets(
  _MatchEntry match, {
  required bool allowDraw,
  required bool syncPointField,
}) {
  final winsA = _savedUnitWins(match, forTeamA: true);
  final winsB = _savedUnitWins(match, forTeamA: false);
  _FootballResult resultA;
  _FootballResult resultB;
  if (winsA > winsB) {
    resultA = _FootballResult.win;
    resultB = _FootballResult.loss;
  } else if (winsB > winsA) {
    resultA = _FootballResult.loss;
    resultB = _FootballResult.win;
  } else {
    resultA = allowDraw ? _FootballResult.draw : _FootballResult.loss;
    resultB = allowDraw ? _FootballResult.draw : _FootballResult.loss;
  }
  for (final stat in match.teamA) {
    stat.footballResult = resultA;
    if (syncPointField) {
      stat.pointsCtrl.text = resultA == _FootballResult.win ? '1' : '0';
    }
  }
  for (final stat in match.teamB) {
    stat.footballResult = resultB;
    if (syncPointField) {
      stat.pointsCtrl.text = resultB == _FootballResult.win ? '1' : '0';
    }
  }
}

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

class _RacketFormatToggle extends StatelessWidget {
  final bool isSingles;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _RacketFormatToggle({
    required this.isSingles,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = const Color(0xFFC9D2DC);
    final selectedColor = const Color(0xFF42A5F5);
    final unselectedColor = const Color(0xFFE9ECEF);
    final selectedText = Colors.white;
    final unselectedText = const Color(0xFF6B7280);

    Widget pill({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? selectedColor : unselectedColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: selected ? selectedText : unselectedText,
              ),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.1),
        ),
        child: Row(
          children: [
            pill(
              label: 'Singles',
              selected: isSingles,
              onTap: () => onChanged(true),
            ),
            const SizedBox(width: 4),
            pill(
              label: 'Doubles',
              selected: !isSingles,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressiveSetPanel extends StatelessWidget {
  final _MatchEntry match;
  final bool canEdit;
  final Color accent;
  final String sportKey;
  final bool isVolleyballAdvanced;
  final String teamALabel;
  final String teamBLabel;
  final VoidCallback onChanged;

  const _ProgressiveSetPanel({
    required this.match,
    required this.canEdit,
    required this.accent,
    required this.sportKey,
    required this.isVolleyballAdvanced,
    required this.teamALabel,
    required this.teamBLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sectionTitle = _setSectionTitle(
      sportKey: sportKey,
      isVolleyballAdvanced: isVolleyballAdvanced,
    );

    void loadSetIntoEditor(int index) {
      final existing = match.savedSets[index];
      match.activeSetIndex = index;
      match.editingSetIndex = index;
      match.activeSetScoreACtrl.text = '${existing?.scoreA ?? 0}';
      match.activeSetScoreBCtrl.text = '${existing?.scoreB ?? 0}';
    }

    void stageNextUnsavedSet() {
      match.editingSetIndex = null;
      var nextIndex = match.bestOf;
      for (var i = 0; i < match.savedSets.length; i++) {
        if (match.savedSets[i] == null) {
          nextIndex = i;
          break;
        }
      }
      match.activeSetIndex = nextIndex.clamp(0, match.bestOf - 1);
      match.activeSetScoreACtrl.text = '0';
      match.activeSetScoreBCtrl.text = '0';
    }

    void adjustScore(TextEditingController ctrl, int delta) {
      final current = int.tryParse(ctrl.text.trim()) ?? 0;
      final next = (current + delta).clamp(0, 99);
      ctrl.value = TextEditingValue(
        text: '$next',
        selection: TextSelection.collapsed(offset: '$next'.length),
      );
      onChanged();
    }

    void saveCurrentSet() {
      final index = match.editingSetIndex ?? match.activeSetIndex;
      final scoreA = int.tryParse(match.activeSetScoreACtrl.text.trim()) ?? 0;
      final scoreB = int.tryParse(match.activeSetScoreBCtrl.text.trim()) ?? 0;
      match.savedSets[index] = _SavedSetScore(
        index: index,
        scoreA: scoreA,
        scoreB: scoreB,
      );
      stageNextUnsavedSet();
      onChanged();
    }

    final visibleIndices = <int>{};
    for (var i = 0; i < match.savedSets.length; i++) {
      if (match.savedSets[i] != null) {
        visibleIndices.add(i);
      }
    }
    if (match.editingSetIndex != null) {
      visibleIndices.add(match.editingSetIndex!);
    } else if (match.activeSetIndex < match.bestOf) {
      visibleIndices.add(match.activeSetIndex);
    }
    final ordered = visibleIndices.toList()..sort();
    final winsA = _savedUnitWins(match, forTeamA: true);
    final winsB = _savedUnitWins(match, forTeamA: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionTitle,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
              color: accent.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          for (final index in ordered) ...[
            if (match.savedSets[index] != null &&
                match.editingSetIndex != index)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_setUnitLabel(sportKey: sportKey, isVolleyballAdvanced: isVolleyballAdvanced, index: index)}: ${match.savedSets[index]!.scoreA} - ${match.savedSets[index]!.scoreB}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: canEdit
                          ? () {
                              loadSetIntoEditor(index);
                              onChanged();
                            }
                          : null,
                      child: const Text('Edit set'),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _setUnitLabel(
                              sportKey: sportKey,
                              isVolleyballAdvanced: isVolleyballAdvanced,
                              index: index,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: canEdit ? saveCurrentSet : null,
                          child: const Text('Save set'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SetScoreEditor(
                            label: teamALabel,
                            controller: match.activeSetScoreACtrl,
                            accent: accent,
                            canEdit: canEdit,
                            onMinus: () =>
                                adjustScore(match.activeSetScoreACtrl, -1),
                            onPlus: () =>
                                adjustScore(match.activeSetScoreACtrl, 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SetScoreEditor(
                            label: teamBLabel,
                            controller: match.activeSetScoreBCtrl,
                            accent: accent,
                            canEdit: canEdit,
                            onMinus: () =>
                                adjustScore(match.activeSetScoreBCtrl, -1),
                            onPlus: () =>
                                adjustScore(match.activeSetScoreBCtrl, 1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Text(
              winsA == winsB
                  ? 'Winner: not decided'
                  : 'Winner: ${winsA > winsB ? teamALabel : teamBLabel} ($winsA-$winsB)',
              style: TextStyle(fontWeight: FontWeight.w800, color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetScoreEditor extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color accent;
  final bool canEdit;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _SetScoreEditor({
    required this.label,
    required this.controller,
    required this.accent,
    required this.canEdit,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: accent),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CircleStepButton(
              icon: Icons.remove,
              onTap: canEdit ? onMinus : null,
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                controller.text.trim().isEmpty ? '0' : controller.text.trim(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: accent,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CircleStepButton(icon: Icons.add, onTap: canEdit ? onPlus : null),
          ],
        ),
      ],
    );
  }
}

class _PointsSystemCard extends StatelessWidget {
  final _SportScoringRules rules;

  const _PointsSystemCard({required this.rules});

  List<TextSpan> _buildColoredSpans(String line, {bool isValue = false}) {
    final defaultStyle = TextStyle(
      color: Colors.black.withValues(alpha: isValue ? 0.7 : 0.78),
      fontWeight: FontWeight.w700,
    );
    final pointPattern = RegExp(
      r'(\+\d+\s*pts?|\+\d+\s*pt|-\d+|0\s*pts?|MVP|no draw|draw)',
      caseSensitive: false,
    );
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in pointPattern.allMatches(line)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: line.substring(cursor, match.start),
            style: defaultStyle,
          ),
        );
      }
      final token = line.substring(match.start, match.end);
      final normalized = token.toLowerCase();
      Color tokenColor;
      if (normalized.contains('mvp') || normalized.contains('draw')) {
        tokenColor = const Color(0xFFD97706);
      } else if (normalized.startsWith('+')) {
        tokenColor = const Color(0xFF15803D);
      } else if (normalized.startsWith('-')) {
        tokenColor = const Color(0xFFB91C1C);
      } else {
        tokenColor = const Color(0xFF6B7280);
      }
      spans.add(
        TextSpan(
          text: token,
          style: defaultStyle.copyWith(
            color: tokenColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor), style: defaultStyle));
    }
    return spans;
  }

  (String left, String? right) _splitLine(String line) {
    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) {
      return (line.trim(), null);
    }
    final left = line.substring(0, colonIndex).trim();
    final right = line.substring(colonIndex + 1).trim();
    return (left, right);
  }

  String _symbolForLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('win')) {
      return '🏆';
    }
    if (normalized.contains('lose') || normalized.contains('loss')) {
      return '❌';
    }
    if (normalized.contains('streak')) {
      return '🔴';
    }
    if (normalized.contains('mvp')) {
      return '⭐';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final accent = rules.isBasketballAdvanced
        ? const Color(0xFFC2410C)
        : rules.isBadmintonAdvanced
        ? const Color(0xFF2B78C5)
        : rules.isVolleyballAdvanced
        ? AppTheme.eventPurpleDeep
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
            rules.pointsSystemTitle.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF8A8F98),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in rules.pointsSystemLines) ...[
            Builder(
              builder: (_) {
                final (left, right) = _splitLine(line);
                if (right == null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      left.toUpperCase(),
                      style: TextStyle(
                        color: const Color(0xFF8A8F98),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.35,
                      ),
                    ),
                  );
                }
                final symbol = _symbolForLabel(left);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final stackOnNarrow = constraints.maxWidth < 460;
                    if (stackOnNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (symbol.isNotEmpty) ...[
                                Text(
                                  symbol,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text.rich(
                                  TextSpan(children: _buildColoredSpans(left)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text.rich(
                              TextSpan(
                                children: _buildColoredSpans(
                                  right,
                                  isValue: true,
                                ),
                              ),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Row(
                            children: [
                              if (symbol.isNotEmpty) ...[
                                Text(
                                  symbol,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text.rich(
                                  TextSpan(children: _buildColoredSpans(left)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: Text.rich(
                            TextSpan(
                              children: _buildColoredSpans(
                                right,
                                isValue: true,
                              ),
                            ),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 4),
          ],
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
  final Color accentColor;
  final String sportKey;
  final int? maxPointsPerEntry;
  final bool isFootballAdvanced;
  final bool isBasketballAdvanced;
  final bool isVolleyballAdvanced;
  final bool isBadmintonAdvanced;
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
    required this.accentColor,
    required this.sportKey,
    required this.maxPointsPerEntry,
    required this.isFootballAdvanced,
    required this.isBasketballAdvanced,
    required this.isVolleyballAdvanced,
    required this.isBadmintonAdvanced,
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
        if (isBadmintonAdvanced) {
          stat.pointsCtrl.text = ownResult == _FootballResult.win ? '1' : '0';
        }
      }
      for (final stat in opposingTeam) {
        stat.footballResult = opposingResult;
        if (isBadmintonAdvanced) {
          stat.pointsCtrl.text = opposingResult == _FootballResult.win
              ? '1'
              : '0';
        }
      }
      onAnyStatChanged();
    }

    int teamTotalScore(List<_PlayerStatEntry> team) {
      if (_isSetLikeSport(
        isVolleyballAdvanced: isVolleyballAdvanced,
        isBadmintonAdvanced: isBadmintonAdvanced,
      )) {
        return identical(team, match.teamA)
            ? _savedUnitWins(match, forTeamA: true)
            : _savedUnitWins(match, forTeamA: false);
      }
      return team.fold<int>(0, (sum, stat) {
        return sum + (int.tryParse(stat.pointsCtrl.text.trim()) ?? 0);
      });
    }

    _FootballResult teamResult(List<_PlayerStatEntry> team) {
      if (team.isEmpty) {
        return _FootballResult.draw;
      }
      return team.first.footballResult;
    }

    _FootballResult autoTeamResult({
      required int ownTotal,
      required int opponentTotal,
    }) {
      if (ownTotal > opponentTotal) {
        return _FootballResult.win;
      }
      if (ownTotal < opponentTotal) {
        return _FootballResult.loss;
      }
      return isFootballAdvanced || isVolleyballAdvanced
          ? _FootballResult.draw
          : _FootballResult.loss;
    }

    void syncTeamResultsFromTotals() {
      if (_isSetLikeSport(
        isVolleyballAdvanced: isVolleyballAdvanced,
        isBadmintonAdvanced: isBadmintonAdvanced,
      )) {
        _syncResultsFromSavedSets(
          match,
          allowDraw: isVolleyballAdvanced,
          syncPointField: isBadmintonAdvanced,
        );
        return;
      }
      final totalA = teamTotalScore(match.teamA);
      final totalB = teamTotalScore(match.teamB);
      final resultA = autoTeamResult(ownTotal: totalA, opponentTotal: totalB);
      final resultB = autoTeamResult(ownTotal: totalB, opponentTotal: totalA);
      for (final player in match.teamA) {
        player.footballResult = resultA;
      }
      for (final player in match.teamB) {
        player.footballResult = resultB;
      }
    }

    void applyRacketFormat(bool singles) {
      if (!isBadmintonAdvanced || match.isSingles == singles) {
        return;
      }
      match.isSingles = singles;
      final targetSize = singles ? 1 : 2;
      while (match.teamA.length > targetSize) {
        match.teamA.removeLast().dispose();
      }
      while (match.teamB.length > targetSize) {
        match.teamB.removeLast().dispose();
      }
      while (match.teamA.length < targetSize) {
        match.teamA.add(_PlayerStatEntry.create());
      }
      while (match.teamB.length < targetSize) {
        match.teamB.add(_PlayerStatEntry.create());
      }
      onAnyStatChanged();
    }

    final accent = isFootballAdvanced
        ? const Color(0xFF0F766E)
        : (isBasketballAdvanced
              ? const Color(0xFFC2410C)
              : isBadmintonAdvanced
              ? accentColor
              : isVolleyballAdvanced
              ? AppTheme.eventPurpleDeep
              : const Color(0xFF6D28D9));

    if (match.isSingles) {
      syncTeamResultsFromTotals();
      return _SinglesMatchCard(
        match: match,
        players: players,
        canEdit: canEdit,
        maxPointsPerEntry: maxPointsPerEntry,
        isFootballAdvanced: isFootballAdvanced,
        isBasketballAdvanced: isBasketballAdvanced,
        isVolleyballAdvanced: isVolleyballAdvanced,
        isBadmintonAdvanced: isBadmintonAdvanced,
        accentColor: accent,
        sportKey: sportKey,
        onRemoveMatch: onRemoveMatch,
        onAnyStatChanged: onAnyStatChanged,
        onTeamResultSelected: applyTeamResult,
        onSwitchRacketFormat: isBadmintonAdvanced
            ? (isSingles) => applyRacketFormat(isSingles)
            : null,
      );
    }

    syncTeamResultsFromTotals();

    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Text(
                  'Match ${match.matchNumber}',
                  style: TextStyle(fontWeight: FontWeight.w900, color: accent),
                ),
                const Spacer(),
                if (!isFootballAdvanced && !isBasketballAdvanced) ...[
                  Text(
                    'Best of ${match.bestOf}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  onPressed: canEdit ? onRemoveMatch : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          if (isBadmintonAdvanced) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: _RacketFormatToggle(
                isSingles: match.isSingles,
                enabled: canEdit,
                onChanged: applyRacketFormat,
              ),
            ),
          ],
          if (_isSetLikeSport(
            isVolleyballAdvanced: isVolleyballAdvanced,
            isBadmintonAdvanced: isBadmintonAdvanced,
          )) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: _ProgressiveSetPanel(
                match: match,
                canEdit: canEdit,
                accent: accent,
                sportKey: sportKey,
                isVolleyballAdvanced: isVolleyballAdvanced,
                teamALabel: 'Team A',
                teamBLabel: 'Team B',
                onChanged: onAnyStatChanged,
              ),
            ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Team A',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('vs', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Team B',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Team A',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${teamTotalScore(match.teamA)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          color: accent,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SmallResultBadge(result: teamResult(match.teamA)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '-',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: accent.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Team B',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${teamTotalScore(match.teamB)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          color: accent,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SmallResultBadge(result: teamResult(match.teamB)),
                    ],
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
                  'PLAYERS — RESULT + STATS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.6,
                    color: accent.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Team A',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < match.teamA.length; i++) ...[
                  _PlayerStatRow(
                    entry: match.teamA[i],
                    players: players,
                    canEdit: canEdit,
                    accentColor: accent,
                    sportKey: sportKey,
                    maxPointsPerEntry: maxPointsPerEntry,
                    isFootballAdvanced: isFootballAdvanced,
                    isBasketballAdvanced: isBasketballAdvanced,
                    isVolleyballAdvanced: isVolleyballAdvanced,
                    isBadmintonAdvanced: isBadmintonAdvanced,
                    showResultSelector: isBadmintonAdvanced,
                    onChanged: onAnyStatChanged,
                    onResultChanged: isBadmintonAdvanced
                        ? (result) => applyTeamResult(
                            isFromTeamA: true,
                            selected: result,
                          )
                        : null,
                    onRemove: canEdit && match.teamA.length > 1
                        ? () => onRemoveTeamAPlayer(i)
                        : null,
                  ),
                  const SizedBox(height: 8),
                ],
                if (!isBadmintonAdvanced)
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
                  'Team B',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < match.teamB.length; i++) ...[
                  _PlayerStatRow(
                    entry: match.teamB[i],
                    players: players,
                    canEdit: canEdit,
                    accentColor: accent,
                    sportKey: sportKey,
                    maxPointsPerEntry: maxPointsPerEntry,
                    isFootballAdvanced: isFootballAdvanced,
                    isBasketballAdvanced: isBasketballAdvanced,
                    isVolleyballAdvanced: isVolleyballAdvanced,
                    isBadmintonAdvanced: isBadmintonAdvanced,
                    showResultSelector: isBadmintonAdvanced,
                    onChanged: onAnyStatChanged,
                    onResultChanged: isBadmintonAdvanced
                        ? (result) => applyTeamResult(
                            isFromTeamA: false,
                            selected: result,
                          )
                        : null,
                    onRemove: canEdit && match.teamB.length > 1
                        ? () => onRemoveTeamBPlayer(i)
                        : null,
                  ),
                  const SizedBox(height: 8),
                ],
                if (!isBadmintonAdvanced)
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
  final String sportKey;
  final int? maxPointsPerEntry;
  final bool isFootballAdvanced;
  final bool isBasketballAdvanced;
  final bool isVolleyballAdvanced;
  final bool isBadmintonAdvanced;
  final Color accentColor;
  final VoidCallback onRemoveMatch;
  final VoidCallback onAnyStatChanged;
  final void Function({
    required bool isFromTeamA,
    required _FootballResult selected,
  })
  onTeamResultSelected;
  final ValueChanged<bool>? onSwitchRacketFormat;

  const _SinglesMatchCard({
    required this.match,
    required this.players,
    required this.canEdit,
    required this.sportKey,
    required this.maxPointsPerEntry,
    required this.isFootballAdvanced,
    required this.isBasketballAdvanced,
    required this.isVolleyballAdvanced,
    required this.isBadmintonAdvanced,
    required this.accentColor,
    required this.onRemoveMatch,
    required this.onAnyStatChanged,
    required this.onTeamResultSelected,
    this.onSwitchRacketFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isSetLike = _isSetLikeSport(
      isVolleyballAdvanced: isVolleyballAdvanced,
      isBadmintonAdvanced: isBadmintonAdvanced,
    );
    final playerA = match.teamA.first;
    final playerB = match.teamB.first;
    final accent = isFootballAdvanced
        ? const Color(0xFF0F766E)
        : isBasketballAdvanced
        ? const Color(0xFFC2410C)
        : isBadmintonAdvanced
        ? accentColor
        : isVolleyballAdvanced
        ? AppTheme.eventPurpleDeep
        : const Color(0xFF6D28D9);

    if (isSetLike) {
      _syncResultsFromSavedSets(
        match,
        allowDraw: isVolleyballAdvanced,
        syncPointField: isBadmintonAdvanced,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Match ${match.matchNumber}',
                style: TextStyle(fontWeight: FontWeight.w900, color: accent),
              ),
              const Spacer(),
              if (!isFootballAdvanced && !isBasketballAdvanced)
                Text(
                  'Best of ${match.bestOf}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: accent),
                ),
              IconButton(
                onPressed: canEdit ? onRemoveMatch : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (isBadmintonAdvanced) ...[
            const SizedBox(height: 6),
            _RacketFormatToggle(
              isSingles: match.isSingles,
              enabled: canEdit && onSwitchRacketFormat != null,
              onChanged: (selected) => onSwitchRacketFormat!(selected),
            ),
          ],
          if (isSetLike) ...[
            const SizedBox(height: 6),
            _ProgressiveSetPanel(
              match: match,
              canEdit: canEdit,
              accent: accent,
              sportKey: sportKey,
              isVolleyballAdvanced: isVolleyballAdvanced,
              teamALabel: playerA.nameCtrl.text.trim().isEmpty
                  ? 'Player A'
                  : playerA.nameCtrl.text.trim(),
              teamBLabel: playerB.nameCtrl.text.trim().isEmpty
                  ? 'Player B'
                  : playerB.nameCtrl.text.trim(),
              onChanged: onAnyStatChanged,
            ),
            const SizedBox(height: 10),
          ],
          _PlayerStatRow(
            entry: playerA,
            players: players,
            canEdit: canEdit,
            accentColor: accent,
            sportKey: sportKey,
            maxPointsPerEntry: maxPointsPerEntry,
            isFootballAdvanced: isFootballAdvanced,
            isBasketballAdvanced: isBasketballAdvanced,
            isVolleyballAdvanced: isVolleyballAdvanced,
            isBadmintonAdvanced: isBadmintonAdvanced,
            showResultSelector: !isSetLike,
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
            accentColor: accent,
            sportKey: sportKey,
            maxPointsPerEntry: maxPointsPerEntry,
            isFootballAdvanced: isFootballAdvanced,
            isBasketballAdvanced: isBasketballAdvanced,
            isVolleyballAdvanced: isVolleyballAdvanced,
            isBadmintonAdvanced: isBadmintonAdvanced,
            showResultSelector: !isSetLike,
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
  final Color accentColor;
  final String sportKey;
  final int? maxPointsPerEntry;
  final bool isFootballAdvanced;
  final bool isBasketballAdvanced;
  final bool isVolleyballAdvanced;
  final bool isBadmintonAdvanced;
  final bool showResultSelector;
  final VoidCallback? onChanged;
  final ValueChanged<_FootballResult>? onResultChanged;
  final String? playerLabel;
  final VoidCallback? onRemove;

  const _PlayerStatRow({
    required this.entry,
    required this.players,
    required this.canEdit,
    required this.accentColor,
    required this.sportKey,
    required this.maxPointsPerEntry,
    required this.isFootballAdvanced,
    required this.isBasketballAdvanced,
    required this.isVolleyballAdvanced,
    required this.isBadmintonAdvanced,
    this.showResultSelector = true,
    this.onChanged,
    this.onResultChanged,
    this.playerLabel,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isFootballAdvanced
        ? const Color(0xFF0F766E)
        : isBasketballAdvanced
        ? const Color(0xFFC2410C)
        : isBadmintonAdvanced
        ? accentColor
        : isVolleyballAdvanced
        ? AppTheme.eventPurpleDeep
        : const Color(0xFF6D28D9);
    final dropdownValue = entry.selectedUserId ?? _manualUserValue;
    final selectedResult =
        (!isFootballAdvanced &&
            !isVolleyballAdvanced &&
            (isBasketballAdvanced || isBadmintonAdvanced) &&
            entry.footballResult == _FootballResult.draw)
        ? _FootballResult.loss
        : entry.footballResult;
    final lossStreak = int.tryParse(entry.lossStreakCtrl.text.trim()) ?? 0;
    final isTennis =
        sportKey.contains('tennis') &&
        !sportKey.contains('table tennis') &&
        !sportKey.contains('ping pong');
    final isTableTennis =
        sportKey.contains('table tennis') || sportKey.contains('ping pong');
    final primaryWinLabel = isTennis ? 'SETS W' : 'GAMES W';
    final pointsWonLabel = isTennis ? 'GAMES W' : 'PTS WON';
    final acesLabel = isTableTennis ? 'SERVE W' : 'ACES';
    final currentLossStreak =
        int.tryParse(entry.lossStreakCtrl.text.trim()) ?? 0;
    final currentWinStreak = entry.winStreak;
    var awardPreview = 0;
    if (isVolleyballAdvanced) {
      awardPreview = switch (selectedResult) {
        _FootballResult.win => 3,
        _FootballResult.draw => 1,
        _FootballResult.loss => 0,
      };
      if (lossStreak >= 3) {
        awardPreview -= 1;
      }
      if (entry.isMvp) {
        awardPreview += 1;
      }
    } else if (isFootballAdvanced ||
        isBasketballAdvanced ||
        isBadmintonAdvanced) {
      awardPreview = switch (selectedResult) {
        _FootballResult.win => 3,
        _FootballResult.draw => isFootballAdvanced ? 1 : 0,
        _FootballResult.loss => 0,
      };
      if (isBadmintonAdvanced) {
        if (lossStreak >= 7) {
          awardPreview -= 3;
        } else if (lossStreak >= 5) {
          awardPreview -= 2;
        } else if (lossStreak >= 3) {
          awardPreview -= 1;
        }
      } else {
        if (lossStreak >= 7) {
          awardPreview -= 3;
        } else if (lossStreak >= 5) {
          awardPreview -= 2;
        } else if (lossStreak >= 3) {
          awardPreview -= 1;
        }
      }
      if (entry.isMvp) {
        awardPreview += 1;
      }
    }

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
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  playerLabel!,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
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
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
            ],
          ],
        ),
        if (isFootballAdvanced ||
            isBasketballAdvanced ||
            isVolleyballAdvanced ||
            isBadmintonAdvanced) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (isFootballAdvanced ||
                  isBasketballAdvanced ||
                  isVolleyballAdvanced ||
                  isBadmintonAdvanced) ...[
                if (currentWinStreak > 0) ...[
                  _StreakBadge(
                    label: '$currentWinStreak W-streak',
                    bg: const Color(0xFFDCFCE7),
                    fg: const Color(0xFF166534),
                  ),
                  const SizedBox(width: 8),
                ] else if (currentLossStreak > 0) ...[
                  _StreakBadge(
                    label: '$currentLossStreak L-streak',
                    bg: const Color(0xFFFEE2E2),
                    fg: const Color(0xFF991B1B),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
              if (showResultSelector) ...[
                _ResultSelector(
                  selected: selectedResult,
                  showDraw: isFootballAdvanced || isVolleyballAdvanced,
                  enabled: canEdit,
                  onSelected: (value) {
                    if (onResultChanged != null) {
                      onResultChanged!(value);
                    } else {
                      entry.footballResult = value;
                      if (isBadmintonAdvanced) {
                        entry.pointsCtrl.text = value == _FootballResult.win
                            ? '1'
                            : '0';
                      }
                      onChanged?.call();
                    }
                  },
                ),
                const SizedBox(width: 8),
              ],
              FilterChip(
                selected: entry.isMvp,
                label: const Text('MVP'),
                selectedColor: const Color(0xFFFFF3C4),
                checkmarkColor: const Color(0xFFD97706),
                side: BorderSide(
                  color: entry.isMvp
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFE5E7EB),
                ),
                onSelected: canEdit
                    ? (selected) {
                        entry.isMvp = selected;
                        onChanged?.call();
                      }
                    : null,
              ),
              if (isFootballAdvanced ||
                  isBasketballAdvanced ||
                  isVolleyballAdvanced ||
                  isBadmintonAdvanced) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: awardPreview >= 0
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    awardPreview > 0
                        ? '+$awardPreview'
                        : awardPreview.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: awardPreview >= 0
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          if (isVolleyballAdvanced)
            Row(
              children: [
                _BasketballStatField(
                  label: 'PTS',
                  controller: entry.pointsCtrl,
                  canEdit: canEdit,
                  max: maxPointsPerEntry,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: 'AST',
                  controller: entry.assistsCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: 'BLK',
                  controller: entry.blocksCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                // Volleyball: store digs in reboundsCtrl (same entry as REB in basketball).
                _BasketballStatField(
                  label: 'DIG',
                  controller: entry.reboundsCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
              ],
            )
          else if (isFootballAdvanced)
            Row(
              children: [
                _BasketballStatField(
                  label: 'G',
                  controller: entry.pointsCtrl,
                  canEdit: canEdit,
                  max: maxPointsPerEntry,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: 'AST',
                  controller: entry.assistsCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: 'PASS',
                  controller: entry.reboundsCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: 'TKL',
                  controller: entry.stealsCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: 'SAV',
                  controller: entry.blocksCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
              ],
            )
          else if (isBadmintonAdvanced)
            Row(
              children: [
                _BasketballStatField(
                  label: primaryWinLabel,
                  controller: entry.pointsCtrl,
                  canEdit: canEdit,
                  max: 1,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: pointsWonLabel,
                  controller: entry.badmintonPointsCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: acesLabel,
                  controller: entry.badmintonAceCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
              ],
            )
          else
            Row(
              children: [
                _BasketballStatField(
                  label: 'PTS',
                  controller: entry.pointsCtrl,
                  canEdit: canEdit,
                  max: maxPointsPerEntry,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: 'AST',
                  controller: entry.assistsCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: 'REB',
                  controller: entry.reboundsCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: 'STL',
                  controller: entry.stealsCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: 'BLK',
                  controller: entry.blocksCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 6),
                _BasketballStatField(
                  label: 'TO',
                  controller: entry.turnoversCtrl,
                  canEdit: canEdit,
                  max: 200,
                  accent: accent,
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
  final Color accent;
  final VoidCallback? onChanged;

  const _BasketballStatField({
    required this.label,
    required this.controller,
    required this.canEdit,
    required this.max,
    required this.accent,
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
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: accent.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent.withValues(alpha: 0.45)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent, width: 1.4),
              ),
            ),
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

class _SmallResultBadge extends StatelessWidget {
  final _FootballResult result;

  const _SmallResultBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (result) {
      _FootballResult.win => (
        'W',
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
      ),
      _FootballResult.draw => (
        'D',
        const Color(0xFFFFF3C4),
        const Color(0xFFD97706),
      ),
      _FootballResult.loss => (
        'L',
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _StreakBadge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11),
      ),
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
        width: 36,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? bg : fg.withValues(alpha: 0.45),
          ),
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
  final bool isVolleyballAdvanced;
  final bool isBadmintonAdvanced;
  final bool showPointsSystemCard;
  final String pointsSystemTitle;
  final List<String> pointsSystemLines;
  final String Function(int points) skillFromPoints;

  const _SportScoringRules({
    required this.disableScoring,
    required this.maxPointsPerEntry,
    this.isFootballAdvanced = false,
    this.isBasketballAdvanced = false,
    this.isVolleyballAdvanced = false,
    this.isBadmintonAdvanced = false,
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
      isVolleyballAdvanced: false,
      isBadmintonAdvanced: false,
      showPointsSystemCard: false,
      skillFromPoints: _defaultSkillByPoints,
    );
  }

  if (sport.contains('volley')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: null,
      isFootballAdvanced: false,
      isBasketballAdvanced: false,
      isVolleyballAdvanced: true,
      isBadmintonAdvanced: false,
      showPointsSystemCard: true,
      pointsSystemTitle: 'Volleyball points system',
      pointsSystemLines: <String>[
        'Set target: 25 pts',
        'Win by 2 required (deuce can go beyond 25)',
        'Win: +3 pts',
        'Draw: +1 pt',
        'Loss: 0 pt',
        '3-loss streak: -1 pt',
        'MVP bonus: +1 pt',
      ],
      skillFromPoints: _volleyballSkillByPoints,
    );
  }

  if (sport.contains('badminton')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: null,
      isFootballAdvanced: false,
      isBasketballAdvanced: false,
      isVolleyballAdvanced: false,
      isBadmintonAdvanced: true,
      showPointsSystemCard: true,
      pointsSystemTitle: 'Badminton points system',
      pointsSystemLines: <String>[
        'Rally point to 21, win by 2',
        'Win match: +3 pts',
        'Lose match: 0 pts',
        '3/5/7-loss streak: -1/-2/-3',
        'MVP bonus: +1 pt (no draw)',
      ],
      skillFromPoints: _badmintonSkillByPoints,
    );
  }

  if (sport.contains('table tennis') || sport.contains('ping pong')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: null,
      isFootballAdvanced: false,
      isBasketballAdvanced: false,
      isVolleyballAdvanced: false,
      isBadmintonAdvanced: true,
      showPointsSystemCard: true,
      pointsSystemTitle: 'Table Tennis points system',
      pointsSystemLines: <String>[
        'Rally point to 11, win by 2',
        'Win match: +3 pts',
        'Lose match: 0 pts',
        '3/5/7-loss streak: -1/-2/-3',
        'MVP bonus: +1 pt (no draw)',
      ],
      skillFromPoints: _tableTennisSkillByPoints,
    );
  }

  if (sport.contains('basketball')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: 999,
      isFootballAdvanced: false,
      isBasketballAdvanced: true,
      isVolleyballAdvanced: false,
      isBadmintonAdvanced: false,
      showPointsSystemCard: true,
      pointsSystemTitle: 'Basketball points system',
      pointsSystemLines: <String>[
        'Win: +3 pts',
        'Loss: 0 pt',
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
      isVolleyballAdvanced: false,
      isBadmintonAdvanced: false,
      showPointsSystemCard: true,
      pointsSystemTitle: 'Football points system',
      pointsSystemLines: <String>[
        'Win: +3 pts',
        'Draw: +1 pt',
        'Loss: 0 pt',
        'Losing streak penalties: 3L=-1, 5L=-2, 7L=-3',
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
      isVolleyballAdvanced: false,
      isBadmintonAdvanced: true,
      showPointsSystemCard: true,
      pointsSystemTitle: 'Pickleball points system',
      pointsSystemLines: <String>[
        'Rally point to 11, win by 2',
        'Win match: +3 pts',
        'Lose match: 0 pts',
        '3/5/7-loss streak: -1/-2/-3',
        'MVP bonus: +1 pt (no draw)',
      ],
      skillFromPoints: _defaultSkillByPoints,
    );
  }

  if (sport.contains('tennis')) {
    return const _SportScoringRules(
      disableScoring: false,
      maxPointsPerEntry: null,
      isFootballAdvanced: false,
      isBasketballAdvanced: false,
      isVolleyballAdvanced: false,
      isBadmintonAdvanced: true,
      showPointsSystemCard: true,
      pointsSystemTitle: 'Tennis points system',
      pointsSystemLines: <String>[
        'Best of 3 sets, 6 games per set',
        'Win by 2 games, tiebreak at 6-6',
        'Win match: +3 pts',
        'Lose match: 0 pts',
        '3/5/7-loss streak: -1/-2/-3',
        'MVP bonus: +1 pt (no draw)',
      ],
      skillFromPoints: _defaultSkillByPoints,
    );
  }

  return const _SportScoringRules(
    disableScoring: false,
    maxPointsPerEntry: 200,
    isFootballAdvanced: false,
    isBasketballAdvanced: false,
    isVolleyballAdvanced: false,
    isBadmintonAdvanced: false,
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
