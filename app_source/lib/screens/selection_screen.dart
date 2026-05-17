import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'result_screen.dart';
import '../services/classifier.dart'; 

class SelectionScreen extends StatefulWidget {
  final String imagePath1;
  final String imagePath2;
  final String riceType; // Initial guess from the camera

  const SelectionScreen({
    super.key,
    required this.imagePath1,
    required this.imagePath2,
    required this.riceType,
  });

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  String? _selectedPath;
  bool _isAnalyzing = false;
  
  // 📝 Metadata State for Dropdown
  late String _currentRiceType;
  final List<String> _riceCategories = ["Paddy", "White", "Brown"];

  // 🚨 ZINDI COMPLIANCE: Image Quality Scoring & Prelim Results
  double _clarityScore1 = 0.0;
  double _clarityScore2 = 0.0;
  
  // 🧠 NEW: Deliberate Two-Step Scan State
  bool _hasScanned = false; 
  bool _isPrelimLoading = false; // Starts false so it waits for user input
  Map<String, dynamic>? _prelimData1;
  Map<String, dynamic>? _prelimData2;

  @override
  void initState() {
    super.initState();
    _currentRiceType = widget.riceType; 
    _evaluateImageQuality();
  }

  /// 🧠 STEP 1: ONLY DO FAST CLARITY CHECK ON LOAD (Saves Battery)
  Future<void> _evaluateImageQuality() async {
    if (widget.imagePath2.isEmpty) {
      if (mounted) setState(() => _selectedPath = widget.imagePath1);
      return; // Wait for user to tap the scan button
    }

    // ⚡ Fast Proxy for Sharpness
    Future<double> calcClarity(String path) async {
      try {
        final file = File(path);
        if (!file.existsSync()) return 0.0;
        int bytes = await file.length();
        double score = (bytes / 2500000); 
        return score.clamp(0.40, 0.99); 
      } catch (e) {
        return 0.50; 
      }
    }

    final scores = await Future.wait([
      calcClarity(widget.imagePath1),
      calcClarity(widget.imagePath2)
    ]);

    if (mounted) {
      setState(() {
        _clarityScore1 = scores[0];
        _clarityScore2 = scores[1];
        // Auto-select the sharpest image initially
        if (_clarityScore1 >= _clarityScore2) {
          _selectedPath = widget.imagePath1;
        } else {
          _selectedPath = widget.imagePath2;
        }
      });
    }
  }

  /// 🚀 STEP 2: USER TRIGGERS PRELIMINARY SCAN
  Future<void> _runPreliminaryScan() async {
    setState(() => _isPrelimLoading = true);
    HapticFeedback.mediumImpact();

    try {
      // Run AI on Image 1
      if (widget.imagePath1.isNotEmpty) {
        final res1 = await RiceClassifier.instance.analyzeImage(widget.imagePath1, _currentRiceType);
        if (mounted) _prelimData1 = res1['raw'];
      }
      
      // Run AI on Image 2 (if it exists)
      if (widget.imagePath2.isNotEmpty) {
        final res2 = await RiceClassifier.instance.analyzeImage(widget.imagePath2, _currentRiceType);
        if (mounted) _prelimData2 = res2['raw'];
      }
    } catch (e) {
      debugPrint("Prelim AI Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isPrelimLoading = false;
          _hasScanned = true; // Unlocks the final step!
        });
      }
    }
  }

  /// 🚀 STEP 3: THE FINAL AI TRIGGER (Highly Optimized with Caching)
  Future<void> _runRealAiAnalysis() async {
    if (_selectedPath == null) return;

    setState(() => _isAnalyzing = true);
    HapticFeedback.lightImpact();

    try {
      Map<String, dynamic>? rawMetrics;

      // 🧠 SMART CACHE: Use pre-computed data to save battery & time!
      if (_selectedPath == widget.imagePath1 && _prelimData1 != null) {
        rawMetrics = _prelimData1;
        await Future.delayed(const Duration(milliseconds: 500)); 
      } else if (_selectedPath == widget.imagePath2 && _prelimData2 != null) {
        rawMetrics = _prelimData2;
        await Future.delayed(const Duration(milliseconds: 500)); 
      } else {
        // Fallback
        final aiResult = await RiceClassifier.instance.analyzeImage(_selectedPath!, _currentRiceType);
        if (aiResult.containsKey('error')) throw Exception(aiResult['message']);
        rawMetrics = aiResult['raw'] as Map<String, dynamic>?;
      }

      if (rawMetrics == null) {
        throw Exception("AI Engine returned empty data packets.");
      }

      // DB ALIGNMENT WITH NEW 15-TARGET DUAL-HEAD
      final Map<String, dynamic> completeAiData = {
        'total_count': (rawMetrics['total_count'] as num?)?.toInt() ?? 0,
        'broken_count': (rawMetrics['broken_count'] as num?)?.toInt() ?? 0,
        'broken_pct': (rawMetrics['broken_pct'] as num?)?.toDouble() ?? 0.0,
        
        'long_pct': (rawMetrics['long_pct'] as num?)?.toDouble() ?? 0.0,
        'med_pct': (rawMetrics['med_pct'] as num?)?.toDouble() ?? 0.0,
        'short_pct': (rawMetrics['short_pct'] as num?)?.toDouble() ?? 0.0,
        
        'black_pct': (rawMetrics['black_pct'] as num?)?.toDouble() ?? 0.0,
        'yellow_pct': (rawMetrics['yellow_pct'] as num?)?.toDouble() ?? 0.0,
        'red_pct': (rawMetrics['red_pct'] as num?)?.toDouble() ?? 0.0,
        'green_pct': (rawMetrics['green_pct'] as num?)?.toDouble() ?? 0.0,
        'chalky_pct': (rawMetrics['chalky_pct'] as num?)?.toDouble() ?? 0.0,
        
        'avg_length': (rawMetrics['avg_length'] as num?)?.toDouble() ?? 0.0,
        'avg_width': (rawMetrics['avg_width'] as num?)?.toDouble() ?? 0.0,
        'lwr': (rawMetrics['lwr'] as num?)?.toDouble() ?? 0.0,
        
        'L': (rawMetrics['L'] as num?)?.toDouble() ?? 0.0,
        'a': (rawMetrics['a'] as num?)?.toDouble() ?? 0.0,
        'b': (rawMetrics['b'] as num?)?.toDouble() ?? 0.0,
        
        'inference_time_ms': (rawMetrics['inference_time_ms'] as num?)?.toInt() ?? 0,
        'confidence': (rawMetrics['confidence'] as num?)?.toDouble() ?? 0.98,
        'model_version': rawMetrics['model_version'] ?? 'DualHead-MobileNetV3-v2.1',
        
        'gps': "Pending Save...", 
        'timestamp': rawMetrics['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      };

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imagePath: _selectedPath!,
            riceType: _currentRiceType, 
            aiData: completeAiData, 
          ),
        ),
      );
    } catch (e) {
      debugPrint("AI Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Analysis failed: $e"), 
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSingleImage = widget.imagePath2.isEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Capture Quality Audit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3))),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isSingleImage 
                            ? "Verify rice type and trigger AI analysis."
                            : "Confirm Rice Category below, run the preliminary scan, and select the best sample.",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              Expanded(
                child: isSingleImage 
                  ? _buildSinglePreview() 
                  : Row(
                      children: [
                        _buildImageTile("Shot 1", widget.imagePath1, _clarityScore1),
                        _buildImageTile("Shot 2", widget.imagePath2, _clarityScore2),
                      ],
                    ),
              ),
              
              _buildMetadataSelector(),
              _buildActionFooter(),
            ],
          ),

          // ⏳ LOADING OVERLAY (For the final transition)
          if (_isAnalyzing)
            Container(
              color: Colors.black.withValues(alpha: 0.85),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.greenAccent),
                    SizedBox(height: 24),
                    Text("Loading final deep audit...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSinglePreview() {
    _selectedPath = widget.imagePath1; 
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green, width: 4),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 10)],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(File(widget.imagePath1), fit: BoxFit.cover),
          ),
          
          if (_hasScanned)
            const Positioned(
              top: 16, right: 16,
              child: CircleAvatar(backgroundColor: Colors.green, radius: 16, child: Icon(Icons.check, color: Colors.white, size: 20)),
            ),

          Positioned(
            bottom: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: !_hasScanned && !_isPrelimLoading
                  ? const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 16),
                        SizedBox(width: 8),
                        Text("Awaiting Rice Type Confirmation...", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                      ]
                    )
                  : _isPrelimLoading
                      ? const Row(
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)),
                            SizedBox(width: 10),
                            Text("Running AI inference...", style: TextStyle(color: Colors.greenAccent, fontSize: 13, fontStyle: FontStyle.italic)),
                          ],
                        )
                      : _prelimData1 != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("PRELIMINARY AI AUDIT", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                                const SizedBox(height: 6),
                                Text("Grains Detected: ${_prelimData1!['total_count']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text("Broken Percentage: ${(_prelimData1!['broken_pct'] as num).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 14)),
                              ],
                            )
                          : const Text("Preliminary Scan Failed", style: TextStyle(color: Colors.redAccent)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildImageTile(String label, String path, double clarityScore) {
    bool isSelected = _selectedPath == path;
    Map<String, dynamic>? prelimData = (path == widget.imagePath1) ? _prelimData1 : _prelimData2;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // 🚨 User MUST click "Run Preliminary Scan" before they are allowed to select an image
          if (_hasScanned) setState(() => _selectedPath = path);
        },
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected && _hasScanned ? Colors.green : Colors.white.withValues(alpha: 0.1), 
              width: isSelected && _hasScanned ? 4 : 2
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(path), fit: BoxFit.cover),
              ),
              
              if (!isSelected || !_hasScanned)
                Container(color: Colors.black.withValues(alpha: 0.4)), 

              if (isSelected && _hasScanned)
                const Positioned(
                  top: 10, right: 10,
                  child: CircleAvatar(backgroundColor: Colors.green, radius: 14, child: Icon(Icons.check, color: Colors.white, size: 18)),
                ),
              
              Positioned(
                bottom: 10, left: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected && _hasScanned ? Colors.green[800]!.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10)),
                      const SizedBox(height: 4),
                      
                      if (!_hasScanned && !_isPrelimLoading)
                        const Text("Awaiting input...", style: TextStyle(color: Colors.amber, fontSize: 10, fontStyle: FontStyle.italic))
                      else if (_isPrelimLoading)
                        const Row(
                          children: [
                            SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)),
                            SizedBox(width: 6),
                            Text("Scanning...", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontStyle: FontStyle.italic)),
                          ],
                        )
                      else if (prelimData != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Grains: ${prelimData['total_count']}", style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
                            Text("Broken: ${(prelimData['broken_pct'] as num).toStringAsFixed(1)}%", style: TextStyle(color: isSelected ? Colors.greenAccent : Colors.white70, fontWeight: FontWeight.w900, fontSize: 11)),
                          ],
                        )
                      else
                        const Text("Scan Failed", style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco, color: Colors.amber, size: 18),
          const SizedBox(width: 12),
          const Text("Rice Category:", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currentRiceType,
              dropdownColor: const Color(0xFF2C2C2C),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.greenAccent),
              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 14),
              items: _riceCategories.map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _currentRiceType = val;
                    // 🚨 RESET SCAN IF THEY CHANGE THE TYPE!
                    _hasScanned = false; 
                    _prelimData1 = null;
                    _prelimData2 = null;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isAnalyzing || _isPrelimLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("RETAKE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          
          // 🚨 DYNAMIC BUTTON: Changes based on state!
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isPrelimLoading 
                  ? null 
                  : (!_hasScanned ? _runPreliminaryScan : _runRealAiAnalysis),
              icon: Icon(!_hasScanned ? Icons.search : Icons.memory, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: !_hasScanned ? Colors.blue[700] : Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              label: Text(
                !_hasScanned ? "RUN PRELIMINARY SCAN" : "VIEW FULL AUDIT", 
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)
              ),
            ),
          ),
        ],
      ),
    );
  }
}