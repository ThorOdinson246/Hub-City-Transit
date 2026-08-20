import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement.freezed.dart';
part 'announcement.g.dart';

/// A document declaring a higher version is rejected rather than half-read.
const int announcementsSchemaVersion = 1;

/// Maps 1:1 to an Android notification channel once push lands.
enum AnnouncementKind {
  @JsonValue('service_alert')
  serviceAlert,
  @JsonValue('product_update')
  productUpdate,
}

/// Mirrors GTFS-Realtime `Alert.SeverityLevel`.
enum AnnouncementSeverity {
  @JsonValue('INFO')
  info,
  @JsonValue('WARNING')
  warning,
  @JsonValue('SEVERE')
  severe,
}

/// Mirrors GTFS-Realtime `Alert.Effect`. Separate from severity on purpose: a
/// detour and a suspension can be equally urgent but need different words.
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

/// Repeated per announcement, because "weekdays 6-9am for two weeks" doesn't
/// fit one range.
@freezed
abstract class ActivePeriod with _$ActivePeriod {
  const factory ActivePeriod({
    required DateTime start,

    /// Null means open-ended.
    DateTime? end,
  }) = _ActivePeriod;

  factory ActivePeriod.fromJson(Map<String, dynamic> json) =>
      _$ActivePeriodFromJson(json);
}

/// Mirrors GTFS-Realtime `EntitySelector`. No entities means agency-wide.
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

    /// Read/dismissed state keys on `(id, updatedAt)`, so editing an alert
    /// resurfaces it for anyone who dismissed the milder wording.
    required DateTime updatedAt,
    @Default(AnnouncementEffect.unknownEffect) AnnouncementEffect effect,
    @Default(<ActivePeriod>[]) List<ActivePeriod> activePeriods,
    @Default(<InformedEntity>[]) List<InformedEntity> informedEntities,
    String? url,
  }) = _Announcement;

  const Announcement._();

  factory Announcement.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementFromJson(json);

  /// Changing the content changes this key. That's the point.
  String get revisionKey => '$id@${updatedAt.toIso8601String()}';

  /// No periods means always live.
  bool isActiveAt(DateTime now) {
    if (activePeriods.isEmpty) return true;
    return activePeriods.any((period) {
      if (now.isBefore(period.start)) return false;
      final end = period.end;
      return end == null || now.isBefore(end);
    });
  }

  bool appliesToRoute(String? routeId) {
    final routeScoped =
        informedEntities.where((entity) => entity.routeId != null);
    if (routeScoped.isEmpty) return true;
    if (routeId == null) return false;
    return routeScoped.any((entity) => entity.routeId == routeId);
  }
}

/// The envelope. Wrapping the list lets the server add fields without a
/// breaking change.
@freezed
abstract class AnnouncementsDocument with _$AnnouncementsDocument {
  const factory AnnouncementsDocument({
    required int schema,

    /// Null for the bundled fallback. Drives the "last checked" line, so don't
    /// fake it.
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
