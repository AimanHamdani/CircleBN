import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../models/club.dart';
import 'sample_clubs.dart';

abstract class ClubRepository {
  Future<List<Club>> listClubs();
}

class SampleClubRepository implements ClubRepository {
  @override
  Future<List<Club>> listClubs() async {
    return SampleData.clubs;
  }
}

class AppwriteClubRepository implements ClubRepository {
  @override
  Future<List<Club>> listClubs() async {
    if (!AppwriteService.isConfigured || AppwriteConfig.clubsCollectionId.isEmpty) {
      return SampleData.clubs;
    }

    try {
      final docs = await AppwriteService.listDocuments(collectionId: AppwriteConfig.clubsCollectionId);

      return docs.documents
          .map(
            (d) => Club.fromMap(
              Map<String, dynamic>.from(d.data),
              id: d.$id,
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (_) {
      return SampleData.clubs;
    }
  }
}

ClubRepository clubRepository() {
  if (!AppwriteConfig.isConfigured) {
    return SampleClubRepository();
  }

  return AppwriteClubRepository();
}

