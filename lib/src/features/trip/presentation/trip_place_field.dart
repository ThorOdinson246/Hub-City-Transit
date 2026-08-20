import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/trip_planner_providers.dart';

class TripPlace {
  const TripPlace({required this.label, required this.lat, required this.lng});

  final String label;
  final double lat;
  final double lng;
}

/// Start or destination picker: current location, a bus stop, or a geocoded
/// address.
class TripPlaceField extends ConsumerStatefulWidget {
  const TripPlaceField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowCurrentLocation = false,
    this.onFocused,
    super.key,
  });

  final String label;
  final TripPlace? value;
  final ValueChanged<TripPlace?> onChanged;
  final bool allowCurrentLocation;

  /// Lets a host sheet expand so the suggestions are not typed into a 4-line gap.
  final VoidCallback? onFocused;

  @override
  ConsumerState<TripPlaceField> createState() => _TripPlaceFieldState();
}

class _TripPlaceFieldState extends ConsumerState<TripPlaceField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.value?.label ?? '';
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(TripPlaceField old) {
    super.didUpdateWidget(old);
    if (widget.value?.label != old.value?.label && !_focus.hasFocus) {
      _controller.text = widget.value?.label ?? '';
    }
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _showSuggestions = _focus.hasFocus);
    if (_focus.hasFocus) widget.onFocused?.call();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // 800ms rather than the 600 used elsewhere: Nominatim's policy ceiling is
    // 1 req/s and we cannot send an identifying User-Agent from a browser.
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _pick(TripPlace place) {
    _controller.text = place.label;
    _focus.unfocus();
    setState(() {
      _showSuggestions = false;
      _query = '';
    });
    widget.onChanged(place);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: widget.label,
            isDense: true,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.place_outlined, size: 20),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Clear ${widget.label}',
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                      widget.onChanged(null);
                    },
                  ),
          ),
          onChanged: _onChanged,
        ),
        if (_showSuggestions) _suggestions(scheme),
      ],
    );
  }

  Widget _suggestions(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.allowCurrentLocation) _currentLocationTile(),
          ..._stopTiles(),
          if (_query.length >= 3) ..._placeTiles(),
        ],
      ),
    );
  }

  Widget _currentLocationTile() {
    final position = ref.watch(userLocationProvider).asData?.value;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.my_location_rounded, size: 20),
      title: const Text('Current location'),
      subtitle: position == null
          ? const Text('Location not available')
          : null,
      enabled: position != null,
      onTap: position == null
          ? null
          : () => _pick(TripPlace(
                label: 'Current location',
                lat: position.latitude,
                lng: position.longitude,
              )),
    );
  }

  List<Widget> _stopTiles() {
    final dataset = ref.watch(transitDatasetProvider).asData?.value;
    if (dataset == null || _query.length < 2) return const [];

    final needle = _query.toLowerCase();
    final seen = <String>{};
    final matches = <Widget>[];

    for (final entry in dataset.allStops) {
      if (matches.length >= 4) break;
      final name = entry.stop.name;
      if (!name.toLowerCase().contains(needle)) continue;
      if (!seen.add(name)) continue;
      matches.add(ListTile(
        dense: true,
        leading: const Icon(Icons.directions_bus_rounded, size: 20),
        title: Text(name),
        subtitle: const Text('Bus stop'),
        onTap: () => _pick(TripPlace(
            label: name, lat: entry.stop.lat, lng: entry.stop.lng)),
      ));
    }
    return matches;
  }

  List<Widget> _placeTiles() {
    return [
      ref.watch(placeSearchProvider(_query)).when(
            loading: () => const ListTile(
              dense: true,
              leading: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              title: Text('Searching…'),
            ),
            error: (_, _) => const ListTile(
              dense: true,
              leading: Icon(Icons.cloud_off_rounded, size: 20),
              title: Text('Address search unavailable'),
            ),
            data: (places) {
              if (places.isEmpty) {
                return const ListTile(
                  dense: true,
                  leading: Icon(Icons.search_off_rounded, size: 20),
                  title: Text('No matching addresses'),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final place in places.take(4))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_rounded, size: 20),
                      title: Text(place.displayName,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _pick(TripPlace(
                          label: place.displayName,
                          lat: place.lat,
                          lng: place.lon)),
                    ),
                ],
              );
            },
          ),
    ];
  }
}
