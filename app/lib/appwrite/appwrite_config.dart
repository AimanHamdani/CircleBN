class AppwriteConfig {
  static const endpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://sgp.cloud.appwrite.io/v1',
  );
  static const projectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: '69bb8ea000301f1d7f61',
  );

  static const databaseId = String.fromEnvironment(
    'APPWRITE_DATABASE_ID',
    defaultValue: '69bb90c10008a2fd1e09',
  );
  static const eventsCollectionId = String.fromEnvironment(
    'APPWRITE_EVENTS_COLLECTION_ID',
    defaultValue: 'events',
  );
  static const clubsCollectionId = String.fromEnvironment(
    'APPWRITE_CLUBS_COLLECTION_ID',
    defaultValue: 'clubs',
  );
  static const profilesCollectionId = String.fromEnvironment(
    'APPWRITE_PROFILES_COLLECTION_ID',
    defaultValue: 'profiles',
  );
  static const eventRegistrationsCollectionId = String.fromEnvironment(
    'APPWRITE_EVENT_REGISTRATIONS_COLLECTION_ID',
    defaultValue: 'event_registrations',
  );
  static const notificationsCollectionId = String.fromEnvironment(
    'APPWRITE_NOTIFICATIONS_COLLECTION_ID',
    defaultValue: 'notifications',
  );
  static const clubMembersCollectionId = String.fromEnvironment(
    'APPWRITE_CLUB_MEMBERS_COLLECTION_ID',
    defaultValue: 'club_members',
  );
  static const promoteClubAdminFunctionId = String.fromEnvironment(
    'APPWRITE_PROMOTE_CLUB_ADMIN_FUNCTION_ID',
    defaultValue: 'promote_club_admin',
  );

  /// Optional. If set, [CreateEventScreen] calls this before saving when `clubId` is set or changed.
  static const validateEventClubHostFunctionId = String.fromEnvironment(
    'APPWRITE_VALIDATE_EVENT_CLUB_HOST_FUNCTION_ID',
    defaultValue: '69dc8eaf0020ba2a4801',
  );
  static const storageBucketId = '69bbaadc0033918d8bba';
  static const profileImagesBucketId = storageBucketId;
  static const eventImagesBucketId = storageBucketId;
  static const passwordRecoveryUrl = String.fromEnvironment(
    'APPWRITE_PASSWORD_RECOVERY_URL',
    defaultValue: 'https://example.com/recovery',
  );

  static bool get isConfigured => endpoint.isNotEmpty && projectId.isNotEmpty;
}

