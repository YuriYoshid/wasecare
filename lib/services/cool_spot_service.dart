import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class CoolSpot {
  final String name;
  final String type;
  final LatLng location;
  final Map<String, dynamic> details;

  CoolSpot({
    required this.name,
    required this.type,
    required this.location,
    required this.details,
  });
}

class CoolSpotService {
  static const radius = 2000; // 検索範囲（メートル）

  Future<List<CoolSpot>> fetchNearbyCoolSpots(LatLng currentLocation) async {
    try {
      // クエリに日本語名の施設を含めるように修正
      final query = """
        [out:json][timeout:25];
        area[name="日本"]->.japan;
        (
          // ショッピング施設
          nwr["shop"="mall"](area.japan)(around:$radius,${currentLocation.latitude},${currentLocation.longitude});
          
          // コンビニ
          nwr["shop"="convenience"](area.japan)(around:$radius,${currentLocation.latitude},${currentLocation.longitude});
          
          // スーパーマーケット
          nwr["shop"="supermarket"](area.japan)(around:$radius,${currentLocation.latitude},${currentLocation.longitude});
          
          // 図書館
          nwr["amenity"="library"](area.japan)(around:$radius,${currentLocation.latitude},${currentLocation.longitude});
          
          // コミュニティセンター
          nwr["amenity"="community_centre"](area.japan)(around:$radius,${currentLocation.latitude},${currentLocation.longitude});

          // カフェ
          nwr["amenity"="cafe"](area.japan)(around:$radius,${currentLocation.latitude},${currentLocation.longitude});
          
          // 映画館
          nwr["amenity"="cinema"](area.japan)(around:$radius,${currentLocation.latitude},${currentLocation.longitude});
        );
        out body;
        >;
        out skel qt;
      """;

      final uri = Uri.parse('https://overpass-api.de/api/interpreter');
      final response = await http.post(
        uri,
        body: query,
        headers: {
          'User-Agent': 'CoolSpotApp/1.0',
          'Accept': 'application/json',
          'Accept-Charset': 'utf-8',
        },
      );

      if (response.statusCode == 200) {
        // レスポンスをUTF-8としてデコード
        final jsonString = utf8.decode(response.bodyBytes);
        final data = json.decode(jsonString) as Map<String, dynamic>;
        final elements = data['elements'] as List;
        
        final spots = <CoolSpot>[];
        
        for (var element in elements) {
          try {
            final Map<String, dynamic> tags = 
                (element['tags'] as Map<String, dynamic>?) ?? {};
            
            if (tags['name'] == null) continue;

            final LatLng location;
            if (element['type'] == 'node') {
              location = LatLng(
                element['lat'].toDouble(),
                element['lon'].toDouble(),
              );
            } else if (element['type'] == 'way' && element['center'] != null) {
              location = LatLng(
                element['center']['lat'].toDouble(),
                element['center']['lon'].toDouble(),
              );
            } else {
              continue;
            }

            String name = tags['name:ja'] ?? tags['name'] ?? '不明な施設';
            if (name.isEmpty) continue;

            spots.add(CoolSpot(
              name: name,
              type: _determineType(tags),
              location: location,
              details: tags,
            ));
          } catch (e) {
            print('Error processing element: $e');
            continue;
          }
        }
        
        return spots;
      } else {
        throw Exception('API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching cool spots: $e');
      throw Exception('施設データの取得に失敗しました: $e');
    }
  }

  String _determineType(Map<String, dynamic> tags) {
    final shop = tags['shop'];
    final amenity = tags['amenity'];

    if (shop == 'mall') return 'ショッピングモール';
    if (shop == 'convenience') return 'コンビニ';
    if (shop == 'supermarket') return 'スーパーマーケット';
    if (amenity == 'library') return '図書館';
    if (amenity == 'community_centre') return 'コミュニティセンター';
    if (amenity == 'cafe') return 'カフェ';
    if (amenity == 'cinema') return '映画館';
    
    return '施設';
  }
}