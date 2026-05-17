import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form Keys for Validation
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // Data Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _orgController = TextEditingController();
  final TextEditingController _stationController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  String _selectedRole = 'SME Rice Buyer';
  String _selectedRegion = 'Ashanti'; // Ghanaian default

  // 🇬🇭 Ghanaian Localization
  final List<String> _roles = ['SME Rice Buyer', 'Quality Lab Technician', 'Warehouse Manager', 'Cooperative Leader'];
  final List<String> _regions = [
    'Ashanti', 
    'Greater Accra', 
    'Northern', 
    'Volta', 
    'Eastern', 
    'Western', 
    'Bono', 
    'Central'
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _orgController.dispose();
    _stationController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _nextPage(GlobalKey<FormState> key) {
    if (key.currentState!.validate()) {
      HapticFeedback.lightImpact();
      FocusScope.of(context).unfocus(); // Dismiss keyboard
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeSetup() async {
    if (_formKey3.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      
      // 💾 SAVE TO DEVICE STORAGE
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isRegistered', true);
      await prefs.setString('userName', _nameController.text.trim());
      await prefs.setString('userRole', _selectedRole);
      await prefs.setString('orgName', _orgController.text.trim());
      await prefs.setString('stationId', _stationController.text.trim());
      await prefs.setString('region', _selectedRegion);
      await prefs.setString('offlinePin', _pinController.text.trim());

      if (!mounted) return;
      
      // 🚀 PUSH TO DASHBOARD
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Force using the buttons
                onPageChanged: (int page) => setState(() => _currentPage = page),
                children: [
                  _buildStep1Identity(),
                  _buildStep2SupplyChain(),
                  _buildStep3Security(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // UI COMPONENTS
  // ====================================================================

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "System Setup",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1)),
              ),
              Row(children: List.generate(3, (index) => _buildDot(index)))
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Configure your offline auditing profile.",
            style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(left: 6),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2E7D32) : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // --- STEP 1: IDENTITY ---
  Widget _buildStep1Identity() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepIcon(Icons.badge_rounded, "Auditor Identity"),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _nameController,
              label: "Full Legal Name",
              hint: "e.g., Kwame Mensah",
              icon: Icons.person_outline,
              validator: (val) => val!.isEmpty ? "Name is required for trace records." : null,
            ),
            const SizedBox(height: 24),
            _buildDropdown(
              label: "Professional Role",
              value: _selectedRole,
              items: _roles,
              icon: Icons.work_outline,
              onChanged: (val) => setState(() => _selectedRole = val!),
            ),
            const Spacer(),
            _buildNextButton(() => _nextPage(_formKey1)),
          ],
        ),
      ),
    );
  }

  // --- STEP 2: SUPPLY CHAIN ---
  Widget _buildStep2SupplyChain() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepIcon(Icons.domain_rounded, "Supply Chain Node"),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _orgController,
              label: "Organization / Cooperative",
              hint: "e.g., Kumasi Rice Co-op",
              icon: Icons.business,
              validator: (val) => val!.isEmpty ? "Organization is required." : null,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildDropdown(
                    label: "Region",
                    value: _selectedRegion,
                    items: _regions,
                    icon: Icons.map_outlined,
                    onChanged: (val) => setState(() => _selectedRegion = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _buildTextField(
                    controller: _stationController,
                    label: "Station ID",
                    hint: "e.g., GH-04",
                    icon: Icons.tag,
                    validator: (val) => val!.isEmpty ? "Required" : null,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                TextButton(
                  onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
                  child: const Text("BACK", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                _buildNextButton(() => _nextPage(_formKey2)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- STEP 3: SECURITY ---
  Widget _buildStep3Security() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepIcon(Icons.lock_outline_rounded, "Offline Security"),
            const SizedBox(height: 16),
            const Text(
              "Set a 4-digit PIN to secure your field data when operating offline without cell service.",
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, letterSpacing: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                hintText: "••••",
              ),
              validator: (val) => val!.length < 4 ? "Please enter a 4-digit PIN" : null,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "GPS tagging will be enabled for export traceability as per UNIDO guidelines.",
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  )
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                TextButton(
                  onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
                  child: const Text("BACK", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _completeSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("COMPLETE SETUP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // REUSABLE WIDGETS
  // ====================================================================

  Widget _buildStepIcon(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF0D47A1).withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: const Color(0xFF0D47A1), size: 28),
        ),
        const SizedBox(width: 16),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, required IconData icon, required String? Function(String?) validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdown({required String label, required String value, required List<String> items, required IconData icon, required void Function(String?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(prefixIcon: Icon(icon, color: Colors.grey), border: InputBorder.none),
            items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 14)))).toList(),
            onChanged: onChanged,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blue),
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton(VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D47A1),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("NEXT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward, color: Colors.white, size: 18),
        ],
      ),
    );
  }
}