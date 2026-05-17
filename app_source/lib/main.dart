import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // 🌍 NEW: Added for GPS Warm-up

// Import all your screens
import 'screens/main_shell.dart'; 
import 'screens/camera_screen.dart';
import 'screens/signup_screen.dart'; 
import 'screens/onboarding_screen.dart'; 

void main() async {
  // Ensure Flutter engine is fully initialized before setting orientations
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock the app to Portrait mode (prevents camera UI bugs in the field)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set the status bar color to transparent for a modern look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AfricaRiceApp());
}

class AfricaRiceApp extends StatelessWidget {
  const AfricaRiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AfricaRice AI Auditor',
      debugShowCheckedModeBanner: false, // 🚨 Hides the debug banner for a professional video!
      theme: ThemeData(
        primaryColor: const Color(0xFF0D47A1), // Corporate Blue
        scaffoldBackgroundColor: const Color(0xFFF8FAFD),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          secondary: const Color(0xFF2E7D32), // Growth Green
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        useMaterial3: true,
      ),
      
      // Set up the routing map
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const MainShell(), 
        '/camera': (context) => const CameraScreen(),
      },
    );
  }
}

/// 🚀 THE SPLASH SCREEN: First impressions matter for the Zindi Judges
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup a smooth fade-in animation
    _animController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();

    // 🌍 NEW: Warm-up the GPS permissions while the splash screen plays
    _checkInitialPermissions();

    // 🚨 SMART ROUTING: Check user status while the splash screen plays
    _routeUser();
  }

  /// 🌍 UNIVERSAL COMPLIANCE: Request GPS safely for all versions (Android 9 to 16)
  Future<void> _checkInitialPermissions() async {
    try {
      // 1. Check if GPS hardware is actually ON
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("🛰️ GPS Hardware is disabled. Asking user to turn it on...");
        // This will open the phone's settings page so the user can turn on GPS
        await Geolocator.openLocationSettings();
        return;
      }

      // 2. Check current status
      LocationPermission permission = await Geolocator.checkPermission();

      // 3. If Denied, ask for it
      if (permission == LocationPermission.denied) {
        // 💡 Android 13 TRICK: Small delay helps the OS 'ready' the dialog before firing
        await Future.delayed(const Duration(milliseconds: 500));
        permission = await Geolocator.requestPermission();
      }

      // 4. If Permanently Denied (The reason your Android 13 isn't showing the popup)
      if (permission == LocationPermission.deniedForever) {
        debugPrint("🚫 GPS is Denied Forever. Popup will NEVER show again unless reset.");
        // Optional: Open App Settings so they can manually allow it
        // await Geolocator.openAppSettings(); 
        return;
      }

      // 5. If successful, warm up the sensor
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        debugPrint("✅ GPS Permissions Active for Android 9-16.");
        
        // This silently pings the GPS chip so it connects to satellites faster 
        try {
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 2),
          );
        } catch(e) {
          debugPrint("Warmup skip: $e");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Permission system error: $e");
    }
  }

  Future<void> _routeUser() async {
    // Wait for the 3-second splash animation to finish gracefully
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    
    // 🚨 CHECK IF THEY ALREADY ACCEPTED IT ON A PREVIOUS LAUNCH
    bool hasAcceptedDisclaimer = prefs.getBool('hasAcceptedDisclaimer') ?? false;

    if (!hasAcceptedDisclaimer) {
      // 🚨 ONLY SHOW DIALOG IF THEY HAVEN'T ACCEPTED IT YET
      bool? accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // Forces the user to explicitly tap the ACCEPT button
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.gavel_rounded, color: Color(0xFF0D47A1)),
                SizedBox(width: 10),
                Text("Legal Disclaimer", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
            content: const Text(
              "This tool is intended for indicative, field-level quality assessment and does not replace laboratory analysis or provide food safety certification.\n\n"
              "Intellectual property for this solution will be co-owned by UNIDO and AfricaRice.",
              style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
            ),
            actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1), 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(true), 
                child: const Text("ACCEPT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              )
            ],
          );
        }
      );

      // If they tap accept, save it permanently to the device memory
      if (accepted == true) {
        await prefs.setBool('hasAcceptedDisclaimer', true);
      } else {
        return; // Halt app if they don't accept
      }
    }

    // --- CONTINUE TO APP ROUTING ---
    // Check if they have finished the onboarding tutorial
    bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!mounted) return;

    if (hasSeenOnboarding) {
      // Returning user -> Straight to Dashboard (MainShell)
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // New user -> Send to Profile Setup / Sign Up
      Navigator.pushReplacementNamed(context, '/signup');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)], // UNIDO Blue
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🌾 Brand Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2), 
                      blurRadius: 20, 
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: const Icon(
                  Icons.spa_rounded, // Represents the rice/agriculture aspect
                  size: 80,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 30),
              
              // 🏢 Title & Organization
              const Text(
                "AFRICARICE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "QUALITY ASSESSMENT AI",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 60),
              
              // ⚙️ Loading Indicator & Traceability Footer
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                "Initializing Offline Engine...",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
      
      // Bottom branding required for professional submissions
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1976D2),
        elevation: 0,
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              // 🚨 Updated to show the correct new AI engine!
              "POWERED BY DUALHEAD-MOBILENETV3  •  UNIDO CHALLENGE 2026",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}