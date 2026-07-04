import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Integrated live Project Credentials
  await Supabase.initialize(
    url: 'https://rlhfqpufrqibnmyhmtii.supabase.co', 
    publishableKey: 'sb_publishable_tQ2Q1GV0jRX5dlqi_wWSBg_qP3l8wJR', 
  );

  runApp(const CompostApp());
}

class CompostApp extends StatelessWidget {
  const CompostApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Compost OS',
      theme: ThemeData(
        fontFamily: 'sans-serif',
        primaryColor: const Color(0xFF0F5132), 
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F5132),
          primary: const Color(0xFF0F5132),
          secondary: const Color(0xFF198754), 
          surface: Colors.white,
          background: const Color(0xFFF8F9FA), 
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Color(0xFF495057), fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F5132), width: 2)),
        ),
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- AUTHENTICATION STREAM GATE ---
class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final currentSession = snapshot.data?.session ?? session;
        if (currentSession != null) {
          return const MainMobileTabsNavigator();
        }
        return const AuthScreen();
      },
    );
  }
}

// --- AUTH SCREEN WITH DESTRUCTIVE ZERO-PERSISTENCE ENGINE ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _farmController = TextEditingController();
  
  bool isLogin = true;
  bool isLoading = false;
  String? errorBannerText;

  void _clearInputFields() {
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();
    _farmController.clear();
  }

  void _executeAuthWorkflow() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final location = _farmController.text.trim();

    setState(() {
      errorBannerText = null;
      isLoading = true;
    });

    if (email.isEmpty || password.isEmpty) {
      _clearInputFields();
      setState(() {
        errorBannerText = "Input fields cannot be left blank.";
        isLoading = false;
      });
      return;
    }

    try {
      if (isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
        _clearInputFields(); // Complete data field scrub on success entry
      } else {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name, 'farm_location': location},
        );
        _clearInputFields(); // Pure destructive wipe on register invocation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account configured! Check your inbox for confirmation.')),
          );
          setState(() => isLogin = true);
        }
      }
    } on AuthException catch (e) {
      _clearInputFields(); // Enforce hard security clean out on mistake layout
      setState(() {
        if (e.message.contains('Invalid login credentials') || e.message.contains('invalid_credentials') || e.message.contains('401')) {
          errorBannerText = "Incorrect password entered";
        } else {
          errorBannerText = e.message;
        }
      });
    } catch (e) {
      _clearInputFields();
      setState(() => errorBannerText = "Network terminal connection timeout.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.eco_rounded, size: 64, color: Color(0xFF0F5132)),
                const SizedBox(height: 12),
                const Text(
                  'Smart Compost OS',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F5132)),
                ),
                const SizedBox(height: 24),

                if (errorBannerText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8D7DA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF5C2C7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            errorBannerText!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (!isLogin) ...[
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name (e.g. Mathews)', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 14),
                  TextField(controller: _farmController, decoration: const InputDecoration(labelText: 'Farm Location (e.g. Copperbelt)', prefixIcon: Icon(Icons.location_on))),
                  const SizedBox(height: 14),
                ],
                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email))),
                const SizedBox(height: 14),
                TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
                const SizedBox(height: 24),

                isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _executeAuthWorkflow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5132),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isLogin ? 'Login to Dashboard' : 'Create Account', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(isLogin ? "Need a terminal profile? " : "Already registered? "),
                    GestureDetector(
                      onTap: () {
                        _clearInputFields();
                        setState(() {
                          errorBannerText = null;
                          isLogin = !isLogin;
                        });
                      },
                      child: Text(
                        isLogin ? 'Register' : 'Login',
                        style: const TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 5 BOTTOM NAVIGATION TABS ARCHITECTURE ---
class MainMobileTabsNavigator extends StatefulWidget {
  const MainMobileTabsNavigator({Key? key}) : super(key: key);

  @override
  State<MainMobileTabsNavigator> createState() => _MainMobileTabsNavigatorState();
}

class _MainMobileTabsNavigatorState extends State<MainMobileTabsNavigator> {
  int _activeTabIdx = 0;

  final List<Widget> _appViewports = [
    const HomeDashboardViewport(),
    const LiveMonitoringViewport(),
    const AlertsViewport(),
    const HistoryViewport(),
    const SettingsAndProfileViewport(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _appViewports[_activeTabIdx]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _activeTabIdx,
        onTap: (index) => setState(() => _activeTabIdx = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0F5132),
        unselectedItemColor: const Color(0xFF6C757D),
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart_rounded), label: 'Monitoring'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none_rounded), activeIcon: Icon(Icons.notifications_rounded), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.history_toggle_off_rounded), activeIcon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

// ==========================================
// 1. HOME DASHBOARD VIEWPORT
// ==========================================
class HomeDashboardViewport extends StatelessWidget {
  const HomeDashboardViewport({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final operatorName = user?.userMetadata?['full_name'] ?? 'Mathews';
    double targetProgressValue = 0.85;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Greeting Card Component
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good Morning, $operatorName 👋', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF212529))),
                const Text('Welcome back!', style: TextStyle(color: Color(0xFF6C757D), fontSize: 14)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live Operational Wisdom Slider Card
        const CompostTipsSlider(),
        const SizedBox(height: 16),

        // Core Compost Status Card (Dynamic Auto-Color Engine)
        _buildDynamicStatusCard(targetProgressValue),
        const SizedBox(height: 16),

        // Today's Readings Section Title
        const Text("Today's Readings", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF212529))),
        const SizedBox(height: 10),

        // Three Equal Sensor Summaries Cards
        Row(
          children: [
            _buildSensorQuickBox('🌡 Temperature', '58°C', const Color(0xFF0F5132)),
            const SizedBox(width: 8),
            _buildSensorQuickBox('💧 Moisture', '55%', const Color(0xFF0F5132)),
            const SizedBox(width: 8),
            _buildSensorQuickBox('⚗ pH', '7.1', const Color(0xFF0F5132)),
          ],
        ),
        const SizedBox(height: 20),

        // Structural Progression Track Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE9ECEF))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Batch Progress', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF495057))),
                  Text('${(targetProgressValue * 100).toInt()}% Ready', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F5132), fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: targetProgressValue,
                  minHeight: 12,
                  backgroundColor: const Color(0xFFE9ECEF),
                  color: const Color(0xFF0F5132),
                ),
              ),
              const SizedBox(height: 8),
              const Text('████████░░', style: TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 12, letterSpacing: 2))
            ],
          ),
        ),
        const SizedBox(height: 16),

        // AI Interpretation & Recommendation Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC8E6C9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recommendation', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F5132), fontSize: 14)),
              const SizedBox(height: 6),
              const Text('Keep moisture stable. No turning required today.', style: TextStyle(color: Color(0xFF1B5E20), fontSize: 13)),
              const Divider(height: 16, color: Color(0xFFA5D6A7)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Expected readiness:', style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32))),
                  Text('3 Days Remaining', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F5132))),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Recent Alert Snippet Card Widget
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE9ECEF))),
          child: Row(
            children: const [
              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF198754), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Compost entered thermophilic phase perfectly.', style: TextStyle(fontSize: 13, color: Color(0xFF495057))),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicStatusCard(double progress) {
    Color statusColor = const Color(0xFF0F5132); 
    String statusString = "HEALTHY";
    
    if (progress < 0.40) {
      statusColor = const Color(0xFFDC3545);
      statusString = "NEEDS ATTENTION";
    } else if (progress < 0.80) {
      statusColor = const Color(0xFFFFC107);
      statusString = "ALMOST READY";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Compost is...', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
              const SizedBox(width: 8),
              Text(statusString, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('85% Completed Optimization', style: TextStyle(color: Colors.white, fontSize: 13)),
              Text('Est: 3 Days Remaining', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSensorQuickBox(String label, String value, Color theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE9ECEF))),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D), fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HOMEPAGE DYNAMIC OPERATIONS TIPS HANDBOOK
// ==========================================
class CompostTipsSlider extends StatefulWidget {
  const CompostTipsSlider({Key? key}) : super(key: key);

  @override
  State<CompostTipsSlider> createState() => _CompostTipsSliderState();
}

class _CompostTipsSliderState extends State<CompostTipsSlider> {
  int _tipIdx = 0;
  Timer? _rotationTimer;

  final List<Map<String, String>> _bookOfKnowledge = [
    {'title': 'The Golden C:N Ratio Strategy', 'body': 'Target 30 parts Carbon (Browns: dry straw) to 1 part Nitrogen (Greens: kitchen waste) to minimize volatile structural gas build-up.'},
    {'title': 'Aeration & Turning Rules', 'body': 'Agitate your batch matrices cleanly when temperatures exceed 65°C to preserve balanced microbial lifecycle respiration levels.'},
    {'title': 'The Sponge Compression Standard', 'body': 'Keep moisture parameters close to 55%. Mass compounds must consistently replicate the damp feel of an evenly wrung-out sponge.'},
  ];

  @override
  void initState() {
    super.initState();
    _rotationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) setState(() => _tipIdx = (_tipIdx + 1) % _bookOfKnowledge.length);
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dynamicTip = _bookOfKnowledge[_tipIdx];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E4620), Color(0xFF0F5132)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('💡 Operations Tip Handbook', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              Row(children: _bookOfKnowledge.map((e) => Container(width: 4, height: 4, margin: const EdgeInsets.only(left: 3), decoration: BoxDecoration(shape: BoxShape.circle, color: _bookOfKnowledge.indexOf(e) == _tipIdx ? Colors.white : Colors.white30))).toList())
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey<int>(_tipIdx),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dynamicTip['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(dynamicTip['body']!, style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 12, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 2. LIVE MONITORING VIEWPORT
// ==========================================
class LiveMonitoringViewport extends StatelessWidget {
  const LiveMonitoringViewport({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Monitoring', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0.5),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTelemetryMetricBlock('Temperature Monitoring Node', '58°C', 'Stable Phase Bounds', Colors.red),
          _buildTelemetryMetricBlock('Moisture Saturation Sensor', '54%', 'Optimal Humidity Balance', Colors.blue),
          _buildTelemetryMetricBlock('Acidity / pH Matrix Element', '7.1 pH', 'Neutral Neutral Safe Zone', Colors.purple),
          const SizedBox(height: 12),
          const Text('Hardware Diagnostic Links', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildSensorStatusLine('Temperature Array', 'Connected'),
          _buildSensorStatusLine('Moisture Probe V2', 'Connected'),
          _buildSensorStatusLine('pH Core Electrode', 'Connected'),
        ],
      ),
    );
  }

  Widget _buildTelemetryMetricBlock(String title, String dataStr, String evaluation, Color barAccent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE9ECEF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
              Text(evaluation, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: barAccent)),
            ],
          ),
          const SizedBox(height: 6),
          Text(dataStr, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF212529))),
          const SizedBox(height: 8),
          Container(width: double.infinity, height: 4, decoration: BoxDecoration(color: barAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(2)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: 0.7, child: Container(color: barAccent))),
        ],
      ),
    );
  }

  Widget _buildSensorStatusLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Row(children: [const Icon(Icons.radio_button_checked_rounded, color: Colors.green, size: 14), const SizedBox(width: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
        ],
      ),
    );
  }
}

// ==========================================
// 3. ALERTS VIEWPORT
// ==========================================
class AlertsViewport extends StatelessWidget {
  const AlertsViewport({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert Timeline Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0.5),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTimelineCard('Today', 'Temperature reached absolute thermophilic target parameters.', Colors.green, Icons.check),
          _buildTimelineCard('Yesterday', 'Moisture saturation levels slipped 3% below recommended setpoints.', Colors.amber, Icons.warning_amber_rounded),
          _buildTimelineCard('3 Days Ago', 'Compost organic structural batch #1 successfully harvested.', Colors.blue, Icons.info_outline),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(String window, String desc, Color fill, IconData asset) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE9ECEF))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: fill.withOpacity(0.1), radius: 16, child: Icon(asset, color: fill, size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(window, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Color(0xFF6C757D), fontSize: 12, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 4. HISTORY VIEWPORT
// ==========================================
class HistoryViewport extends StatelessWidget {
  const HistoryViewport({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived Batch Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0.5),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBatchHistoryItem('Batch Record Ledger #01', 'Jan 4', 'Jan 28', '24 Days Processing Time', 'COMPLETED', Colors.green),
          _buildBatchHistoryItem('Batch Record Ledger #02', 'Feb 2', 'Feb 26', '24 Days Processing Time', 'COMPLETED', Colors.green),
        ],
      ),
    );
  }

  Widget _buildBatchHistoryItem(String reference, String start, String end, String duration, String condition, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE9ECEF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(reference, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(condition, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 10))),
            ],
          ),
          const Divider(height: 20, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Started', style: TextStyle(fontSize: 11, color: Colors.grey)), Text(start, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Matured Harvest', style: TextStyle(fontSize: 11, color: Colors.grey)), Text(end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Duration', style: TextStyle(fontSize: 11, color: Colors.grey)), Text(duration, style: const TextStyle(color: Colors.grey, fontSize: 12))]),
            ],
          )
        ],
      ),
    );
  }
}

// ==========================================
// 5. SETTINGS SCREEN (HOUSES PROFILE SEGMENT)
// ==========================================
class SettingsAndProfileViewport extends StatelessWidget {
  const SettingsAndProfileViewport({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final operatorName = user?.userMetadata?['full_name'] ?? 'Mathews';
    final areaLocation = user?.userMetadata?['farm_location'] ?? 'Copperbelt Province';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('System Terminal Configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Profile Card Segment Nested Inside Settings Screen Layout Container
            const Text('Operator Account Profile Info', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE9ECEF))),
              child: Row(
                children: [
                  CircleAvatar(radius: 24, backgroundColor: const Color(0xFF0F5132).withOpacity(0.1), child: const Icon(Icons.person, color: Color(0xFF0F5132), size: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(operatorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                        Text('Role Tier: Professional Farmer', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        Text('Location Scope: $areaLocation', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text('Logged ID: ${user?.email ?? ""}', style: const TextStyle(color: Colors.blue, fontSize: 11)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Hardware Preferences', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _buildActionConfigTile(Icons.phone, 'Contact Operational Line'),
            _buildActionConfigTile(Icons.language, 'Interface Language Select'),
            _buildActionConfigTile(Icons.palette_outlined, 'Application Interface Theme'),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
              label: const Text('Log Out of Terminal', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545), minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionConfigTile(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE9ECEF))),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0F5132), size: 20),
        title: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
        onTap: () {},
      ),
    );
  }
}