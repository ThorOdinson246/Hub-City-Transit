import '../../data/models/announcement.dart';

/// Lets the UI say how fresh the data is. A cached document during an outage
/// shouldn't look live.
enum AnnouncementsSource { network, cache, bundled }

class AnnouncementsResult {
  const AnnouncementsResult({
    required this.document,
    required this.source,
    this.fetchedAt,
    this.droppedRecords = 0,
  });

  final AnnouncementsDocument document;
  final AnnouncementsSource source;

  /// Null for the bundled asset.
  final DateTime? fetchedAt;

  /// Surfaced so a malformed feed is visible instead of silently thinning alerts.
  final int droppedRecords;
}

abstract interface class AnnouncementsRepository {
  /// Network, then cache, then the bundled asset. Never throws — a stale alert
  /// beats no alert.
  Future<AnnouncementsResult> getAnnouncements({bool forceRefresh = false});
}
