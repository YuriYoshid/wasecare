import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:torch_light/torch_light.dart';
import '../services/heart_rate_service.dart';

class HeartRateScreen extends StatefulWidget {
  const HeartRateScreen({Key? key}) : super(key: key);

  @override
  _HeartRateScreenState createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen> {
  CameraController? _controller;
  final HeartRateService _heartRateService = HeartRateService();
  bool _isMeasuring = false;
  String _heartRate = '-- BPM';
  String _statusMessage = '準備完了';
  double _progress = 0.0;
  Timer? _measurementTimer;
  static const measurementDuration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() {
        _statusMessage = 'カメラの初期化に失敗しました: $e';
      });
    }
  }

  Future<void> _startMeasurement() async {
  if (_controller == null || !_controller!.value.isInitialized) {
    setState(() {
      _statusMessage = 'カメラが準備できていません';
    });
    return;
  }

  try {
    setState(() {
      _isMeasuring = true;
      _heartRate = '測定中...';
      _statusMessage = '指をカメラに当ててください';
      _progress = 0.0;
    });

    // フラッシュをオンにする
    await TorchLight.enableTorch();

    // 心拍数測定を開始
    StreamController<CameraImage> imageStreamController = StreamController<CameraImage>();
    
    // カメラのイメージストリームを開始
    await _controller!.startImageStream((image) {
      if (_isMeasuring) {
        imageStreamController.add(image);
      }
    });

    // HeartRateServiceに画像ストリームを渡す
    _heartRateService.startMeasurement(imageStreamController.stream).listen(
      (result) {
        if (mounted) {
          setState(() {
            _heartRate = '${result.heartRate.round()} BPM';
            if (result.quality != 'good') {
              _statusMessage = '測定品質が低下しています\n指の位置を調整してください';
            } else {
              _statusMessage = '測定中...';
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _statusMessage = 'エラーが発生しました: $error';
          });
          _stopMeasurement();
        }
      },
    );

    // 進行状況の更新タイマー
    _measurementTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (_progress >= 1.0) {
          _stopMeasurement();
        } else {
          setState(() {
            _progress += 0.1 / (measurementDuration.inSeconds * 10);
          });
        }
      },
    );

  } catch (e) {
    setState(() {
      _statusMessage = 'エラーが発生しました: $e';
    });
    _stopMeasurement();
  }
}

  Future<void> _stopMeasurement() async {
    _measurementTimer?.cancel();
    _measurementTimer = null;

    if (_controller?.value.isStreamingImages ?? false) {
      await _controller!.stopImageStream();
    }

    try {
      await TorchLight.disableTorch();
    } catch (e) {
      print('フラッシュのオフに失敗しました: $e');
    }

    _heartRateService.stopMeasurement();

    if (mounted) {
      setState(() {
        _isMeasuring = false;
        _progress = 0.0;
        if (_heartRate != '測定中...') {
          _statusMessage = '測定完了';
        } else {
          _statusMessage = '測定が中断されました';
          _heartRate = '-- BPM';
        }
      });
    }
  }

  @override
  void dispose() {
    _measurementTimer?.cancel();
    _controller?.dispose();
    _heartRateService.stopMeasurement();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '心拍数測定',
          style: TextStyle(fontSize: 24),
        ),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isMeasuring ? Colors.red : Colors.grey,
                  width: 2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _heartRate,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isMeasuring)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          value: _progress,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    '1. スマートフォンの背面カメラに\n人差し指を軽く当ててください',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '2. 測定中は指を動かさないでください',
                    style: TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed: _isMeasuring ? _stopMeasurement : _startMeasurement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isMeasuring ? Colors.red : Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  _isMeasuring ? '測定中止' : '測定開始',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}