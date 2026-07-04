import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Link
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
      title: 'Smart Compost',
      theme: ThemeData(
        fontFamily: 'sans-serif',
        primaryColor: const Color(0xFF0F5132), // Deep Emerald Green
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F5132),
          primary: const Color(0xFF0F5132),
          secondary: const Color(0xFF198754), 
          surface: Colors.white,
          background: const Color(0xFFF8F9FA), 
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F5132),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Color(0xFF495057)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0F5132), width: 2),
          ),
        ),
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- AUTH GATE ---
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
          return const MainNavigationScreen();
        }
        return const AuthScreen();
      },
    );
  }
}

// --- UPGRADED AUTH SCREEN (WITH NAME & FARM LOCATION FIELDS) ---
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

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _nameController.text.trim();
    final farmLocation = _farmController.text.trim();

    // Field validations
    if (email.isEmpty || password.isEmpty) {
      _showSnackbar('Please fill out Email and Password.');
      return;
    }

    if (!isLogin && (fullName.isEmpty || farmLocation.isEmpty)) {
      _showSnackbar('Please tell us your name and farm location to register.');
      return;
    }

    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        // Core Feature: Passing custom metadata details directly into Supabase User Profile
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': fullName,
            'farm_location': farmLocation,
          },
        );
        if (mounted) {
          _showSnackbar('Account created successfully! Please check your email to verify.');
          setState(() => isLogin = true); // Switch back to login page
        }
      }
    } catch (e) {
      if (mounted) _showSnackbar('Authentication Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnackbar('Please enter your email address first.');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
      if (mounted) _showSnackbar('Password reset link sent to your email!');
    } catch (e) {
      if (mounted) _showSnackbar(e.toString());
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.eco_rounded, size: 72, color: Color(0xFF0F5132)),
                const SizedBox(height: 16),
                Text(
                  isLogin ? 'Welcome Back!' : 'Join Smart Compost Today',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF212529)),
                ),
                const SizedBox(height: 8),
                Text(
                  isLogin 
                      ? 'Monitor your organic cycles with real-time data accuracy.' 
                      : 'Sign up for better compost tracking and efficient delivery analytics.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6C757D)),
                ),
                const SizedBox(height: 32),
                
                // Form Fields (Dynamic rendering based on signup state)
                if (!isLogin) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _farmController,
                    decoration: const InputDecoration(labelText: 'Farm / Organization Location', prefixIcon: Icon(Icons.location_on_outlined)),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                ),
                
                if (isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF198754), fontWeight: FontWeight.bold)),
                    ),
                  ),
                const SizedBox(height: 16),
                
                isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                      child: Text(isLogin ? 'Login to Dashboard' : 'Create Account', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                const SizedBox(height: 24),
                
                Row(
                  children: const [
                    Expanded(child: Divider(color: Color(0xFFDEE2E6), thickness: 1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: Color(0xFFADB5BD), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: Color(0xFFDEE2E6), thickness: 1)),
                  ],
                ),
                const SizedBox(height: 24),
                
                OutlinedButton.icon(
                  onPressed: () {
                    _showSnackbar('Google OAuth requires production domains. Use Email for MVP demo.');
                  },
                  icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
                  label: const Text('Continue with Google', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: Color(0xFFDEE2E6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLogin ? "Don't have an account? " : "Already have an account? ",
                      style: const TextStyle(color: Color(0xFF495057)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin ? 'Sign up' : 'Login',
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

// --- MAIN NAVIGATION SCREEN ---
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const DashboardScreen(),
    const HistoryScreen(),
    const AlertsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF0F5132),
        unselectedItemColor: const Color(0xFFADB5BD),
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.history_toggle_off_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active_rounded), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// --- DASHBOARD SCREEN ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    // Dynamic metadata reading to welcome user by name
    final userMetadata = supabase.auth.currentUser?.userMetadata;
    final farmerName = userMetadata?['full_name'] ?? 'Farmer';

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $farmerName!', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F5132),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase.from('compost_data').stream(primaryKey: ['id']).order('created_at').limit(1),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.sensors_off_rounded, size: 64, color: Color(0xFFCED4DA)),
                    SizedBox(height: 16),
                    Text(
                      'Waiting for live telemetry...\nNo rows found in your Supabase SQL table.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6C757D), fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          final latestData = snapshot.data!.first;
          double temp = double.tryParse(latestData['temperature'].toString()) ?? 0.0;
          double moisture = double.tryParse(latestData['moisture'].toString()) ?? 0.0;
          double ph = double.tryParse(latestData['ph'].toString()) ?? 0.0;
          
          bool tSensor = latestData['temp_status'] ?? true;
          bool mSensor = latestData['moisture_status'] ?? true;
          bool pSensor = latestData['ph_status'] ?? true;

          bool isReady = (temp >= 55 && temp <= 70) && (moisture >= 50 && moisture <= 60) && (ph >= 6.5 && ph <= 7.5);
          double readinessPercentage = isReady ? 100.0 : 45.0; 

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE9ECEF))),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Text('Overall Readiness Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF495057))),
                        const SizedBox(height: 20),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 130,
                              height: 130,
                              child: CircularProgressIndicator(
                                value: readinessPercentage / 100,
                                strokeWidth: 12,
                                backgroundColor: const Color(0xFFE9ECEF),
                                valueColor: AlwaysStoppedAnimation<Color>(isReady ? const Color(0xFF198754) : const Color(0xFFFD7E14)),
                              ),
                            ),
                            Text('${readinessPercentage.toInt()}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF212529))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isReady ? const Color(0xFFD1E7DD) : const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            isReady ? 'Compost Ready for Use!' : 'Status: Still Composting',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isReady ? const Color(0xFF0F5132) : const Color(0xFF664D03)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Live Sensor Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF212529))),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildSensorCard('Temperature', '$temp °C', Icons.thermostat_rounded, const Color(0xFFDC3545)),
                    _buildSensorCard('Moisture', '$moisture %', Icons.water_drop_rounded, const Color(0xFF0D6EFD)),
                    _buildSensorCard('pH Level', '$ph', Icons.science_rounded, const Color(0xFF6F42C1)),
                  ],
                ),
                const SizedBox(height: 28),
                const Text('Hardware Integrity Checks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF212529))),
                const SizedBox(height: 12),
                _buildStatusRow('DS18B20 Temp Probe', tSensor),
                _buildStatusRow('Capacitive Moisture Sensor', mSensor),
                _buildStatusRow('Analog pH Module', pSensor),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE9ECEF))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Color(0xFF6C757D), fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF212529))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String sensorName, bool isConnected) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE9ECEF))),
      child: ListTile(
        title: Text(sensorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF495057))),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isConnected ? const Color(0xFFD1E7DD) : const Color(0xFFF8D7DA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(color: isConnected ? const Color(0xFF0F5132) : const Color(0xFF842029), fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

// --- COMPOST HISTORY ---
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> historyData = [
      {'batch': '#2', 'started': 'Feb 08', 'ready': 'Mar 12', 'days': '27 Days'},
      {'batch': '#1', 'started': 'Jan 10', 'ready': 'Feb 03', 'days': '24 Days'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Compost History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF0F5132), elevation: 0),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: historyData.length,
        itemBuilder: (context, index) {
          final item = historyData[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE9ECEF))),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: const Color(0xFFD1E7DD), child: Text(item['batch']!, style: const TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold))),
              title: Text('Cycle Duration: ${item['days']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Started: ${item['started']} | Ended: ${item['ready']}', style: const TextStyle(color: Color(0xFF6C757D))),
              trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF198754)),
            ),
          );
        },
      ),
    );
  }
}

// --- ALERTS HISTORY ---
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> alerts = [
      {'title': 'Temperature High', 'time': 'Yesterday', 'desc': 'Temperature peaked above optimum bounds.'},
      {'title': 'Moisture Low', 'time': '2 days ago', 'desc': 'Critical level: Add water immediately.'},
      {'title': 'Compost Ready', 'time': '5 days ago', 'desc': 'Batch #1 conditions met successfully.'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Logs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF0F5132), elevation: 0),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE9ECEF))),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3CD), child: Icon(Icons.warning_amber_rounded, color: Color(0xFF664D03))),
              title: Text(alerts[index]['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(alerts[index]['desc']!, style: const TextStyle(color: Color(0xFF6C757D))),
              trailing: Text(alerts[index]['time']!, style: const TextStyle(color: Color(0xFFADB5BD), fontSize: 11)),
            ),
          );
        },
      ),
    );
  }
}

// --- USER PROFILE SCREEN ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] ?? 'Active Farmer';
    final location = user?.userMetadata?['farm_location'] ?? 'Not Specified';

    return Scaffold(
      appBar: AppBar(title: const Text('Farmer Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF0F5132), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 46, backgroundColor: Color(0xFFE9ECEF), child: Icon(Icons.person_rounded, size: 48, color: Color(0xFF6C757D))),
            const SizedBox(height: 20),
            Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF212529))),
            const SizedBox(height: 4),
            Text('📍 $location', style: const TextStyle(fontSize: 14, color: Color(0xFF6C757D))),
            const SizedBox(height: 12),
            Text(user?.email ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFFADB5BD))),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out of System', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545), minimumSize: const Size.fromHeight(54)),
            )
          ],
        ),
      ),
    );
  }
}