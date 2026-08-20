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

/// Keeps the document fresh while the app is foregrounded.
///
/// A conditional GET every few minutes, not the 3-second firehose that
/// `busLocationPollingProvider` runs. Without any poll, a rider watching the map
/// for forty minutes would never see an alert published in that window.
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

  /// Faster while a severe alert is live — that's when a correction matters.
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

/// Active announcements, most severe first then newest.
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

/// Severe, undismissed, and relevant to the route on screen.
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
