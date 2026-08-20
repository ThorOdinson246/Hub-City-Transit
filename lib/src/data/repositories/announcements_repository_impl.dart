import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/announcements_repository.dart';
import '../models/announcement.dart';

/// Network, then last good cache, then the bundled asset. Endpoint is injected
/// so repointing it is configuration.
final class AnnouncementsRepositoryImpl implements AnnouncementsRepository {
  AnnouncementsRepositoryImpl({
    required Dio dio,
    required String endpoint,
    AssetBundle? assetBundle,
  })  : _dio = dio,
        _endpoint = endpoint,
        _assetBundle = assetBundle ?? rootBundle;

  static const String bundledAssetPath = 'assets/data/announcements.json';
  static const String _cacheKey = 'announcements_document_v1';
  static const String _cacheFetchedAtKey = 'announcements_fetched_at_v1';
  static const String _cacheEtagKey = 'announcements_etag_v1';

  final Dio _dio;
  final String _endpoint;
  final AssetBundle _assetBundle;

  @override
  Future<AnnouncementsResult> getAnnouncements({
    bool forceRefresh = false,
  }) async {
    if (_endpoint.isNotEmpty) {
      final fetched = await _fetchFromNetwork();
      if (fetched != null) return fetched;
    }

    final cached = await _readCache();
    if (cached != null) return cached;

    return _readBundled();
  }

  Future<AnnouncementsResult?> _fetchFromNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    final etag = prefs.getString(_cacheEtagKey);

    final headers = <String, String>{};
    if (etag != null) headers['If-None-Match'] = etag;

    try {
      final response = await _dio.get<String>(
        _endpoint,
        options: Options(
          responseType: ResponseType.plain,
          // 304 is a success for our purposes, not an error to retry.
          validateStatus: (status) =>
              status != null &&
              (status == 304 || (status >= 200 && status < 300)),
          headers: headers,
        ),
      );

      if (response.statusCode == 304) {
        return _readCache();
      }

      final body = response.data;
      if (body == null || body.isEmpty) return null;

      final parsed = _parseDocument(body);
      if (parsed == null) return null;

      final fetchedAt = DateTime.now();
      await prefs.setString(_cacheKey, body);
      await prefs.setString(_cacheFetchedAtKey, fetchedAt.toIso8601String());
      final newEtag = response.headers.value('etag');
      if (newEtag != null) {
        await prefs.setString(_cacheEtagKey, newEtag);
      }

      return AnnouncementsResult(
        document: parsed.document,
        source: AnnouncementsSource.network,
        fetchedAt: fetchedAt,
        droppedRecords: parsed.dropped,
      );
    } on DioException {
      // Caller falls back to cache; a stale alert beats an error screen.
      return null;
    }
  }

  Future<AnnouncementsResult?> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;

    final parsed = _parseDocument(raw);
    if (parsed == null) return null;

    final fetchedAtRaw = prefs.getString(_cacheFetchedAtKey);
    return AnnouncementsResult(
      document: parsed.document,
      source: AnnouncementsSource.cache,
      fetchedAt: fetchedAtRaw == null ? null : DateTime.tryParse(fetchedAtRaw),
      droppedRecords: parsed.dropped,
    );
  }

  Future<AnnouncementsResult> _readBundled() async {
    try {
      final raw = await _assetBundle.loadString(bundledAssetPath);
      final parsed = _parseDocument(raw);
      if (parsed != null) {
        return AnnouncementsResult(
          document: parsed.document,
          source: AnnouncementsSource.bundled,
          droppedRecords: parsed.dropped,
        );
      }
    } on FlutterError {
      // Missing asset shouldn't take down the app over a cosmetic feature.
    }

    return const AnnouncementsResult(
      document: AnnouncementsDocument.empty,
      source: AnnouncementsSource.bundled,
    );
  }

  /// Drops individual bad records rather than binning the whole document —
  /// unlike `_loadStops`, where one bad field takes out all seven routes.
  _ParsedDocument? _parseDocument(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }

    if (decoded is! Map<String, dynamic>) return null;

    final schema = decoded['schema'];
    if (schema is! int || schema > announcementsSchemaVersion) {
      // A newer schema may redefine fields we think we understand.
      return null;
    }

    final generatedAtRaw = decoded['generated_at'];
    final items = decoded['announcements'];

    final parsed = <Announcement>[];
    var dropped = 0;
    if (items is List) {
      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          dropped++;
          continue;
        }
        try {
          parsed.add(Announcement.fromJson(item));
        } on Object {
          dropped++;
        }
      }
    }

    return _ParsedDocument(
      document: AnnouncementsDocument(
        schema: schema,
        generatedAt:
            generatedAtRaw is String ? DateTime.tryParse(generatedAtRaw) : null,
        announcements: List<Announcement>.unmodifiable(parsed),
      ),
      dropped: dropped,
    );
  }
}

class _ParsedDocument {
  const _ParsedDocument({required this.document, required this.dropped});

  final AnnouncementsDocument document;
  final int dropped;
}
