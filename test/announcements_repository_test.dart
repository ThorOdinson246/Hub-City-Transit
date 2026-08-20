import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/data/repositories/announcements_repository_impl.dart';
import 'package:hubcity_transit_flutter/src/domain/repositories/announcements_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves a fixed payload for the bundled asset path and nothing else, so a
/// test can assert the fallback without touching the real bundle.
class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._contents);

  final Map<String, String> _contents;

  @override
  Future<ByteData> load(String key) async {
    final value = _contents[key];
    if (value == null) {
      throw FlutterError('Asset not found: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

String _document(List<Map<String, dynamic>> announcements, {int schema = 1}) {
  return jsonEncode(<String, dynamic>{
    'schema': schema,
    'generated_at': '2026-08-19T14:00:00Z',
    'announcements': announcements,
  });
}

Map<String, dynamic> _valid({String id = 'a1'}) => <String, dynamic>{
      'id': id,
      'kind': 'service_alert',
      'severity': 'WARNING',
      'title': 'Detour',
      'body': 'Blue route detour.',
      'updatedAt': '2026-08-19T14:03:00Z',
    };

AnnouncementsRepositoryImpl _repository({
  required String bundled,
  Dio? dio,
  String endpoint = '',
}) {
  return AnnouncementsRepositoryImpl(
    dio: dio ?? Dio(),
    endpoint: endpoint,
    assetBundle: _FakeAssetBundle(<String, String>{
      AnnouncementsRepositoryImpl.bundledAssetPath: bundled,
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('falls back to the bundled asset when no endpoint is configured', () async {
    final repository = _repository(bundled: _document([_valid()]));

    final result = await repository.getAnnouncements();

    expect(result.source, AnnouncementsSource.bundled);
    expect(result.document.announcements, hasLength(1));
    expect(result.fetchedAt, isNull);
  });

  test('drops one malformed record instead of the whole document', () async {
    // The failure this guards against is the existing _loadStops behaviour,
    // where a single bad field throws out every route in the file.
    final repository = _repository(
      bundled: _document([
        _valid(id: 'good-1'),
        <String, dynamic>{'id': 'bad', 'severity': 'NONSENSE'},
        _valid(id: 'good-2'),
      ]),
    );

    final result = await repository.getAnnouncements();

    expect(result.document.announcements, hasLength(2));
    expect(
      result.document.announcements.map((a) => a.id),
      containsAll(<String>['good-1', 'good-2']),
    );
    expect(result.droppedRecords, 1, reason: 'drops must be observable');
  });

  test('rejects a document from a newer schema rather than half-reading it', () async {
    final repository = _repository(bundled: _document([_valid()], schema: 99));

    final result = await repository.getAnnouncements();

    expect(result.document.announcements, isEmpty);
  });

  test('survives a malformed document without throwing', () async {
    final repository = _repository(bundled: '{not json at all');

    final result = await repository.getAnnouncements();

    expect(result.document.announcements, isEmpty);
    expect(result.source, AnnouncementsSource.bundled);
  });

  test('survives the bundled asset being absent', () async {
    // A cosmetic feature must not take down app startup.
    final repository = AnnouncementsRepositoryImpl(
      dio: Dio(),
      endpoint: '',
      assetBundle: _FakeAssetBundle(const <String, String>{}),
    );

    final result = await repository.getAnnouncements();

    expect(result.document.announcements, isEmpty);
  });

  test('a network failure degrades to the bundled asset, not an error', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
    dio.httpClientAdapter = _FailingAdapter();

    final repository = _repository(
      bundled: _document([_valid(id: 'offline-copy')]),
      dio: dio,
      endpoint: 'https://example.invalid/announcements.json',
    );

    final result = await repository.getAnnouncements();

    expect(result.source, AnnouncementsSource.bundled);
    expect(result.document.announcements.single.id, 'offline-copy');
  });

  test('caches a successful fetch and reports it as network', () async {
    final dio = Dio();
    dio.httpClientAdapter = _StaticAdapter(_document([_valid(id: 'live')]));

    final repository = _repository(
      bundled: _document(const []),
      dio: dio,
      endpoint: 'https://example.test/announcements.json',
    );

    final result = await repository.getAnnouncements();

    expect(result.source, AnnouncementsSource.network);
    expect(result.document.announcements.single.id, 'live');
    expect(result.fetchedAt, isNotNull);

    // A later offline read should return the cached copy, not the bundled one.
    final offlineDio = Dio();
    offlineDio.httpClientAdapter = _FailingAdapter();
    final offlineRepository = _repository(
      bundled: _document(const []),
      dio: offlineDio,
      endpoint: 'https://example.test/announcements.json',
    );

    final cached = await offlineRepository.getAnnouncements();

    expect(cached.source, AnnouncementsSource.cache);
    expect(cached.document.announcements.single.id, 'live');
  });
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );
  }
}

class _StaticAdapter implements HttpClientAdapter {
  _StaticAdapter(this.body);

  final String body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
