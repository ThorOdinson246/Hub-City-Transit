import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which announcement revisions the rider has read and which banners
/// they have dismissed.
///
/// Keys are revision keys (`id@updatedAt`), not bare ids, so editing an
/// announcement resurfaces it. Escalating "minor delays" to "route suspended"
/// must reach someone who dismissed the milder wording.
///
/// Unlike the older preference notifiers in `app/providers.dart`, the initial
/// load is awaited via [AsyncNotifier] rather than racing the constructor, so a
/// tap during startup cannot be silently reverted by a late load completing.
class AnnouncementReadState {
  const AnnouncementReadState({
    this.readKeys = const <String>{},
    this.dismissedKeys = const <String>{},
  });

  final Set<String> readKeys;
  final Set<String> dismissedKeys;

  bool isRead(String revisionKey) => readKeys.contains(revisionKey);

  bool isDismissed(String revisionKey) => dismissedKeys.contains(revisionKey);

  AnnouncementReadState copyWith({
    Set<String>? readKeys,
    Set<String>? dismissedKeys,
  }) {
    return AnnouncementReadState(
      readKeys: readKeys ?? this.readKeys,
      dismissedKeys: dismissedKeys ?? this.dismissedKeys,
    );
  }
}

class AnnouncementReadStore extends AsyncNotifier<AnnouncementReadState> {
  static const String _readKey = 'announcements_read_keys_v1';
  static const String _dismissedKey = 'announcements_dismissed_keys_v1';

  @override
  Future<AnnouncementReadState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AnnouncementReadState(
      readKeys: (prefs.getStringList(_readKey) ?? const <String>[]).toSet(),
      dismissedKeys:
          (prefs.getStringList(_dismissedKey) ?? const <String>[]).toSet(),
    );
  }

  Future<void> markRead(String revisionKey) async {
    final current = state.valueOrNull;
    if (current == null || current.isRead(revisionKey)) return;

    final updated = {...current.readKeys, revisionKey};
    state = AsyncData(current.copyWith(readKeys: updated));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readKey, updated.toList(growable: false));
  }

  Future<void> markAllRead(Iterable<String> revisionKeys) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = {...current.readKeys, ...revisionKeys};
    if (updated.length == current.readKeys.length) return;

    state = AsyncData(current.copyWith(readKeys: updated));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readKey, updated.toList(growable: false));
  }

  Future<void> dismiss(String revisionKey) async {
    final current = state.valueOrNull;
    if (current == null || current.isDismissed(revisionKey)) return;

    final updated = {...current.dismissedKeys, revisionKey};
    state = AsyncData(
      current.copyWith(
        dismissedKeys: updated,
        readKeys: {...current.readKeys, revisionKey},
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissedKey, updated.toList(growable: false));
    await prefs.setStringList(
      _readKey,
      state.requireValue.readKeys.toList(growable: false),
    );
  }

  /// Drops keys for announcements no longer in the document, so the stored
  /// sets cannot grow without bound across years of service alerts.
  Future<void> pruneTo(Set<String> liveRevisionKeys) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final read = current.readKeys.intersection(liveRevisionKeys);
    final dismissed = current.dismissedKeys.intersection(liveRevisionKeys);
    if (read.length == current.readKeys.length &&
        dismissed.length == current.dismissedKeys.length) {
      return;
    }

    state = AsyncData(
      AnnouncementReadState(readKeys: read, dismissedKeys: dismissed),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readKey, read.toList(growable: false));
    await prefs.setStringList(_dismissedKey, dismissed.toList(growable: false));
  }
}

final announcementReadStoreProvider =
    AsyncNotifierProvider<AnnouncementReadStore, AnnouncementReadState>(
  AnnouncementReadStore.new,
);
