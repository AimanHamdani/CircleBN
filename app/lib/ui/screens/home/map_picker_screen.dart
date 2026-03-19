import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

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
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;

  @override
  void initState() {
    super.initState();
    _latCtrl = TextEditingController(text: _picked.latitude.toStringAsFixed(6));
    _lngCtrl = TextEditingController(text: _picked.longitude.toStringAsFixed(6));
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useFallback = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Pick Location'),
        centerTitle: true,
      ),
      body: useFallback ? _desktopFallback(context) : _interactiveMap(context),
    );
  }

  Widget _interactiveMap(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _picked,
            initialZoom: 13,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
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
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ],
            ),
          ],
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
                  child: const Text('Use'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopFallback(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Map interaction has issues on Windows. Enter coordinates below or open map in browser.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _latCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Latitude'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _lngCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Longitude'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _openInBrowser,
            child: const Text('Open Map in Browser'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => _confirmPick(context),
            child: const Text('Use Coordinates'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInBrowser() async {
    final lat = double.tryParse(_latCtrl.text.trim()) ?? _picked.latitude;
    final lng = double.tryParse(_lngCtrl.text.trim()) ?? _picked.longitude;
    final uri = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=15/$lat/$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _confirmPick(BuildContext context) {
    final lat = double.tryParse(_latCtrl.text.trim()) ?? _picked.latitude;
    final lng = double.tryParse(_lngCtrl.text.trim()) ?? _picked.longitude;
    Navigator.of(context).pop(MapPickerResult(lat: lat, lng: lng));
  }
}

