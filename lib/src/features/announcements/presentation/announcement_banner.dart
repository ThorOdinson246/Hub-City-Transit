import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/announcement_read_store.dart';
import '../application/announcements_controller.dart';
import 'announcement_presentation.dart';

/// Pins the most urgent live alert above the map. Renders nothing on an
/// ordinary day.
class AnnouncementBanner extends ConsumerWidget {
  const AnnouncementBanner({required this.routeId, super.key});

  final String? routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(pinnedAnnouncementProvider(routeId));
    if (view == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final announcement = view.announcement;
    final style = announcementStyle(announcement, scheme);

    return Semantics(
      liveRegion: true,
      label: '${style.label}. ${announcement.title}. ${announcement.body}',
      child: Material(
        color: style.color,
        borderRadius: BorderRadius.circular(14),
        elevation: 3,
        child: InkWell(
          onTap: () => context.push('/announcements'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(style.icon, color: style.onColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.title,
                        style: text.titleSmall?.copyWith(
                          color: style.onColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        announcement.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: style.onColor.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Full 48dp: a mis-tap here pans the map instead of dismissing.
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: style.onColor,
                  tooltip: 'Dismiss alert',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => ref
                      .read(announcementReadStoreProvider.notifier)
                      .dismiss(announcement.revisionKey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
