import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';

import 'appwrite_config.dart';

class AppwriteService {
  AppwriteService._();

  static final Client _client = Client()
    ..setEndpoint(AppwriteConfig.endpoint)
    ..setProject(AppwriteConfig.projectId);

  static Databases get databases => Databases(_client);
  static Account get account => Account(_client);
  static Storage get storage => Storage(_client);

  static bool get isConfigured => AppwriteConfig.isConfigured;

  static Future<models.DocumentList> listDocuments({
    required String collectionId,
    List<String> queries = const [],
  }) async {
    return await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: collectionId,
      queries: queries,
    );
  }

  static Future<models.Document> getDocument({
    required String collectionId,
    required String documentId,
  }) async {
    return await databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: collectionId,
      documentId: documentId,
    );
  }

  static Future<models.Document> createOrUpdateDocument({
    required String collectionId,
    required String documentId,
    required Map<String, dynamic> data,
    List<String>? permissions,
  }) async {
    try {
      return await updateDocument(
        collectionId: collectionId,
        documentId: documentId,
        data: data,
        permissions: permissions,
      );
    } catch (_) {
      return await createDocument(
        collectionId: collectionId,
        documentId: documentId,
        data: data,
        permissions: permissions,
      );
    }
  }

  static Future<models.Document> createDocument({
    required String collectionId,
    required Map<String, dynamic> data,
    String? documentId,
    List<String>? permissions,
  }) async {
    return await databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: collectionId,
      documentId: documentId ?? ID.unique(),
      data: data,
      permissions: permissions,
    );
  }

  static Future<models.Document> updateDocument({
    required String collectionId,
    required String documentId,
    required Map<String, dynamic> data,
    List<String>? permissions,
  }) async {
    return await databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: collectionId,
      documentId: documentId,
      data: data,
      permissions: permissions,
    );
  }

  static Future<void> deleteDocument({
    required String collectionId,
    required String documentId,
  }) async {
    await databases.deleteDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: collectionId,
      documentId: documentId,
    );
  }

  static Future<models.File> uploadFile({
    required String bucketId,
    required String path,
    Uint8List? bytes,
    String? filename,
    String? fileId,
    List<String>? permissions,
  }) async {
    final resolvedFileId = fileId ?? _contentBasedFileId(bytes) ?? ID.unique();
    final inputFile = kIsWeb
        ? InputFile.fromBytes(
            bytes: bytes!,
            filename: filename ?? 'upload.jpg',
          )
        : InputFile.fromPath(path: path);

    try {
      return await storage.createFile(
        bucketId: bucketId,
        fileId: resolvedFileId,
        file: inputFile,
        permissions: permissions,
      );
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        return await storage.getFile(
          bucketId: bucketId,
          fileId: resolvedFileId,
        );
      }
      rethrow;
    }
  }

  static Future<Uint8List> getFileViewBytes({
    required String bucketId,
    required String fileId,
  }) async {
    return await storage.getFileView(
      bucketId: bucketId,
      fileId: fileId,
    );
  }

  static String? _contentBasedFileId(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    // JS-safe 32-bit FNV-1a hash for Flutter web compatibility.
    var hash = 0x811C9DC5;
    const prime = 0x01000193;
    const mask32 = 0xFFFFFFFF;

    for (final b in bytes) {
      hash ^= b;
      hash = (hash * prime) & mask32;
    }

    final hex = hash.toRadixString(16).padLeft(8, '0');
    return 'img_$hex';
  }
}

