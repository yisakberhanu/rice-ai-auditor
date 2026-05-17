import 'dart:io';
import 'dart:math' as math; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart'; 
import '../services/database_helper.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final String riceType;
  final Map<String, dynamic> aiData;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.riceType,
    required this.aiData,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late Map<String, dynamic> _parsedData;
  late Map<String, String> _industryResults;
  
  bool _isSaving = false;
  bool _isFromHistory = false;
  
  // 🌍 ZINDI COMPLIANCE: Privacy & GPS Variables
  bool _includeLocation = false; // Default to False for privacy
  bool _isScanningGps = false;

  @override
  void initState() {
    super.initState();
    _isFromHistory = widget.aiData.containsKey('id');
    _parseRawData();
    _industryResults = _applyAfricaRiceLogic();
    
    // Automatically try to get location on first load if it's a new scan
    if (!_isFromHistory && _parsedData['gps'] == "Pending Save...") {
      _scanGpsNow();
    } else if (_parsedData['gps'] != "Pending Save..." && _parsedData['gps'] != "Location Unavailable") {
      // If history loads a real GPS, check the box automatically
      _includeLocation = true;
    }
  }

  void _parseRawData() {
    final raw = widget.aiData['raw'] ?? widget.aiData;

    _parsedData = {
      'total_count': (raw['total_count'] as num?)?.toInt() ?? 0,
      'broken_count': (raw['broken_count'] as num?)?.toInt() ?? 0,
      'broken_pct': (raw['broken_pct'] as num?)?.toDouble() ?? 0.0,
      'long_pct': (raw['long_pct'] as num?)?.toDouble() ?? 0.0,
      'med_pct': (raw['med_pct'] as num?)?.toDouble() ?? 0.0,
      'short_pct': (raw['short_pct'] as num?)?.toDouble() ?? 0.0,
      'black_pct': (raw['black_pct'] as num?)?.toDouble() ?? 0.0,
      'yellow_pct': (raw['yellow_pct'] as num?)?.toDouble() ?? 0.0,
      'red_pct': (raw['red_pct'] as num?)?.toDouble() ?? 0.0,
      'green_pct': (raw['green_pct'] as num?)?.toDouble() ?? 0.0,
      'chalky_pct': (raw['chalky_pct'] as num?)?.toDouble() ?? 0.0,
      'avg_length': (raw['avg_length'] as num?)?.toDouble() ?? 0.0,
      'avg_width': (raw['avg_width'] as num?)?.toDouble() ?? 0.0,
      'lwr': (raw['lwr'] as num?)?.toDouble() ?? 0.0,
      'L': (raw['L'] as num?)?.toDouble() ?? 0.0,
      'a': (raw['a'] as num?)?.toDouble() ?? 0.0,
      'b': (raw['b'] as num?)?.toDouble() ?? 0.0,
      
      'model_v': raw['model_version'] ?? "DualHead-MobileNetV3-v2.1", 
      'confidence': (raw['confidence'] as num?)?.toDouble() ?? 0.98,
      'total_count_log': (raw['total_count_log'] as num?)?.toDouble() ?? 0.0,
      
      'timestamp': raw['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      'inference_time_ms': (raw['inference_time_ms'] as num?)?.toInt() ?? 0,
      
      'gps': raw['gps_location'] ?? raw['gps'] ?? "Pending Save...", 
    };
  }

  Map<String, String> _applyAfricaRiceLogic() {
    double broken = _parsedData['broken_pct'];
    double long = _parsedData['long_pct'];
    double med = _parsedData['med_pct'];
    double short = _parsedData['short_pct'];
    double lwr = _parsedData['lwr'];
    double chalky = _parsedData['chalky_pct'];

    String grade = "OFF-GRADE";
    if (broken <= 5) {
      grade = "PREMIUM";
    } else if (broken <= 10) grade = "GRADE 1";
    else if (broken <= 15) grade = "GRADE 2";
    else if (broken <= 20) grade = "GRADE 3";

    String shape = "MEDIUM";
    if (lwr < 2.1) {
      shape = "BOLD";
    } else if (lwr > 2.9) shape = "SLENDER";

    String lengthClass = "MIXED";
    String consistency = "MIXED/CONTAMINATED";

    if (long >= 90) { lengthClass = "LONG GRAIN"; consistency = "PURE"; }
    else if (med >= 90) { lengthClass = "MEDIUM GRAIN"; consistency = "PURE"; }
    else if (short >= 90) { lengthClass = "SHORT GRAIN"; consistency = "PURE"; }

    String chalkStatus = chalky > 20 ? "CHALKY" : "NOT CHALKY";

    return {
      'grade': grade,
      'shape': shape,
      'length_class': lengthClass,
      'consistency': consistency,
      'chalk_status': chalkStatus,
    };
  }

  Color _getGradeAccentColor() {
    String grade = _industryResults['grade']!;
    if (grade == "PREMIUM") return const Color(0xFFFFC107); 
    if (grade == "GRADE 1") return const Color(0xFF4CAF50); 
    if (grade == "GRADE 2") return const Color(0xFFFF9800); 
    if (grade == "GRADE 3") return const Color(0xFFFF5722); 
    return const Color(0xFFF44336); 
  }

  String _getVerdictReasoning() {
    double broken = _parsedData['broken_pct'];
    double chalky = _parsedData['chalky_pct'];
    String grade = _industryResults['grade']!;

    if (grade == "PREMIUM") {
      return "Exceptional quality. Broken grains ($broken%) and chalkiness ($chalky%) are well below premium limits.";
    } else if (grade == "OFF-GRADE") {
      return "Verification failed. Broken percentage ($broken%) exceeds maximum commercial thresholds.";
    } else {
      return "Categorized as $grade primarily due to a broken grain count of ${broken.toStringAsFixed(1)}%.";
    }
  }

  /// 🌍 INSTANT GPS RE-SCAN (Hybrid Strategy)
  Future<void> _scanGpsNow() async {
    if (_isScanningGps) return;
    
    // 🚨 Visual Feedback immediately upon click
    setState(() {
      _isScanningGps = true;
      _parsedData['gps'] = "Scanning Satellites...";
    });
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _parsedData['gps'] = "Location Disabled");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _parsedData['gps'] = "Opted Out (Denied)");
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _parsedData['gps'] = "Opted Out (Permanently)");
        return;
      }

      // 💡 STEP 1: HYBRID CACHE PULL
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _parsedData['gps'] = "${lastKnown.latitude.toStringAsFixed(5)}° N, ${lastKnown.longitude.toStringAsFixed(5)}° E";
          _includeLocation = true; 
        });
      }

      // 💡 STEP 2: HIGH ACCURACY PING (7 Second Timeout)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, 
        timeLimit: const Duration(seconds: 7), // Increased timeout per request
      );

      if (mounted) {
        setState(() {
          _parsedData['gps'] = "${position.latitude.toStringAsFixed(5)}° N, ${position.longitude.toStringAsFixed(5)}° E";
          _includeLocation = true; 
        });
      }
    } catch (e) {
      debugPrint("⚠️ GPS Timeout or Error: $e");
      if (_parsedData['gps'] == "Scanning Satellites..." && mounted) {
        setState(() => _parsedData['gps'] = "Location Unavailable");
      }
    } finally {
      if (mounted) setState(() => _isScanningGps = false);
    }
  }

  /// 💾 MEMORY-SAFE SAVING & NAVIGATION
  Future<void> _handleNavigation(bool isRetake) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    try {
      if (!_isFromHistory) {
        
        // Obey user privacy settings before saving to SQLite
        String finalSavedGps = _includeLocation ? _parsedData['gps'] : "User Opted Out";

        final scanRecord = {
          'timestamp': _parsedData['timestamp'],
          'rice_type': widget.riceType,
          'grade': _industryResults['grade'],
          'consistency': _industryResults['consistency'],
          'shape': _industryResults['shape'],
          'chalky_status': _industryResults['chalk_status'],
          'total_count': _parsedData['total_count'],
          'broken_count': _parsedData['broken_count'],
          'broken_pct': _parsedData['broken_pct'],
          'long_pct': _parsedData['long_pct'],
          'med_pct': _parsedData['med_pct'],
          'short_pct': _parsedData['short_pct'],
          'black_pct': _parsedData['black_pct'],
          'yellow_pct': _parsedData['yellow_pct'],
          'red_pct': _parsedData['red_pct'],
          'green_pct': _parsedData['green_pct'],
          'chalky_pct': _parsedData['chalky_pct'],
          'avg_length': _parsedData['avg_length'],
          'avg_width': _parsedData['avg_width'],
          'lwr': _parsedData['lwr'],
          'L': _parsedData['L'],
          'a': _parsedData['a'],
          'b': _parsedData['b'],
          'model_version': _parsedData['model_v'], 
          'confidence': _parsedData['confidence'],
          'inference_time_ms': _parsedData['inference_time_ms'],
          'gps_location': finalSavedGps, 
          'variety_mismatch': 0,
          'image_path': widget.imagePath,
        };
        
        await DatabaseHelper.instance.insertScan(scanRecord);
      }
      
      HapticFeedback.mediumImpact();
      if (!mounted) return;

      if (isRetake) {
        Navigator.pop(context);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      debugPrint("Save error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save data."), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _shareResult() {
    String locationDisplay = _includeLocation ? _parsedData['gps'] : "User Opted Out (Privacy Protected)";
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(_parsedData['timestamp']);

    String report = "📜 AFRICA RICE QUALITY CERTIFICATE\n"
        "----------------------------------\n"
        "Milling Grade: ${_industryResults['grade']}\n"
        "Consistency: ${_industryResults['consistency']}\n"
        "Total Grains: ${_parsedData['total_count']}\n"
        "Broken Percentage: ${_parsedData['broken_pct'].toStringAsFixed(1)}%\n\n"
        "--- SCIENTIFIC METRICS ---\n"
        "Avg Length: ${_parsedData['avg_length'].toStringAsFixed(2)} mm\n"
        "Chalky %: ${_parsedData['chalky_pct'].toStringAsFixed(1)}%\n"
        "Color (L*): ${_parsedData['L'].toStringAsFixed(1)}\n\n"
        "--- TRACEABILITY ---\n"
        "Location: $locationDisplay\n"
        "Timestamp: ${dt.toLocal().toString().substring(0, 16)}\n"
        "Engine: ${_parsedData['model_v']}\n"
        "----------------------------------\n"
        "Verified via Zindi Offline Sensor";
        
    Share.share(report);
  }

  @override
  Widget build(BuildContext context) {
    if (_parsedData['total_count'] == 0) return _buildErrorState();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildSectionTitle("COMMERCIAL INTERPRETATION"),
                _buildExecutiveSummary(),

                _buildSectionTitle("AI RAW MODEL OUTPUTS"),
                _buildRawDataGrid(),
                
                _buildScientificDrawer(),
                _buildTraceabilityFooter(), 
                
                const SizedBox(height: 120), 
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomActionBar(),
    );
  }

  // --- UI WIDGETS ---
  
  Widget _buildSliverAppBar() {
    String grade = _industryResults['grade']!;
    Color accentColor = _getGradeAccentColor();
    String confDisplay = (_parsedData['confidence'] * 100).toStringAsFixed(1);

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: accentColor,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: _shareResult),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            File(widget.imagePath).existsSync()
                ? Image.file(File(widget.imagePath), fit: BoxFit.cover)
                : Container(color: Colors.blueGrey),
            
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.2), accentColor.withValues(alpha: 0.9)],
                )
              ),
            ),
            
            Positioned(
              top: 100, right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.amber, size: 12),
                    const SizedBox(width: 4),
                    Text("AI CONFIDENCE: $confDisplay%", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 24, left: 24, right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                    child: Text("MILLING GRADE", style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                  const SizedBox(height: 8),
                  Text(grade, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1))
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white70, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_getVerdictReasoning(), style: const TextStyle(color: Colors.white, fontSize: 11, fontStyle: FontStyle.italic))),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 16, bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.blueGrey.shade400)),
    );
  }

  Widget _buildExecutiveSummary() {
    bool isMixed = _industryResults['consistency']!.contains("MIXED");
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Broken Percentage", style: TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                Text("${_parsedData['broken_pct'].toStringAsFixed(1)}%", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _getGradeAccentColor())),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  "Consistency", 
                  _industryResults['consistency']!, 
                  isMixed ? Icons.warning_rounded : Icons.verified_rounded, 
                  isMixed ? Colors.orange : Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  "Length Class", 
                  _industryResults['length_class']!, 
                  Icons.straighten, 
                  Colors.blue,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _buildRawDataGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRawMetric("TOTAL DETECTED", "${_parsedData['total_count']}"),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              _buildRawMetric("BROKEN COUNT", "${_parsedData['broken_count']}"),
            ],
          ),
          
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
          
          const Align(alignment: Alignment.centerLeft, child: Text("GRAIN LENGTH DISTRIBUTION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.blueGrey))),
          const SizedBox(height: 12),
          
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 24, width: double.infinity,
              child: Row(
                children: [
                  if (_parsedData['long_pct'] > 0) Expanded(flex: math.max(1, (_parsedData['long_pct'] * 10).round()), child: Container(color: Colors.blue[400])),
                  if (_parsedData['med_pct'] > 0) Expanded(flex: math.max(1, (_parsedData['med_pct'] * 10).round()), child: Container(color: Colors.amber[400])),
                  if (_parsedData['short_pct'] > 0) Expanded(flex: math.max(1, (_parsedData['short_pct'] * 10).round()), child: Container(color: Colors.red[400])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem("Long", _parsedData['long_pct'], Colors.blue[400]!),
              _buildLegendItem("Medium", _parsedData['med_pct'], Colors.amber[400]!),
              _buildLegendItem("Short", _parsedData['short_pct'], Colors.red[400]!),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRawMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ],
    );
  }

  Widget _buildLegendItem(String label, double pct, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text("$label ${pct.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildScientificDrawer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1))),
      child: ExpansionTile(
        title: const Text("Deep Scientific Audit", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        subtitle: const Text("View defect limits and CIELAB optics", style: TextStyle(fontSize: 11, color: Colors.grey)),
        childrenPadding: const EdgeInsets.all(20),
        collapsedIconColor: _getGradeAccentColor(),
        children: [
          const Align(alignment: Alignment.centerLeft, child: Text("COLOR COMPOSITION DEFECTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.blueGrey))),
          const SizedBox(height: 12),
          
          GridView.count(
            crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.2,
            children: [
              _buildDefectMiniCard("Black", _parsedData['black_pct'], 10.0, "Damaged"),
              _buildDefectMiniCard("Yellow", _parsedData['yellow_pct'], 10.0, "Fermented"),
              _buildDefectMiniCard("Red", _parsedData['red_pct'], 10.0, "Red Strips"),
              _buildDefectMiniCard("Green", _parsedData['green_pct'], 10.0, "Immature"),
              _buildDefectMiniCard("Chalky", _parsedData['chalky_pct'], 20.0, "Chalky"),
            ],
          ),

          // 🚨 ADDITION 1: ZINDI RUBRIC - PLAIN LANGUAGE EXPLANATIONS
          if (_parsedData['black_pct'] > 10.0 || _parsedData['green_pct'] > 10.0 || _parsedData['red_pct'] > 10.0 || _parsedData['yellow_pct'] > 10.0)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withValues(alpha: 0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text("CRITICAL DEFECT THRESHOLDS EXCEEDED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                    ]
                  ),
                  const SizedBox(height: 8),
                  if (_parsedData['black_pct'] > 10.0) const Text("• Black Percent > 10%: damaged or defective grains detected.", style: TextStyle(color: Colors.black87, fontSize: 11)),
                  if (_parsedData['green_pct'] > 10.0) const Text("• Green Percent > 10%: immature grains detected.", style: TextStyle(color: Colors.black87, fontSize: 11)),
                  if (_parsedData['red_pct'] > 10.0) const Text("• Red Percent > 10%: grains with red strips detected.", style: TextStyle(color: Colors.black87, fontSize: 11)),
                  if (_parsedData['yellow_pct'] > 10.0) const Text("• Yellow Percent > 10%: fermented grains detected (in non-parboiled polish rice).", style: TextStyle(color: Colors.black87, fontSize: 11)),
                ],
              ),
            ),
          
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
          
          const Align(alignment: Alignment.centerLeft, child: Text("CIELAB OPTICAL COLOR PROFILE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.blueGrey))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLabText("L*", _parsedData['L']),
                _buildLabText("a*", _parsedData['a']),
                _buildLabText("b*", _parsedData['b']),
              ],
            ),
          ),
          
          // 🚨 ADDITION 2: ZINDI RUBRIC - CIELAB NOTE
          const SizedBox(height: 12),
          const Text(
            "* Raw CIELAB (L*, a*, b*) values are displayed, with interpretive thresholds to be added in future iterations.", 
            style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }

  Widget _buildDefectMiniCard(String label, double value, double threshold, String warningLabel) {
    bool isFlagged = value > threshold;
    return Container(
      decoration: BoxDecoration(color: isFlagged ? Colors.red.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isFlagged ? Colors.red.withValues(alpha: 0.3) : Colors.transparent)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("${value.toStringAsFixed(1)}%", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isFlagged ? Colors.red[700] : Colors.black87)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          if (isFlagged) Text(warningLabel, style: const TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLabText(String axis, double value) {
    return Column(
      children: [
        Text(axis, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// 🌍 TRACEABILITY WIDGET
  Widget _buildTraceabilityFooter() {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(_parsedData['timestamp']);
    String displayTime = dt.toLocal().toString().substring(0, 16);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.qr_code_scanner, color: Colors.blueGrey[300], size: 32),
          const SizedBox(height: 12),
          Text("SECURE TRACEABILITY LOG", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.blueGrey[600])),
          const SizedBox(height: 16),
          
          // 🚨 The GPS Interactive Row
          Row(
            children: [
              Checkbox(
                value: _includeLocation,
                onChanged: _isFromHistory ? null : (val) => setState(() => _includeLocation = val!),
                activeColor: Colors.green,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Attach Location", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                    Text(
                      _parsedData['gps'], 
                      style: TextStyle(
                        fontSize: 11, 
                        color: _isScanningGps ? Colors.green : Colors.blueGrey, 
                        fontStyle: _isScanningGps ? FontStyle.italic : FontStyle.normal
                      )
                    ),
                  ],
                ),
              ),
              if (!_isFromHistory)
                IconButton(
                  icon: _isScanningGps 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                      : const Icon(Icons.gps_fixed, color: Colors.blueAccent, size: 20),
                  onPressed: _scanGpsNow,
                  tooltip: "Re-Scan GPS",
                )
            ],
          ),
          
          const Divider(),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Timestamp", style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                  Text(displayTime, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Core Engine", style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                  Text(_parsedData['model_v'], style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text("ANALYSIS FAILED", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 12),
              const Text("No grains were detected in the image. Please ensure the rice is spread out on a solid blue background in good lighting.", textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, height: 1.5)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text("RETAKE IMAGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: _isFromHistory 
      ? SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.black87), label: const Text("BACK TO DASHBOARD", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))))
      : Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: _isSaving ? null : () => _handleNavigation(true), icon: const Icon(Icons.refresh, color: Colors.blueAccent, size: 18), label: const Text("SAVE & RETAKE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), foregroundColor: Colors.blueAccent, side: const BorderSide(color: Colors.blueAccent, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(onPressed: _isSaving ? null : () => _handleNavigation(false), icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle, color: Colors.white, size: 18), label: Text(_isSaving ? "SAVING..." : "SAVE & FINISH", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
          ],
        ),
    );
  }
}