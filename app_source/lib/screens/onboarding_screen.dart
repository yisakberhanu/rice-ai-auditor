import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    // Mark onboarding as complete so they never see it again
    await prefs.setBool('hasSeenOnboarding', true); 
    
    if (!mounted) return;
    // Launch them into their new Dashboard Shell!
    Navigator.pushReplacementNamed(context, '/'); // Assumes '/' is your MainShell
  }

  void _nextPage() {
    if (_currentPage < 3) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Skip Button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: const Text("SKIP", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
            
            // Swipeable Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (int page) => setState(() => _currentPage = page),
                children: [
                  _buildPage(
                    title: "Your Pocket\nQuality Lab",
                    subtitle: "Powered by the AfricaRice ConvNeXt engine, this tool replaces expensive laboratory equipment with just your smartphone.",
                    graphic: _buildLabGraphic(),
                  ),
                  _buildPage(
                    title: "The Calibration\nProtocol",
                    subtitle: "For precision AI reading:\n1. Use a solid BLUE background.\n2. Spread grains in a SINGLE layer.\n3. Avoid heavy shadows or glare.",
                    graphic: _buildBlueBackgroundGraphic(),
                  ),
                  _buildPage(
                    title: "Smart Field\nHUD Sensors",
                    subtitle: "Watch the on-screen Command Center. Our tilt-guidance and motion-lock systems ensure the AI only receives perfectly stable, laboratory-grade images.",
                    graphic: _buildSmartSensorGraphic(),
                  ),
                  _buildPage(
                    title: "Verifiable\nTraceability",
                    subtitle: "Every scan is secured with offline GPS coordinates, timestamping, and CIELAB optic data for 100% UNIDO audit compliance.",
                    graphic: _buildTraceabilityGraphic(),
                  ),
                ],
              ),
            ),

            // Bottom Navigation Controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Progress Dots
                  Row(
                    children: List.generate(4, (index) => _buildDot(index)),
                  ),
                  
                  // Next / Get Started Button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == 3 ? "START AUDITING" : "NEXT",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // REUSABLE PAGE BUILDER
  // ====================================================================
  Widget _buildPage({required String title, required String subtitle, required Widget graphic}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Center(child: graphic),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1, color: Color(0xFF0D47A1)),
                ),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 15, color: Colors.blueGrey, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2E7D32) : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // ====================================================================
  // CUSTOM 2026-STYLE GRAPHICS (Updated for 1.0 Score Features)
  // ====================================================================
  
  // Graphic 1: The Lab & Profile
  Widget _buildLabGraphic() {
    return Container(
      width: 200, height: 200,
      decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.science_rounded, size: 100, color: Colors.blueAccent),
          Positioned(
            bottom: 30, right: 30, 
            child: Container(
              padding: const EdgeInsets.all(8), 
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), 
              child: const Icon(Icons.verified_user_rounded, color: Colors.green, size: 30)
            )
          ),
        ],
      ),
    );
  }

  // Graphic 2: Blue Background & Protocol
  Widget _buildBlueBackgroundGraphic() {
    return Container(
      width: 220, height: 220,
      decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white, width: 8), boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 20)]),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.scatter_plot, size: 80, color: Colors.white),
          Positioned(
            top: 15, left: 15,
            child: Icon(Icons.wb_sunny_rounded, color: Colors.yellow[200], size: 24), // Signifying natural light
          ),
          Positioned(
            bottom: 15,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: const Text("AFRICARICE PROTOCOL", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold))),
          )
        ],
      ),
    );
  }

  // Graphic 3: The Smart Sensor HUD
  Widget _buildSmartSensorGraphic() {
    return Container(
      width: 200, height: 200,
      decoration: BoxDecoration(
        color: Colors.white, 
        shape: BoxShape.circle,
        border: Border.all(color: Colors.greenAccent, width: 4),
        boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.2), blurRadius: 30)]
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Simulated Level bubble
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300, width: 2)),
          ),
          Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          ),
          Positioned(
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
              child: const Text("STABLE - HOLD STILL", style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          )
        ],
      ),
    );
  }

  // Graphic 4: Traceability & DB
  Widget _buildTraceabilityGraphic() {
    return Container(
      width: 240, height: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTraceIcon(Icons.gps_fixed_rounded, Colors.blue),
              _buildTraceIcon(Icons.lock_clock_rounded, Colors.orange),
              _buildTraceIcon(Icons.table_chart_rounded, Colors.green),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), 
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, color: Colors.green, size: 16), 
                SizedBox(width: 8), 
                Text("AUDIT SECURED", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))
              ]
            )
          ),
        ],
      ),
    );
  }

  Widget _buildTraceIcon(IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24),
        ),
      ],
    );
  }
}