import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../models/club.dart';
import 'sample_clubs.dart';

abstract class ClubRepository {
  Future<List<Club>> listClubs();

  /// Latest club document from Appwrite, or null if missing / offline.
  Future<Club?> getClub(String id);
}

class SampleClubRepository implements ClubRepository {
  @override
  Future<List<Club>> listClubs() async {
    return SampleData.clubs;
  }

  @override
  Future<Club?> getClub(String id) async {
    for (final c in SampleData.clubs) {
      if (c.id == id) {
        return c;
      }
    }
    return null;
  }
}

class AppwriteClubRepository implements ClubRepository {
  @override
  Future<List<Club>> listClubs() async {
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.clubsCollectionId.isEmpty) {
      return SampleData.clubs;
    }

    final docs = await AppwriteService.listDocuments(
      collectionId: AppwriteConfig.clubsCollectionId,
      queries: [Query.limit(500)],
    );

    return docs.documents
        .map(
          (d) => Club.fromMap(
            Map<String, dynamic>.from(d.data),
            id: d.$id,
            documentCreatedAt: DateTime.tryParse(d.$createdAt),
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<Club?> getClub(String id) async {
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.clubsCollectionId.isEmpty ||
        id.trim().isEmpty) {
      return null;
    }
    try {
      final doc = await AppwriteService.getDocument(
        collectionId: AppwriteConfig.clubsCollectionId,
        documentId: id,
      );
      return Club.fromMap(
        Map<String, dynamic>.from(doc.data),
        id: doc.$id,
        documentCreatedAt: DateTime.tryParse(doc.$createdAt),
      );
    } catch (_) {
      return null;
    }
  }
}

ClubRepository clubRepository() {
  if (!AppwriteConfig.isConfigured ||
      AppwriteConfig.databaseId.isEmpty ||
      AppwriteConfig.clubsCollectionId.isEmpty) {
    return SampleClubRepository();
  }

  return AppwriteClubRepository();
}

