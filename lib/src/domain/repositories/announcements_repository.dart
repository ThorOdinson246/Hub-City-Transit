import '../../data/models/announcement.dart';

/// Where a document came from. The UI needs this to be honest with the rider
/// about freshness — a cached document rendered during an outage must not look
/// like a live one.
enum AnnouncementsSource {
  /// Fetched from the network this session.
  network,

  /// Read from the on-device cache of a previous successful fetch.
  cache,

  /// The asset compiled into the app. Only reached when nothing has ever been
  /// fetched successfully on this device.
  bundled,
}

class AnnouncementsResult {
  const AnnouncementsResult({
    required this.document,
    required this.source,
    this.fetchedAt,
    this.droppedRecords = 0,
  });

  final AnnouncementsDocument document;
  final AnnouncementsSource source;

  /// When the document was last successfully retrieved from the network.
  /// Null when [source] is [AnnouncementsSource.bundled].
  final DateTime? fetchedAt;

  /// Records rejected during parsing. Surfaced so a malformed feed is
  /// observable rather than silently thinning the rider's alerts.
  final int droppedRecords;
}

abstract interface class AnnouncementsRepository {
  /// Returns the best document available, preferring fresh network data and
  /// falling back through cache to the bundled asset. Never throws: a
  /// transport failure degrades the source rather than surfacing an error,
  /// because a rider with a stale alert is better served than one with none.
  Future<AnnouncementsResult> getAnnouncements({bool forceRefresh = false});
}
