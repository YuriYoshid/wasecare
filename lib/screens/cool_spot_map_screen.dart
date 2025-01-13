import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/cool_spot.dart';

class CoolSpotMap extends StatefulWidget {
  @override
  _CoolSpotMapState createState() => _CoolSpotMapState();
}

class _CoolSpotMapState extends State<CoolSpotMap> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Position? _currentPosition;
  
  // サンプルデータ（実際はAPIやデータベースから取得）
  final List<CoolSpot> coolSpots = [
    CoolSpot(
      name: '○○ショッピングモール',
      type: 'ショッピングモール',
      location: LatLng(35.6895, 139.6917),
      address: '東京都...',
    ),
    // 他の涼しい場所を追加
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadCoolSpots();
  }

  // 現在位置を取得
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      setState(() {
        _currentPosition = position;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 14.0,
          ),
        ),
      );
    } catch (e) {
      print('位置情報の取得に失敗しました: $e');
    }
  }

  // マーカーを作成
  void _loadCoolSpots() {
    setState(() {
      _markers = coolSpots.map((spot) => Marker(
        markerId: MarkerId(spot.name),
        position: spot.location,
        infoWindow: InfoWindow(
          title: spot.name,
          snippet: '${spot.type} - ${spot.hasAirCon ? "冷房あり" : ""}',
        ),
      )).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('近くの涼しい場所'),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(35.6895, 139.6917), // 東京
          zoom: 14.0,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        onMapCreated: (controller) {
          setState(() {
            _mapController = controller;
          });
        },
      ),
    );
  }
}