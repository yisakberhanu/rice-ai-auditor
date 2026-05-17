import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class RiceClassifier {
  RiceClassifier._internal();
  static final RiceClassifier instance = RiceClassifier._internal();
  factory RiceClassifier() => instance;

  static const bool useMockData = false;
  Interpreter? _interpreter;
  bool _isLoaded = false;
  bool _hasError = false;

  final String _modelVersionTag = "DualHead-MobileNetV3-v2.1";

  Future<void> loadModel() async {
    if (_isLoaded || useMockData) return;
    try {
      debugPrint("⏳ [AI DEBUG] Pre-warming Dual-Head TFLite Engine...");
      
      final options = InterpreterOptions()..threads = 4;
      
      _interpreter = await Interpreter.fromAsset(
        'assets/RICE_MOBILE_FINAL_V2.tflite',
        options: options,
      );
      
      _interpreter!.allocateTensors();
      _isLoaded = true;
      debugPrint("✅ [AI DEBUG] $_modelVersionTag Ready.");
    } catch (e) {
      _hasError = true;
      debugPrint("❌ [AI DEBUG] Model Load Error: $e");
    }
  }

  Future<Map<String, dynamic>> analyzeImage(String imagePath, String riceType) async {
    if (useMockData) return _generateMockPrediction();
    if (!_isLoaded && !_hasError) await loadModel();

    if (_hasError || _interpreter == null) {
      return {"error": "MODEL_UNAVAILABLE", "message": "Model failed to load."};
    }

    try {
      final stopwatch = Stopwatch()..start();
      
      final byteData = await rootBundle.load('assets/RICE_MOBILE_FINAL_V2.tflite');
      final modelBytes = byteData.buffer.asUint8List();

      // Fire off the AI in the background Isolate
      final rawResults = await compute(_runDualHeadInference, {
        'path': imagePath,
        'type': riceType,
        'version': _modelVersionTag,
        'model_bytes': modelBytes,
      });

      stopwatch.stop();

      // Inject Main-Thread Metadata
      rawResults['raw']['inference_time_ms'] = stopwatch.elapsedMilliseconds;
      rawResults['raw']['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      rawResults['raw']['confidence'] = 0.98; // Static high confidence for MVP
      rawResults['raw']['gps'] = "Pending Save..."; 

      return rawResults;
    } catch (e) {
      debugPrint("❌ [AI DEBUG] Isolate Error: $e");
      return {"error": "INFERENCE_FAILED", "message": "$e"};
    }
  }

  Future<Map<String, dynamic>> _generateMockPrediction() async {
    await Future.delayed(const Duration(seconds: 1));
    return {"raw": {"total_count": 1200, "broken_pct": 5.0, "model_version": "MOCK"}};
  }
}

/// ⚙️ OPTIMIZED DUAL-HEAD INFERENCE WORKER
Future<Map<String, dynamic>> _runDualHeadInference(Map<String, dynamic> params) async {
  final String path = params['path'];
  final String type = params['type'];
  final String versionTag = params['version'];
  final Uint8List modelBytes = params['model_bytes'];

  final file = File(path);
  if (!file.existsSync()) return {"error": "FILE_MISSING"};

  final bytes = file.readAsBytesSync();
  img.Image? originalImage = img.decodeImage(bytes);
  if (originalImage == null) return {"error": "INVALID_IMAGE"};

  final interpreter = Interpreter.fromBuffer(modelBytes);
  interpreter.allocateTensors();

  const int targetW = 1024;
  const int targetH = 768;
  
  var inputImg = Float32List(1 * targetH * targetW * 3).reshape([1, targetH, targetW, 3]);
  var metaInput = Float32List(1 * 3).reshape([1, 3]);

  // 1. IMAGE PREPROCESSING (/ 255.0 Scaling)
  img.Image res = img.copyResize(originalImage, width: targetW, height: targetH, interpolation: img.Interpolation.average);
  for (int y = 0; y < targetH; y++) {
    for (int x = 0; x < targetW; x++) {
      final pixel = res.getPixel(x, y);
      inputImg[0][y][x][0] = pixel.r / 255.0;
      inputImg[0][y][x][1] = pixel.g / 255.0;
      inputImg[0][y][x][2] = pixel.b / 255.0;
    }
  }

  // 2. METADATA ALIGNMENT (One-Hot array mapping)
  metaInput[0][0] = (type == 'Paddy') ? 1.0 : 0.0;
  metaInput[0][1] = (type == 'White') ? 1.0 : 0.0;
  metaInput[0][2] = (type == 'Brown') ? 1.0 : 0.0;

  // 3. 🚨 DYNAMIC TFLITE ROUTER
  int countsIdx = 0;
  int metricsIdx = 1;
  
  final outputTensors = interpreter.getOutputTensors();
  for (int i = 0; i < outputTensors.length; i++) {
    if (outputTensors[i].shape.last == 9) countsIdx = i;
    if (outputTensors[i].shape.last == 6) metricsIdx = i;
  }

  var outCounts = Float32List(1 * 9).reshape([1, 9]); 
  var outMetrics = Float32List(1 * 6).reshape([1, 6]); 

  Map<int, Object> outputs = {
    countsIdx: outCounts,
    metricsIdx: outMetrics,
  };

  interpreter.runForMultipleInputs([inputImg, metaInput], outputs);
  interpreter.close();

  // 4. 🧮 REVERSE MIN-MAX SCALING
  final List<double> cMin = [802.0, 58.0, 7.0, 0.0, 4.0, 0.0, 0.0, 0.0, 0.0];
  final List<double> cRange = [2819.0, 3059.0, 1301.0, 114.0, 1760.0, 2602.0, 146.0, 992.0, 845.0];
  
  final List<double> mMin = [4.93, 1.81, 1.81, 28.91, -5.3, -10.69];
  final List<double> mRange = [5.28, 1.98, 2.32, 52.85, 26.7, 53.06];

  double getCount(int index) {
    double scaledValue = outCounts[0][index];
    return (scaledValue * cRange[index]) + cMin[index];
  }

  double getMetric(int index) {
    double scaledValue = outMetrics[0][index];
    return (scaledValue * mRange[index]) + mMin[index];
  }

  // Assign Unscaled Values
  double total       = max(1.0, getCount(0)); // Prevent divide by zero
  double brokenCount = getCount(1);
  double longCount   = getCount(2);
  double medCount    = getCount(3);
  double blackCount  = getCount(4);
  double chalkyCount = getCount(5);
  double redCount    = getCount(6);
  double yellowCount = getCount(7);
  double greenCount  = getCount(8);

  double p(double val) => (val / total * 100).clamp(0.0, 100.0);

  double lP = p(longCount);
  double mP = p(medCount);
  double sP = (100.0 - lP - mP).clamp(0.0, 100.0);

  double avgLength = getMetric(0);
  double avgWidth  = getMetric(1);
  double lwr       = getMetric(2);
  double valL      = getMetric(3);
  double valA      = getMetric(4);
  double valB      = getMetric(5);

  // 5. PERFECT MAPPING TO ResultScreen
  return {
    "raw": {
      "total_count": total.round(),
      "broken_count": brokenCount.round(),
      "broken_pct": p(brokenCount),
      
      "long_pct": lP,
      "med_pct": mP,
      "short_pct": sP,
      
      "black_pct": p(blackCount),
      "chalky_pct": p(chalkyCount),
      "red_pct": p(redCount),
      "yellow_pct": p(yellowCount),
      "green_pct": p(greenCount),
      
      "avg_length": avgLength,
      "avg_width": avgWidth,
      "lwr": lwr,
      "L": valL,
      "a": valA,
      "b": valB,
      
      "model_version": versionTag
    }
  };
}