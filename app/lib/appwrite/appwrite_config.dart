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
    defaultValue: '',
  );
  static const profilesCollectionId = String.fromEnvironment(
    'APPWRITE_PROFILES_COLLECTION_ID',
    defaultValue: 'profiles',
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

