import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class CoolSpotMapScreen extends StatefulWidget {
  const CoolSpotMapScreen({Key? key}) : super(key: key);

  @override
  _CoolSpotMapScreenState createState() => _CoolSpotMapScreenState();
}

class _CoolSpotMapScreenState extends State<CoolSpotMapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  final List<Marker> _markers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      await _getCurrentLocation();
      _addSampleMarkers();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw '位置情報サービスが無効です。設定から位置情報を有効にしてください。';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw '位置情報の許可が必要です。';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw '位置情報の許可が永続的に拒否されています。設定から許可してください。';
    }

    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = position;
        _markers.add(
          Marker(
            point: LatLng(position.latitude, position.longitude),
            width: 60,
            height: 60,
            child: const Icon(
              Icons.my_location,
              color: Colors.blue,
              size: 40,
            ),
          ),
        );
      });
    }
  }

  void _addSampleMarkers() {
    final sampleSpots = [
      {
        'name': 'イオンモール',
        'type': 'ショッピングモール',
        'lat': 35.6895,
        'lng': 139.6917,
      },
      // 他のサンプルデータを追加
    ];

    setState(() {
      _markers.addAll(
        sampleSpots.map(
          (spot) => Marker(
            point: LatLng(spot['lat'] as double, spot['lng'] as double),
            width: 60,
            height: 60,
            child: GestureDetector(
              onTap: () => _showSpotDetails(spot),
              child: const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40,
              ),
            ),
          ),
        ),
      );
    });
  }

  void _showSpotDetails(Map<String, dynamic> spot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(spot['name'] as String),
        content: Text('${spot['type']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeMap,
                  child: const Text('再試行'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('近くの涼しい場所'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentPosition != null
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : const LatLng(35.6895, 139.6917),
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.wasecare',
          ),
          MarkerLayer(markers: _markers),
        ],
      ),
    );
  }
}