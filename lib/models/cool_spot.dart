import 'package:google_maps_flutter/google_maps_flutter.dart';

class CoolSpot {
  final String name;
  final String type;
  final LatLng location;
  final String address;
  final bool hasAirCon;

  CoolSpot({
    required this.name,
    required this.type,
    required this.location,
    required this.address,
    this.hasAirCon = true,
  });

  // JSONからオブジェクトを生成するファクトリメソッド
  factory CoolSpot.fromJson(Map<String, dynamic> json) {
    return CoolSpot(
      name: json['name'],
      type: json['type'],
      location: LatLng(
        json['latitude'] as double,
        json['longitude'] as double,
      ),
      address: json['address'],
      hasAirCon: json['hasAirCon'] ?? true,
    );
  }

  // オブジェクトをJSONに変換するメソッド
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'address': address,
      'hasAirCon': hasAirCon,
    };
  }
}