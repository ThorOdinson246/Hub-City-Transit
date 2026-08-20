import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement.freezed.dart';
part 'announcement.g.dart';

/// Schema version this client understands. A document declaring a higher
/// version is rejected wholesale rather than partially misread.
const int announcementsSchemaVersion = 1;

/// Which notification channel an announcement belongs to. Maps 1:1 to an
/// Android notification channel when push lands.
enum AnnouncementKind {
  @JsonValue('service_alert')
  serviceAlert,
  @JsonValue('product_update')
  productUpdate,
}

/// Mirrors GTFS-Realtime `Alert.SeverityLevel` so a future GTFS-RT feed
/// transcodes without a client change.
enum AnnouncementSeverity {
  @JsonValue('INFO')
  info,
  @JsonValue('WARNING')
  warning,
  @JsonValue('SEVERE')
  severe,
}

/// Mirrors GTFS-Realtime `Alert.Effect`. Drives the icon and label, and is
/// deliberately separate from [AnnouncementSeverity] — a detour and a
/// full suspension can share an urgency but need different words.
enum AnnouncementEffect {
  @JsonValue('NO_SERVICE')
  noService,
  @JsonValue('REDUCED_SERVICE')
  reducedService,
  @JsonValue('SIGNIFICANT_DELAYS')
  significantDelays,
  @JsonValue('DETOUR')
  detour,
  @JsonValue('ADDITIONAL_SERVICE')
  additionalService,
  @JsonValue('MODIFIED_SERVICE')
  modifiedService,
  @JsonValue('STOP_MOVED')
  stopMoved,
  @JsonValue('OTHER_EFFECT')
  otherEffect,
  @JsonValue('UNKNOWN_EFFECT')
  unknownEffect,
}

/// One window during which an announcement is live. Repeated, because
/// "weekdays 6-9am for two weeks" is not expressible as a single range.
@freezed
abstract class ActivePeriod with _$ActivePeriod {
  const factory ActivePeriod({
    required DateTime start,

    /// `null` means open-ended — live until the announcement is withdrawn.
    DateTime? end,
  }) = _ActivePeriod;

  factory ActivePeriod.fromJson(Map<String, dynamic> json) =>
      _$ActivePeriodFromJson(json);
}

/// What an announcement applies to. Mirrors GTFS-Realtime `EntitySelector`.
/// An announcement with no entities is agency-wide.
@freezed
abstract class InformedEntity with _$InformedEntity {
  const factory InformedEntity({
    String? routeId,
    int? stopId,
  }) = _InformedEntity;

  factory InformedEntity.fromJson(Map<String, dynamic> json) =>
      _$InformedEntityFromJson(json);
}

@freezed
abstract class Announcement with _$Announcement {
  const factory Announcement({
    required String id,
    required AnnouncementKind kind,
    required AnnouncementSeverity severity,
    required String title,
    required String body,

    /// Bumped whenever the author edits an existing announcement. Read and
    /// dismissed state key on `(id, updatedAt)` so that escalating an alert
    /// resurfaces it for someone who already dismissed the milder version.
    required DateTime updatedAt,
    @Default(AnnouncementEffect.unknownEffect) AnnouncementEffect effect,
    @Default(<ActivePeriod>[]) List<ActivePeriod> activePeriods,
    @Default(<InformedEntity>[]) List<InformedEntity> informedEntities,
    String? url,
  }) = _Announcement;

  const Announcement._();

  factory Announcement.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementFromJson(json);

  /// Identity for read/dismissed state. Changing the announcement's content
  /// changes this key, which is the point.
  String get revisionKey => '$id@${updatedAt.toIso8601String()}';

  /// An announcement with no active periods is always live.
  bool isActiveAt(DateTime now) {
    if (activePeriods.isEmpty) return true;
    return activePeriods.any((period) {
      if (now.isBefore(period.start)) return false;
      final end = period.end;
      return end == null || now.isBefore(end);
    });
  }

  /// Agency-wide announcements apply to every rider. Otherwise the rider only
  /// sees it if it names a route they are looking at.
  bool appliesToRoute(String? routeId) {
    final routeScoped =
        informedEntities.where((entity) => entity.routeId != null);
    if (routeScoped.isEmpty) return true;
    if (routeId == null) return false;
    return routeScoped.any((entity) => entity.routeId == routeId);
  }
}

/// The fetched document. Wrapping the list lets the server evolve the envelope
/// (schema bumps, freshness hints) without another breaking change.
@freezed
abstract class AnnouncementsDocument with _$AnnouncementsDocument {
  const factory AnnouncementsDocument({
    required int schema,

    /// When the server built this document. Null for the bundled fallback,
    /// which has no meaningful generation time — the UI uses this to tell the
    /// rider how fresh the data is, so it must not be faked.
    DateTime? generatedAt,
    @Default(<Announcement>[]) List<Announcement> announcements,
  }) = _AnnouncementsDocument;

  const AnnouncementsDocument._();

  factory AnnouncementsDocument.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementsDocumentFromJson(json);

  static const AnnouncementsDocument empty = AnnouncementsDocument(
    schema: announcementsSchemaVersion,
  );
}
