import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../auth/current_user.dart';
import '../models/user_profile.dart';

class ProfileRepository {
  Future<UserProfile> getMyProfile() async {
    final userId = currentUserId;
    String accountEmail = '';
    String accountName = '';
    try {
      final me = await AppwriteService.account.get();
      accountEmail = me.email;
      accountName = me.name;
    } catch (_) {}

    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return UserProfile.empty(userId).copyWith(
        email: accountEmail,
        realName: accountName.isNotEmpty ? accountName : null,
      );
    }

    try {
      final doc = await AppwriteService.getDocument(
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
      );
      final profile = UserProfile.fromMap(
        Map<String, dynamic>.from(doc.data),
        userId: userId,
      );
      return profile.copyWith(
        email: accountEmail.isNotEmpty ? accountEmail : null,
        realName: profile.realName == 'Name' && accountName.isNotEmpty ? accountName : null,
      );
    } catch (_) {
      return UserProfile.empty(userId).copyWith(
        email: accountEmail,
        realName: accountName.isNotEmpty ? accountName : null,
      );
    }
  }

  Future<UserProfile> saveMyProfile(UserProfile profile) async {
    try {
      if (profile.realName.trim().isNotEmpty) {
        await AppwriteService.account.updateName(name: profile.realName.trim());
      }
    } catch (_) {}

    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return profile;
    }

    final doc = await AppwriteService.createOrUpdateDocument(
      collectionId: AppwriteConfig.profilesCollectionId,
      documentId: profile.userId,
      data: profile.toMap(),
    );

    return UserProfile.fromMap(
      Map<String, dynamic>.from(doc.data),
      userId: profile.userId,
    );
  }
}

ProfileRepository profileRepository() => ProfileRepository();

