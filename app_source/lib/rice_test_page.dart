import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// ✅ Fixed Import: Points to your actual folder structure
import 'services/classifier.dart'; 

class RiceTestPage extends StatefulWidget {
  const RiceTestPage({super.key});

  @override
  State<RiceTestPage> createState() => _RiceTestPageState();
}

class _RiceTestPageState extends State<RiceTestPage> {
  bool _isAnalyzing = false;
  Map<String, dynamic>? _results;
  String _statusMessage = "Ready to test model logic.";

  /// Bridge: Copies the asset image to a local file so the AI can read it on the emulator
  Future<String> _prepareTestImage() async {
    try {
      final byteData = await rootBundle.load('assets/test_rice.jpg');
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/emulator_test_image.jpg');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (e) {
      throw Exception("Failed to load 'assets/test_rice.jpg'. Did you add it to pubspec.yaml?");
    }
  }

  Future<void> _runInference() async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage = "Preparing image...";
      _results = null;
    });

    try {
      // 1. Get the path from assets
      String path = await _prepareTestImage();
      
      setState(() => _statusMessage = "Running AI (48 Tiles)...");

      // 2. Run the actual classifier (RiceClassifier)
      final result = await RiceClassifier.instance.analyzeImage(path, "Paddy");

      setState(() {
        _results = result;
        _statusMessage = "Analysis Complete ✅";
      });
    } catch (e) {
      // ✅ Error Handling: If it fails, show the error in the UI
      setState(() => _statusMessage = "Error: $e");
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Inference Failed"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Emulator AI Lab"),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- IMAGE PREVIEW ---
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                height: 220,
                width: double.infinity,
                color: Colors.grey[300],
                child: Image.asset(
                  "assets/test_rice.jpg", 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => 
                    const Center(child: Text("test_rice.jpg not found in assets")),
                ),
              ),
            ),
            
            const SizedBox(height: 25),

            // --- STATUS ---
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                color: _statusMessage.contains("Error") ? Colors.red : Colors.green[900]
              ),
            ),
            
            const SizedBox(height: 20),

            // --- RUN BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _runInference,
                icon: _isAnalyzing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.psychology, color: Colors.white),
                label: Text(_isAnalyzing ? "Processing Tiles..." : "START AI TEST", 
                  style: const TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- RESULTS CARD ---
            if (_results != null) ...[
              _buildResultItem("Quality Grade", _results!['grade'], Icons.star, Colors.orange),
              _buildResultItem("Total Grains", _results!['raw']['total_count'].toStringAsFixed(0), Icons.grain, Colors.blue),
              _buildResultItem("Broken %", "${_results!['raw']['broken_pct'].toStringAsFixed(1)}%", Icons.broken_image_outlined, Colors.red),
              _buildResultItem("Avg Length", "${_results!['raw']['avg_length'].toStringAsFixed(2)}mm", Icons.straighten, Colors.purple),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(String label, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}