import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/repositories/announcements_repository.dart';
import '../application/announcement_read_store.dart';
import '../application/announcements_controller.dart';
import 'announcement_presentation.dart';

class AnnouncementsInboxPage extends ConsumerWidget {
  const AnnouncementsInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final asyncResult = ref.watch(announcementsControllerProvider);
    final views = ref.watch(visibleAnnouncementsProvider);

    return Scaffold(
      appBar: AppBar(
        // Never an unconditional pop: reached as a deep link or a notification
        // tap there is nothing to pop, and iOS has no hardware back.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: const Text('Service Alerts'),
        actions: [
          if (views.any((view) => !view.isRead))
            TextButton(
              onPressed: () => ref
                  .read(announcementReadStoreProvider.notifier)
                  .markAllRead(
                    views.map((view) => view.announcement.revisionKey),
                  ),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(announcementsControllerProvider.notifier).refresh(),
          child: asyncResult.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => const _InboxMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load alerts',
              // Never the raw exception — it leaks the request path.
              message: 'Check your connection and pull down to try again.',
            ),
            data: (result) {
              if (views.isEmpty) {
                return _InboxMessage(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No current alerts',
                  message: announcementsEndpoint.isEmpty
                      ? 'Alerts are not configured for this build yet.'
                      : 'Service is running as scheduled. '
                          'Pull down to check again.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: views.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == views.length) {
                    return _FreshnessFooter(result: result);
                  }
                  final view = views[index];
                  return _AnnouncementCard(
                    view: view,
                    onTap: () => ref
                        .read(announcementReadStoreProvider.notifier)
                        .markRead(view.announcement.revisionKey),
                  );
                },
              );
            },
          ),
        ),
      ),
      backgroundColor: scheme.surface,
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.view, required this.onTap});

  final AnnouncementView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final announcement = view.announcement;
    final style = announcementStyle(announcement, scheme);
    final effect = announcementEffectLabel(announcement.effect);
    final age = announcementAge(announcement.updatedAt, DateTime.now());

    return Semantics(
      button: true,
      // Unread is a dot in the visual design; it must also be spoken.
      label: '${view.isRead ? '' : 'Unread. '}${style.label}. '
          '${announcement.title}. $age',
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: view.isRead
                    ? scheme.outlineVariant
                    : style.color.withValues(alpha: 0.55),
                width: view.isRead ? 1 : 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(style.icon, size: 20, color: style.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: text.titleMedium?.copyWith(
                          fontWeight:
                              view.isRead ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!view.isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: style.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(announcement.body, style: text.bodyMedium),
                const SizedBox(height: 12),
                // Wrap, not Row: these chips must reflow rather than overflow
                // when the rider uses a large text scale.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Chip(label: style.label, color: style.color),
                    if (effect != null)
                      _Chip(label: effect, color: scheme.onSurfaceVariant),
                    Text(
                      age,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (announcement.url case final String url
                    when url.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // 48dp minimum target, enforced by the widget not by padding.
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Learn more'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Tells the rider how old the data is. A cached document rendered during an
/// outage must not be presented as current fact.
class _FreshnessFooter extends StatelessWidget {
  const _FreshnessFooter({required this.result});

  final AnnouncementsResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fetchedAt = result.fetchedAt;
    final now = DateTime.now();
    final isStale = fetchedAt == null ||
        now.difference(fetchedAt) > announcementsStaleAfter;

    final String message;
    if (result.source == AnnouncementsSource.bundled) {
      message = 'Showing alerts included with the app. Not yet updated.';
    } else if (fetchedAt == null) {
      message = 'Last updated at an unknown time.';
    } else {
      message = 'Last checked ${announcementAge(fetchedAt, now)}.';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isStale ? Icons.schedule_rounded : Icons.cloud_done_rounded,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Scrollable so pull-to-refresh still works, and so the content survives
    // a large text scale on a short screen.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      children: [
        Icon(icon, size: 48, color: scheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: text.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
