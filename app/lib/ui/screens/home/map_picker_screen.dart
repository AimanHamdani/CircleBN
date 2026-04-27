import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapPickerResult {
  final double lat;
  final double lng;
  const MapPickerResult({required this.lat, required this.lng});
}

class MapPickerScreen extends StatefulWidget {
  static const routeName = '/map-picker';

  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng _picked = const LatLng(4.9031, 114.9398);
  final MapController _mapCtrl = MapController();
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _searchCtrl;
  bool _isSearching = false;
  List<_MapSearchResult> _searchResults = const <_MapSearchResult>[];

  @override
  void initState() {
    super.initState();
    _latCtrl = TextEditingController(text: _picked.latitude.toStringAsFixed(6));
    _lngCtrl = TextEditingController(
      text: _picked.longitude.toStringAsFixed(6),
    );
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Pick Location'),
        centerTitle: true,
      ),
      body: _interactiveMap(context),
    );
  }

  Widget _interactiveMap(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _picked,
            initialZoom: 13,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onTap: (_, point) => setState(() {
              _picked = point;
              _latCtrl.text = point.latitude.toStringAsFixed(6);
              _lngCtrl.text = point.longitude.toStringAsFixed(6);
            }),
            onLongPress: (_, point) => setState(() {
              _picked = point;
              _latCtrl.text = point.latitude.toStringAsFixed(6);
              _lngCtrl.text = point.longitude.toStringAsFixed(6);
            }),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.circlebn.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _picked,
                  width: 44,
                  height: 44,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE3E7EE)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchPlace(),
                        decoration: const InputDecoration(
                          hintText: 'Search place or lat,lng',
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSearching ? null : _searchPlace,
                      icon: _isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE3E7EE)),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _searchResults.length; i++) ...[
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                          ),
                          title: Text(
                            _searchResults[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_searchResults[i].point.latitude.toStringAsFixed(6)}, ${_searchResults[i].point.longitude.toStringAsFixed(6)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            _setPickedLocation(
                              _searchResults[i].point,
                              zoom: 15,
                            );
                            setState(
                              () => _searchResults = const <_MapSearchResult>[],
                            );
                          },
                        ),
                        if (i != _searchResults.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE3E7EE)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_picked.latitude.toStringAsFixed(6)}, ${_picked.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton(
                  onPressed: () => _confirmPick(context),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Use'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _searchPlace() async {
    final raw = _searchCtrl.text.trim();
    if (raw.isEmpty || _isSearching) {
      return;
    }

    // Fast path: allow direct "lat,lng" input.
    final coordMatch = RegExp(
      r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
    ).firstMatch(raw);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1) ?? '');
      final lng = double.tryParse(coordMatch.group(2) ?? '');
      if (lat != null && lng != null) {
        _setPickedLocation(LatLng(lat, lng), zoom: 15);
        setState(() => _searchResults = const <_MapSearchResult>[]);
        return;
      }
    }

    setState(() => _isSearching = true);
    try {
      final parsed = await _searchProviders(raw);
      if (parsed.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No location found.')));
        return;
      }
      setState(() => _searchResults = parsed);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location search failed.')));
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<List<_MapSearchResult>> _searchProviders(String query) async {
    final providers = <Uri>[
      Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(query)}&format=jsonv2&limit=3',
      ),
      Uri.parse(
        'https://geocode.maps.co/search'
        '?q=${Uri.encodeQueryComponent(query)}&limit=3',
      ),
      Uri.parse(
        'https://photon.komoot.io/api'
        '?q=${Uri.encodeQueryComponent(query)}&limit=3',
      ),
      Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
        '?name=${Uri.encodeQueryComponent(query)}&count=3&language=en&format=json',
      ),
    ];

    for (final uri in providers) {
      try {
        final payload = await _fetchSearchPayload(uri);
        final decoded = jsonDecode(payload);
        final parsed = _parseSearchResponse(decoded);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      } catch (_) {
        // Try next provider.
      }
    }
    return const <_MapSearchResult>[];
  }

  Future<String> _fetchSearchPayload(Uri uri) async {
    final response = await http
        .get(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
            'User-Agent': 'CircleBN/1.0 (map-search)',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Search request failed (${response.statusCode})');
    }
    return response.body;
  }

  List<_MapSearchResult> _parseSearchResponse(dynamic decoded) {
    if (decoded is List) {
      final out = <_MapSearchResult>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final lat = double.tryParse((item['lat'] ?? '').toString());
        final lng = double.tryParse((item['lon'] ?? '').toString());
        if (lat == null || lng == null) {
          continue;
        }
        final title = (item['display_name'] ?? item['name'] ?? '')
            .toString()
            .trim();
        out.add(
          _MapSearchResult(
            title: title.isEmpty ? 'Location' : title,
            point: LatLng(lat, lng),
          ),
        );
        if (out.length >= 3) {
          break;
        }
      }
      return out;
    }

    if (decoded is Map && decoded['features'] is List) {
      final features = decoded['features'] as List;
      final out = <_MapSearchResult>[];
      for (final feature in features) {
        if (feature is! Map) {
          continue;
        }
        final geometry = feature['geometry'];
        if (geometry is! Map || geometry['coordinates'] is! List) {
          continue;
        }
        final coordinates = geometry['coordinates'] as List;
        if (coordinates.length < 2) {
          continue;
        }
        final lng = (coordinates[0] is num)
            ? (coordinates[0] as num).toDouble()
            : double.tryParse(coordinates[0].toString());
        final lat = (coordinates[1] is num)
            ? (coordinates[1] as num).toDouble()
            : double.tryParse(coordinates[1].toString());
        if (lat == null || lng == null) {
          continue;
        }
        final props = feature['properties'];
        final title = props is Map
            ? (props['name'] ??
                      props['street'] ??
                      props['city'] ??
                      props['country'] ??
                      '')
                  .toString()
                  .trim()
            : '';
        out.add(
          _MapSearchResult(
            title: title.isEmpty ? 'Location' : title,
            point: LatLng(lat, lng),
          ),
        );
        if (out.length >= 3) {
          break;
        }
      }
      return out;
    }

    if (decoded is Map && decoded['results'] is List) {
      final results = decoded['results'] as List;
      final out = <_MapSearchResult>[];
      for (final item in results) {
        if (item is! Map) {
          continue;
        }
        final latValue = item['latitude'];
        final lngValue = item['longitude'];
        final lat = latValue is num
            ? latValue.toDouble()
            : double.tryParse(latValue?.toString() ?? '');
        final lng = lngValue is num
            ? lngValue.toDouble()
            : double.tryParse(lngValue?.toString() ?? '');
        if (lat == null || lng == null) {
          continue;
        }
        final name = (item['name'] ?? '').toString().trim();
        final admin = (item['admin1'] ?? '').toString().trim();
        final country = (item['country'] ?? '').toString().trim();
        final titleParts = <String>[
          if (name.isNotEmpty) name,
          if (admin.isNotEmpty) admin,
          if (country.isNotEmpty) country,
        ];
        out.add(
          _MapSearchResult(
            title: titleParts.isEmpty ? 'Location' : titleParts.join(', '),
            point: LatLng(lat, lng),
          ),
        );
        if (out.length >= 3) {
          break;
        }
      }
      return out;
    }

    return const <_MapSearchResult>[];
  }

  void _setPickedLocation(LatLng point, {double zoom = 13}) {
    setState(() {
      _picked = point;
      _latCtrl.text = point.latitude.toStringAsFixed(6);
      _lngCtrl.text = point.longitude.toStringAsFixed(6);
    });
    _mapCtrl.move(point, zoom);
  }

  void _confirmPick(BuildContext context) {
    final lat = double.tryParse(_latCtrl.text.trim()) ?? _picked.latitude;
    final lng = double.tryParse(_lngCtrl.text.trim()) ?? _picked.longitude;
    Navigator.of(context).pop(MapPickerResult(lat: lat, lng: lng));
  }
}

class _MapSearchResult {
  final String title;
  final LatLng point;

  const _MapSearchResult({required this.title, required this.point});
}
