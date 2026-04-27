import '../auth/current_user.dart';
import '../models/club.dart';
import '../models/direct_message.dart';
import '../models/user_profile.dart';
import 'club_member_repository.dart';
import 'club_repository.dart';
import 'direct_message_repository.dart';
import 'membership_repository.dart';
import 'profile_repository.dart';

class AppPreloadService {
  String _cachedUserId = '';

  Future<MembershipStatus>? _membershipFuture;
  Future<UserProfile>? _myProfileFuture;
  Future<List<Club>>? _clubsFuture;
  Future<List<ClubMember>>? _membershipsFuture;
  Future<List<DirectMessageThread>>? _dmThreadsFuture;

  void _resetIfUserChanged() {
    final uid = currentUserId.trim();
    if (uid == _cachedUserId) {
      return;
    }
    _cachedUserId = uid;
    _membershipFuture = null;
    _myProfileFuture = null;
    _clubsFuture = null;
    _membershipsFuture = null;
    _dmThreadsFuture = null;
  }

  Future<MembershipStatus> membershipStatus({bool forceRefresh = false}) {
    _resetIfUserChanged();
    if (forceRefresh || _membershipFuture == null) {
      _membershipFuture = membershipRepository().getStatus();
    }
    return _membershipFuture!;
  }

  Future<UserProfile> myProfile({bool forceRefresh = false}) {
    _resetIfUserChanged();
    if (forceRefresh || _myProfileFuture == null) {
      _myProfileFuture = profileRepository().getMyProfile();
    }
    return _myProfileFuture!;
  }

  Future<List<Club>> clubs({bool forceRefresh = false}) {
    _resetIfUserChanged();
    if (forceRefresh || _clubsFuture == null) {
      _clubsFuture = clubRepository().listClubs();
    }
    return _clubsFuture!;
  }

  Future<List<ClubMember>> myClubMemberships({bool forceRefresh = false}) {
    _resetIfUserChanged();
    final uid = currentUserId.trim();
    if (uid.isEmpty) {
      return Future.value(const <ClubMember>[]);
    }
    if (forceRefresh || _membershipsFuture == null) {
      _membershipsFuture = clubMemberRepository().listMembershipsForUser(
        userId: uid,
      );
    }
    return _membershipsFuture!;
  }

  Future<List<DirectMessageThread>> myDmThreads({bool forceRefresh = false}) {
    _resetIfUserChanged();
    final uid = currentUserId.trim();
    if (uid.isEmpty) {
      return Future.value(const <DirectMessageThread>[]);
    }
    if (forceRefresh || _dmThreadsFuture == null) {
      _dmThreadsFuture = directMessageRepository().listThreadsForUser(
        userId: uid,
      );
    }
    return _dmThreadsFuture!;
  }

  void warmHomeData() {
    membershipStatus();
    myProfile();
  }

  void warmCircleData() {
    clubs();
    myClubMemberships();
    myDmThreads();
  }
}

final AppPreloadService _appPreloadService = AppPreloadService();

AppPreloadService appPreloadService() => _appPreloadService;
