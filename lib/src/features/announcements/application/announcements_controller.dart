import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_provider.dart';
import '../../../data/models/announcement.dart';
import '../../../data/repositories/announcements_repository_impl.dart';
import '../../../domain/repositories/announcements_repository.dart';
import 'announcement_read_store.dart';

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) {
  return AnnouncementsRepositoryImpl(
    dio: ref.watch(dioProvider),
    endpoint: announcementsEndpoint,
  );
});

/// Loads the document and keeps it fresh while the app is in the foreground.
///
/// Deliberately *not* modelled on `busLocationPollingProvider`: this is
/// `autoDispose`, the timer is cancelled on dispose, and polling stops when the
/// app is backgrounded. A conditional `If-None-Match` GET every few minutes is
/// three orders of magnitude cheaper than that provider's 3-second loop, and
/// without it a rider watching the map for forty minutes would never see an
/// alert published during that window.
class AnnouncementsController extends AutoDisposeAsyncNotifier<AnnouncementsResult> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _disposed = false;

  @override
  Future<AnnouncementsResult> build() async {
    final repository = ref.watch(announcementsRepositoryProvider);

    _lifecycle = AppLifecycleListener(
      onResume: _onResumed,
      onHide: _cancelTimer,
      onPause: _cancelTimer,
    );

    ref.onDispose(() {
      _disposed = true;
      _cancelTimer();
      _lifecycle?.dispose();
    });

    final result = await repository.getAnnouncements();
    _schedule(result);
    unawaited(_prune(result));
    return result;
  }

  Future<void> refresh() async {
    final repository = ref.read(announcementsRepositoryProvider);
    final result = await repository.getAnnouncements(forceRefresh: true);
    if (_disposed) return;
    state = AsyncData(result);
    _schedule(result);
    unawaited(_prune(result));
  }

  void _onResumed() {
    unawaited(refresh());
  }

  /// Poll faster while something urgent is on screen — a severe alert is
  /// exactly when a correction or an all-clear matters most.
  void _schedule(AnnouncementsResult result) {
    _cancelTimer();
    if (announcementsEndpoint.isEmpty) return;

    final now = DateTime.now();
    final hasUrgent = result.document.announcements.any(
      (announcement) =>
          announcement.severity == AnnouncementSeverity.severe &&
          announcement.isActiveAt(now),
    );

    _timer = Timer(
      hasUrgent ? announcementsUrgentPollInterval : announcementsPollInterval,
      () => unawaited(refresh()),
    );
  }

  Future<void> _prune(AnnouncementsResult result) async {
    final live = result.document.announcements
        .map((announcement) => announcement.revisionKey)
        .toSet();
    await ref.read(announcementReadStoreProvider.notifier).pruneTo(live);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

final announcementsControllerProvider = AutoDisposeAsyncNotifierProvider<
    AnnouncementsController, AnnouncementsResult>(AnnouncementsController.new);

/// An announcement paired with the rider's state for it, ready to render.
class AnnouncementView {
  const AnnouncementView({
    required this.announcement,
    required this.isRead,
    required this.isDismissed,
  });

  final Announcement announcement;
  final bool isRead;
  final bool isDismissed;
}

/// Active announcements, most severe first then newest, with read state applied.
final visibleAnnouncementsProvider =
    Provider.autoDispose<List<AnnouncementView>>((ref) {
  final result = ref.watch(announcementsControllerProvider).valueOrNull;
  if (result == null) return const <AnnouncementView>[];

  final readState = ref.watch(announcementReadStoreProvider).valueOrNull ??
      const AnnouncementReadState();
  final now = DateTime.now();

  final views = result.document.announcements
      .where((announcement) => announcement.isActiveAt(now))
      .map(
        (announcement) => AnnouncementView(
          announcement: announcement,
          isRead: readState.isRead(announcement.revisionKey),
          isDismissed: readState.isDismissed(announcement.revisionKey),
        ),
      )
      .toList();

  views.sort((a, b) {
    final bySeverity = b.announcement.severity.index
        .compareTo(a.announcement.severity.index);
    if (bySeverity != 0) return bySeverity;
    return b.announcement.updatedAt.compareTo(a.announcement.updatedAt);
  });

  return List<AnnouncementView>.unmodifiable(views);
});

final unreadAnnouncementCountProvider = Provider.autoDispose<int>((ref) {
  return ref
      .watch(visibleAnnouncementsProvider)
      .where((view) => !view.isRead)
      .length;
});

/// The single alert worth pinning to the Map screen, if any. Severe only, not
/// yet dismissed, and scoped to the route the rider is looking at.
final pinnedAnnouncementProvider =
    Provider.autoDispose.family<AnnouncementView?, String?>((ref, routeId) {
  final candidates = ref.watch(visibleAnnouncementsProvider).where(
        (view) =>
            view.announcement.severity == AnnouncementSeverity.severe &&
            !view.isDismissed &&
            view.announcement.appliesToRoute(routeId),
      );
  return candidates.isEmpty ? null : candidates.first;
});
