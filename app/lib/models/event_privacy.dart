/// Stored in [Event.privacy]. Used for listing, invites, and join flows.
abstract final class EventPrivacy {
  static const String public = 'Public (anyone can join)';
  /// UI-only label for the first privacy step (never persist alone).
  static const String privateCombined = 'Private';
  static const String privateRequestJoin =
      'Private — request to join (creator approves)';
  static const String privateInviteSearch =
      'Private — invite users (search)';
  static const String privateClubNotify =
      'Private — club: notify all members';
  static const String legacyPrivateInvitesOnly = 'Private (invites only)';

  static bool isPublic(String? privacy) =>
      (privacy ?? '').trim().isEmpty ||
      (privacy ?? '').toLowerCase().contains('public');

  static bool isPrivateish(String? privacy) =>
      (privacy ?? '').toLowerCase().contains('private');

  /// Listed like a public event; join uses a request queue.
  static bool isRequestJoin(String? privacy) {
    final p = (privacy ?? '').toLowerCase();
    return p.contains('private') && p.contains('request');
  }

  /// Invite-only; [Event.invitedUserIds] is set manually (search) or via club notify.
  static bool isInviteSearch(String? privacy) {
    final p = (privacy ?? '').toLowerCase();
    if (!p.contains('private')) return false;
    if (p.contains('request')) return false;
    if (p.contains('invites only') || p.contains('club: notify')) {
      return false;
    }
    return p.contains('search') || p.contains('invite users');
  }

  /// Club-hosted: all club members (except creator) get invites.
  static bool wantsClubMemberInvites(String? privacy) {
    final p = (privacy ?? '').toLowerCase();
    return p.contains('invites only') || p.contains('club: notify');
  }

  /// Hide from default browse unless viewer is invited / creator / registered.
  static bool hidesFromPublicBrowse(String? privacy) {
    if (!isPrivateish(privacy)) return false;
    return !isRequestJoin(privacy);
  }

  /// Maps any private-ish stored value to one of the three concrete modes for UI.
  static String privateSubModeValue(String? privacy) {
    final p = privacy ?? '';
    if (isRequestJoin(p)) {
      return privateRequestJoin;
    }
    if (wantsClubMemberInvites(p)) {
      return privateClubNotify;
    }
    if (isPrivateish(p)) {
      return privateInviteSearch;
    }
    return privateRequestJoin;
  }
}
