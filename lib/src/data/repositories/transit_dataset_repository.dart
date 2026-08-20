import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../models/transit_dataset.dart';

/// Loads the bundled timetable once and keeps it.
///
/// Parsed on first use rather than at startup: the map tab doesn't need it, and
/// 322KB of JSON on the launch path would be felt.
final class TransitDatasetRepository {
  TransitDatasetRepository({AssetBundle? assetBundle})
      : _bundle = assetBundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<TransitDataset>? _pending;

  Future<TransitDataset> load() {
    // Held as the Future, not the value, so concurrent callers share one parse
    // instead of racing — the mistake _loadStops makes, where seven callers
    // decode the same file before any of them populates the cache.
    return _pending ??= _read();
  }

  Future<TransitDataset> _read() async {
    final raw = await _bundle.loadString(localTransitAssetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('transit.json is not an object');
    }
    return TransitDataset.fromJson(decoded);
  }
}
