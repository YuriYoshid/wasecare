import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/cool_spot_service.dart';

class CoolSpotMapScreen extends StatefulWidget {
  const CoolSpotMapScreen({Key? key}) : super(key: key);

  @override
  _CoolSpotMapScreenState createState() => _CoolSpotMapScreenState();
}

class _CoolSpotMapScreenState extends State<CoolSpotMapScreen> {
  final MapController _mapController = MapController();
  final CoolSpotService _spotService = CoolSpotService();
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
      if (_currentPosition != null) {
        await _fetchAndDisplaySpots();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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

    _currentPosition = await Geolocator.getCurrentPosition();
    
    if (mounted) {
      setState(() {});
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        14.0,
      );
    }
  }

  Future<void> _fetchAndDisplaySpots() async {
    if (_currentPosition == null) return;

    try {
      final spots = await _spotService.fetchNearbyCoolSpots(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      );

      if (!mounted) return;

      setState(() {
        _markers.clear();

        // 現在位置のマーカー
        _markers.add(
          Marker(
            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            width: 60,
            height: 60,
            child: const Icon(
              Icons.my_location,
              color: Colors.blue,
              size: 40,
            ),
          ),
        );

        // 施設のマーカー
        _markers.addAll(
          spots.map(
            (spot) => Marker(
              point: spot.location,
              width: 60,
              height: 60,
              child: GestureDetector(
                onTap: () => _showSpotDetails(spot),
                child: const Icon(
                  Icons.place,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ),
          ),
        );

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '施設データの取得に失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  void _showSpotDetails(CoolSpot spot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(spot.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('種類: ${spot.type}'),
            if (spot.details['opening_hours'] != null)
              Text('営業時間: ${spot.details['opening_hours']}'),
            if (spot.details['phone'] != null)
              Text('電話: ${spot.details['phone']}'),
            if (spot.details['website'] != null)
              Text('ウェブサイト: ${spot.details['website']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshSpots() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _initializeMap();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              ElevatedButton(
                onPressed: _refreshSpots,
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('近くの涼しい場所'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSpots,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _initializeMap,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
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
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}