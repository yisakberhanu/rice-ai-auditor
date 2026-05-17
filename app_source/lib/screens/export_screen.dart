import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_helper.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool isExportingCSV = false;
  bool isExportingCert = false;

  // MASTER TRACEABILITY CSV (100% COMPLETE DATA)
  Future<void> _exportMasterCSV() async {
    setState(() => isExportingCSV = true);
    HapticFeedback.mediumImpact();

    try {
      final scans = await DatabaseHelper.instance.getScans();

      if (scans.isEmpty) {
        _showSnackBar("No data to export.", isError: true);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      String hubLocation = prefs.getString('hubLocation') ?? "Field";
      String auditorName = prefs.getString('userName') ?? "Auditor";

      List<List<dynamic>> rows = [
        [
          "Audit_ID", "Timestamp", "Auditor", "Location", "Rice_Type", 
          "Grade", "Broken_Count", "Broken_Pct", 
          "Avg_Length_mm", "Avg_Width_mm", "LWR", // Physical Dimensions
          "L*", "a*", "b*", "GPS_Location"
        ]
      ];

      for (var s in scans) {
        String displayTime = "Unknown";
        if (s['timestamp'] != null) {
          DateTime dt = DateTime.fromMillisecondsSinceEpoch(s['timestamp']);
          displayTime = dt.toLocal().toString().substring(0, 16);
        }

        // Handle GPS data cleanly
        String gpsData = (s['gps_location'] != null && s['gps_location'].toString().isNotEmpty) 
            ? s['gps_location'] 
            : "Not Provided";

        rows.add([
          "GH-${s['id']}",
          displayTime,
          auditorName,
          hubLocation,
          s['rice_type'] ?? "Unknown",
          s['grade'] ?? "N/A",
          s['broken_count'] ?? 0,
          s['broken_pct'] ?? 0.0,
          s['avg_length'] ?? 0.0,
          s['avg_width'] ?? 0.0,
          s['lwr'] ?? 0.0,
          s['L'] ?? 0.0,
          s['a'] ?? 0.0,
          s['b'] ?? 0.0,
          gpsData
        ]);
      }

      // Generate and Save File
      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/AfricaRice_MasterAudit_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(path)], text: 'AfricaRice Quality Audit Report');

    } catch (e) {
      debugPrint("CSV Export Error: $e");
      _showSnackBar("Failed to generate CSV.", isError: true);
    } finally {
      if (mounted) setState(() => isExportingCSV = false);
    }
  }

  /// 📄 GENERATE TEXT CERTIFICATE
  Future<void> _shareTextCertificate() async {
    setState(() => isExportingCert = true);
    HapticFeedback.mediumImpact();

    try {
      final scans = await DatabaseHelper.instance.getScans();
      if (scans.isEmpty) {
        _showSnackBar("No recent scan to certify.", isError: true);
        return;
      }

      final latest = scans.first;
      final prefs = await SharedPreferences.getInstance();
      String auditorName = prefs.getString('userName') ?? "Auditor";
      String hubLocation = prefs.getString('hubLocation') ?? "Field";
      
      String displayTime = "Unknown";
      if (latest['timestamp'] != null) {
        DateTime dt = DateTime.fromMillisecondsSinceEpoch(latest['timestamp']);
        displayTime = dt.toLocal().toString().substring(0, 16);
      }

      // Check the AI Trust Status
      String trustStatus = (latest['confidence'] != null && latest['confidence'] > 0.85)
          ? "VERIFIED (High Confidence)" 
          : "MANUAL REVIEW ADVISED";

      String textReport = """
====== UNIDO AFRICARICE CERTIFICATE ======
Batch ID: GH-${latest['id']}
Date: $displayTime
Auditor: $auditorName
Location: $hubLocation

--- COMMERCIAL VERDICT ---
Declared Type: ${latest['rice_type'] ?? 'Unknown'}
Trust Status: $trustStatus
Milling Grade: ${latest['grade']}
Consistency: ${latest['consistency'] ?? 'N/A'}
Shape Class: ${latest['shape'] ?? 'N/A'}

--- DEFECT COMPOSITION ---
Total Grains Analyzed: ${latest['total_count']}
Broken Grains: ${latest['broken_pct']}%
Chalky: ${latest['chalky_pct'] ?? 0}%
Discolored (Black): ${latest['black_pct'] ?? 0}%
Fermented (Yellow): ${latest['yellow_pct'] ?? 0}%
Red Strips (Red): ${latest['red_pct'] ?? 0}%
Immature (Green): ${latest['green_pct'] ?? 0}%

--- PHYSICAL METRICS ---
Avg Dimensions: ${latest['avg_length']}x${latest['avg_width']}mm
LWR (Length-Width Ratio): ${latest['lwr']}
Optical Color (L*a*b*): ${latest['L']}, ${latest['a']}, ${latest['b']}

--- TRACEABILITY LOG ---
Engine: ${latest['model_version'] ?? 'DualHead-MobileNetV3-v2.1'}
Inference Time: ${latest['inference_time_ms'] ?? 0}ms
GPS: ${latest['gps_location'] ?? "Opted Out"}
==========================================
""";

      await Share.share(textReport);

    } catch (e) {
      debugPrint("Cert Error: $e");
      _showSnackBar("Failed to generate Certificate.", isError: true);
    } finally {
      if (mounted) setState(() => isExportingCert = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        title: const Text("Data Export", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Export & Sharing Options",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1)),
            ),
            const SizedBox(height: 8),
            const Text(
              "Generate reports for buyers, mill managers, or regulatory bodies.",
              style: TextStyle(fontSize: 13, color: Colors.blueGrey),
            ),
            const SizedBox(height: 24),

            _buildExportCard(
              title: "Master Audit Log (CSV)",
              sub: "Download the complete local database containing all metrics for every batch.",
              icon: Icons.table_chart_outlined,
              color: const Color(0xFF2E7D32),
              isLoading: isExportingCSV,
              onTap: _exportMasterCSV,
            ),
            
            const SizedBox(height: 16),

            _buildExportCard(
              title: "Single Batch Certificate",
              sub: "Generate a plain-text quality certificate for the most recent scan to share via SMS or WhatsApp.",
              icon: Icons.assignment_turned_in_outlined,
              color: Colors.blueAccent,
              isLoading: isExportingCert,
              onTap: _shareTextCertificate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: isLoading 
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: color, strokeWidth: 2))
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(sub, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}