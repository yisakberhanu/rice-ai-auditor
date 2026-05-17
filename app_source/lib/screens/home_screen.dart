import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/database_helper.dart';
import 'camera_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // --- Data States ---
  List<Map<String, dynamic>> _allScans = [];
  List<Map<String, dynamic>> _filteredScans = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String _selectedFilter = "All";
  
  String _userName = "Loading...";
  String _userRole = "";
  final String _orgName = "Hawassa Agri-Hub";
  int _totalGrainsProcessed = 0;
  double _avgBrokenPct = 0.0;

  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2)
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseController);
    
    _initConnectivity();
    _loadDashboardData();
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectionStatus(results);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() {
      _isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
    });
  }

  /// 📊 AGGREGATION ENGINE
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final data = await DatabaseHelper.instance.getScans();
    
    int grainCount = 0;
    double brokenSum = 0;
    
    for (var scan in data) {
      grainCount += (scan['total_count'] as num?)?.toInt() ?? 0;
      brokenSum += (scan['broken_pct'] as num?)?.toDouble() ?? 0.0;
    }

    if (mounted) {
      setState(() {
        _userName = prefs.getString('userName') ?? "Rice Specialist";
        _userRole = prefs.getString('userRole') ?? "Commercial Buyer";
        _allScans = data;
        
        // Re-apply current filters to the newly loaded data
        _applyFilters(_searchQuery, _selectedFilter);
        
        _totalGrainsProcessed = grainCount;
        _avgBrokenPct = data.isNotEmpty ? (brokenSum / data.length) : 0.0;
        _isLoading = false;
      });
    }
  }

  void _applyFilters(String query, String category) {
    setState(() {
      _searchQuery = query;
      _selectedFilter = category;
      _filteredScans = _allScans.where((scan) {
        final matchesSearch = scan['timestamp'].toString().contains(query) || 
                              scan['grade'].toString().toLowerCase().contains(query.toLowerCase()) ||
                              scan['id'].toString().contains(query);
        final matchesCat = category == "All" || scan['rice_type'] == category;
        return matchesSearch && matchesCat;
      }).toList();
    });
  }

  Future<void> _handleExport() async {
    if (_allScans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data to export.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }
    
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Preparing CSV Export..."), backgroundColor: Colors.blue),
    );

    try {
      List<List<dynamic>> rows = [
        ["Audit_ID", "Timestamp", "Variety", "Grade", "Broken_%", "Total_Grains", "L*", "a*", "b*", "GPS_Loc"]
      ];

      for (var s in _allScans) {
        rows.add([
          "GH-${s['id']}", 
          s['timestamp'], 
          s['rice_type'], 
          s['grade'], 
          s['broken_pct'], 
          s['total_count'], 
          s['L'], s['a'], s['b'], 
          s['gps_location'] ?? "Not Provided"
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/AfricaRice_Export_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(path)], text: 'AfricaRice Quality Audit Report');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel(); 
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: const Color(0xFF0D47A1),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              stretch: true,
              backgroundColor: const Color(0xFF0D47A1),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeroSection(),
                stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white), 
                  tooltip: "Export CSV",
                  onPressed: _handleExport
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white), 
                  onPressed: _showAppInfo
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: _buildComplianceBanners(),
            ),

            SliverToBoxAdapter(child: _buildInteractiveSearch()),

            // 📜 RECENT ACTIVITY HEADER
            if (!_isLoading && _filteredScans.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("RECENT AUDITS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2, color: Colors.blueGrey)),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/history'),
                        child: const Text("VIEW ALL", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                      ),
                    ],
                  ),
                ),
              ),

            // 📜 LIST: LIMITED TO TOP 6 SCANS
            _isLoading 
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.blue)))
              : _filteredScans.isEmpty 
                ? _buildEmptyState()
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildHistoryCard(_filteredScans[index]),
                        // 🚨 LIMIT LOGIC: Safe check to prevent OutOfBounds Error
                        childCount: _filteredScans.length > 6 ? 6 : _filteredScans.length,
                      ),
                    ),
                  ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => const CameraScreen())
          );
          _loadDashboardData(); 
        }, 
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 6,
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: const Text("START NEW SCAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeroSection() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(_userRole.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.5)),
                    ],
                  ),
                  _buildOfflineHeartbeat(),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _buildStatCard("TOTAL GRAINS", "${(_totalGrainsProcessed / 1000).toStringAsFixed(1)}k", Icons.grain),
                  const SizedBox(width: 12),
                  _buildStatCard("AVG BROKEN", "${_avgBrokenPct.toStringAsFixed(1)}%", Icons.broken_image_outlined),
                ],
              ),
              const SizedBox(height: 24),
              _buildStorageHealthBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineHeartbeat() {
    Color statusColor = _isOffline ? Colors.orangeAccent : Colors.greenAccent;
    String statusText = _isOffline ? "OFFLINE - LOCAL AI" : "ONLINE - SYNC READY";

    return FadeTransition(
      opacity: _pulseAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, color: statusColor, size: 8),
            const SizedBox(width: 6),
            Text(statusText, style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1), 
          borderRadius: BorderRadius.circular(20)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white54, size: 18),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageHealthBar() {
    double progress = (_allScans.length / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("LOCAL DATA CAPACITY", style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
            Text("${_allScans.length} / 100 SCANS", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            color: progress > 0.8 ? Colors.orangeAccent : Colors.greenAccent,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildComplianceBanners() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: const Text("Core Engine: DualHead-MobileNetV3-v2.1 (AfricaRice 3rd Place Model)", style: TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text("Each scan captures 2 images. The clearest image is auto-selected for accurate AI analysis.", style: TextStyle(fontSize: 10, color: Colors.blueGrey))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInteractiveSearch() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: TextField(
              onChanged: (v) => _applyFilters(v, _selectedFilter),
              decoration: const InputDecoration(
                hintText: "Search by Batch ID, Date, or Grade...",
                prefixIcon: Icon(Icons.search_rounded, color: Colors.blueGrey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: ['All', 'Paddy', 'White', 'Brown'].map((cat) {
                bool isSelected = _selectedFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) => _applyFilters(_searchQuery, cat),
                    selectedColor: const Color(0xFF0D47A1),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> scan) {
    String grade = (scan['grade'] ?? "N/A").toString().toUpperCase();
    Color gradeColor = grade.contains("PREMIUM") ? Colors.green : (grade.contains("GRADE 1") ? Colors.blue : Colors.orange);
    
    String totalGrains = (scan['total_count'] ?? 0).toString();
    String brokenPct = ((scan['broken_pct'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);
    String imagePath = scan['image_path'] ?? "";

    String displayTime = "Unknown";
    if (scan['timestamp'] != null) {
      if (scan['timestamp'] is int) {
        DateTime dt = DateTime.fromMillisecondsSinceEpoch(scan['timestamp']);
        displayTime = dt.toLocal().toString().substring(0, 16);
      } else {
        displayTime = scan['timestamp'].toString().split('.').first;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: () {
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                imagePath: imagePath, 
                riceType: scan['rice_type'] ?? "Unknown", 
                aiData: scan 
              )
            )
          ).then((_) => _loadDashboardData()); 
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imagePath.isNotEmpty && File(imagePath).existsSync()
            ? Image.file(File(imagePath), width: 56, height: 56, fit: BoxFit.cover)
            : Container(width: 56, height: 56, color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.grey)),
        ),
        title: Text("BATCH: GH-${(scan['id'] ?? 0).toString().padLeft(3, '0')}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text("${scan['rice_type']} • $displayTime", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniBadge(Icons.grain, totalGrains),
                const SizedBox(width: 8),
                _miniBadge(Icons.analytics, "$brokenPct% Broken"),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: gradeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(grade, style: TextStyle(color: gradeColor, fontWeight: FontWeight.bold, fontSize: 10)),
        ),
      ),
    );
  }

  Widget _miniBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(icon, size: 10, color: Colors.blueGrey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.blueGrey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text("Field Lab Ready", style: TextStyle(color: Colors.blueGrey, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "1. Place rice on a flat BLUE background.\n"
              "2. Ensure bright, natural lighting without heavy shadows.\n"
              "3. Spread grains evenly in a single layer to avoid overlap.", 
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(height: 24),
          const Text("Tap 'START NEW SCAN' to begin.", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // 🚨 ZINDI MANDATORY: APP INFO & LEGAL DISCLAIMER SCREEN
  void _showAppInfo() {
    showAboutDialog(
      context: context,
      applicationName: "AfricaRice Quality Assessment",
      applicationVersion: "Model: DualHead-MobileNetV3-v2.1",
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.spa, color: Colors.white, size: 32),
      ),
      children: [
        const SizedBox(height: 10),
        const Text(
          "Developed for the UNIDO AfricaRice App Builder Challenge.",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 16),
        const Text(
          "This tool is intended for indicative, field-level quality assessment and does not replace laboratory analysis or provide food safety certification.",
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        const Text(
          "Intellectual property for the solution will be co-owned by UNIDO and AfricaRice.",
          style: TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
        const SizedBox(height: 16),
        const Text(
          "Technical Capabilities:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 4),
        const Text(
          "• Offline On-Device Inference via TFLite\n"
          "• Built for Samsung, Tecno & Huawei (Android 9+)\n"
          "• SQLite Local Storage (Max 100 Scans)\n"
          "• Hardware-Assisted Camera Leveling",
          style: TextStyle(fontSize: 11, color: Colors.black54),
        )
      ],
    );
  }
}