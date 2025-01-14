import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:camera/camera.dart';

class HeartRateService {
  final String serverUrl;
  WebSocketChannel? _channel;
  StreamController<HeartRateResult>? _controller;

  HeartRateService({
    this.serverUrl = 'wss://wasecare-server.onrender.com/ws/heartrate',
  });

  Stream<HeartRateResult> startMeasurement(Stream<CameraImage> imageStream) {
    _controller = StreamController<HeartRateResult>();
    
    // WebSocket接続を確立
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));

    // カメラ画像のストリームを処理
    imageStream.listen((image) {
      if (_channel == null) return;

      // 画像から赤色成分を抽出
      double redValue = _extractRedValue(image);
      
      // サーバーにデータを送信
      _channel!.sink.add(jsonEncode({
        'red_value': redValue,
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
      }));
    });

    // サーバーからの応答を処理
    _channel!.stream.listen(
      (data) {
        final json = jsonDecode(data);
        _controller?.add(HeartRateResult(
          heartRate: json['heart_rate'].toDouble(),
          quality: json['quality'],
        ));
      },
      onError: (error) {
        _controller?.addError(error);
      },
      onDone: () {
        _controller?.close();
      },
    );

    return _controller!.stream;
  }

  void stopMeasurement() {
    _channel?.sink.close();
    _channel = null;
    _controller?.close();
    _controller = null;
  }

  double _extractRedValue(CameraImage image) {
    // YUV420形式から赤色成分を抽出
    final int width = image.width;
    final int height = image.height;
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;
    
    double totalRed = 0;
    int pixelCount = 0;
    
    // 画像中央部分のみを処理（ノイズ軽減のため）
    int startX = width ~/ 3;
    int startY = height ~/ 3;
    int endX = (width * 2) ~/ 3;
    int endY = (height * 2) ~/ 3;
    
    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        int index = y * width + x;
        
        // YUV to RGB conversion
        int yValue = yPlane[index] & 0xFF;
        int uValue = uPlane[index ~/ 4] & 0xFF;
        int vValue = vPlane[index ~/ 4] & 0xFF;
        
        // 赤色成分の計算
        double r = yValue + 1.370705 * (vValue - 128);
        r = r.clamp(0, 255);
        
        totalRed += r;
        pixelCount++;
      }
    }
    
    return totalRed / pixelCount;
  }
}

class HeartRateResult {
  final double heartRate;
  final String quality;

  HeartRateResult({
    required this.heartRate,
    required this.quality,
  });
}