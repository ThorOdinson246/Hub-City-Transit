import 'package:flutter/material.dart';

import '../../../data/models/announcement.dart';

/// Presentation mapping for announcements, kept in one place so the banner, the
/// inbox, and any future notification share a vocabulary.
class AnnouncementStyle {
  const AnnouncementStyle({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;

  /// Spoken and written label. Severity is never conveyed by colour alone.
  final String label;

  /// Foreground that actually contrasts against [color].
  ///
  /// Derived from luminance rather than hardcoded white — the gold route colour
  /// gives white a 1.53:1 ratio, which is why the existing route chips are
  /// unreadable. Do not replace this with a literal.
  Color get onColor =>
      color.computeLuminance() > 0.5 ? const Color(0xFF16161A) : Colors.white;
}

AnnouncementStyle announcementStyle(
  Announcement announcement,
  ColorScheme scheme,
) {
  switch (announcement.severity) {
    case AnnouncementSeverity.severe:
      return AnnouncementStyle(
        icon: Icons.error_rounded,
        color: scheme.error,
        label: 'Urgent alert',
      );
    case AnnouncementSeverity.warning:
      return AnnouncementStyle(
        icon: Icons.warning_amber_rounded,
        color: scheme.tertiary,
        label: 'Service alert',
      );
    case AnnouncementSeverity.info:
      return AnnouncementStyle(
        icon: announcement.kind == AnnouncementKind.productUpdate
            ? Icons.auto_awesome_rounded
            : Icons.info_rounded,
        color: scheme.primary,
        label: announcement.kind == AnnouncementKind.productUpdate
            ? 'App update'
            : 'Notice',
      );
  }
}

/// Short human label for the GTFS-RT effect, or null when it adds nothing.
String? announcementEffectLabel(AnnouncementEffect effect) {
  switch (effect) {
    case AnnouncementEffect.noService:
      return 'No service';
    case AnnouncementEffect.reducedService:
      return 'Reduced service';
    case AnnouncementEffect.significantDelays:
      return 'Major delays';
    case AnnouncementEffect.detour:
      return 'Detour';
    case AnnouncementEffect.additionalService:
      return 'Extra service';
    case AnnouncementEffect.modifiedService:
      return 'Changed service';
    case AnnouncementEffect.stopMoved:
      return 'Stop moved';
    case AnnouncementEffect.otherEffect:
    case AnnouncementEffect.unknownEffect:
      return null;
  }
}

/// Relative age, phrased for a rider glancing at a stop.
String announcementAge(DateTime timestamp, DateTime now) {
  final elapsed = now.difference(timestamp);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) {
    return '${elapsed.inHours} hour${elapsed.inHours == 1 ? '' : 's'} ago';
  }
  final days = elapsed.inDays;
  if (days < 7) return '$days day${days == 1 ? '' : 's'} ago';
  final weeks = days ~/ 7;
  return '$weeks week${weeks == 1 ? '' : 's'} ago';
}
