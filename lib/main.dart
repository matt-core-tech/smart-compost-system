import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Link
  await Supabase.initialize(
    url: 'https://rlhfqpufrqibnmyhmtii.supabase.co', // Paste your Project URL here
    publishableKey: 'YOUR_PUBLISHABLE_API_KEY', // Paste your Publishable Key here
  );

  runApp(const CompostApp());
}

class CompostApp extends StatelessWidget {
  const CompostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Compost',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- AUTH GATE ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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

// --- AUTH SCREEN (LOGIN / REGISTER) ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLogin = true;
  bool isLoading = false;

  void _submit() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful! Please log in.')),
          );
          setState(() => isLogin = true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              isLogin ? 'Welcome Back Farmer' : 'Register New Account',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: Text(isLogin ? 'Login' : 'Sign Up'),
                ),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin ? 'Create an account' : 'Already have an account? Login'),
            )
          ],
        ),
      ),
    );
  }
}

// --- MAIN NAVIGATION SCREEN ---
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

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
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// --- DASHBOARD & LIVE CRITICAL ALGORITHM ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compost Dashboard'), backgroundColor: Colors.green),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Queries the relational SQL table dynamically via realtime subscription
        stream: supabase.from('compost_data').stream(primaryKey: ['id']).order('created_at').limit(1),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Waiting for live telemetry...\nNo rows found in the SQL table.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            );
          }

          // Capture the latest record row pushed to SQL
          final latestData = snapshot.data!.first;
          
          double temp = double.tryParse(latestData['temperature'].toString()) ?? 0.0;
          double moisture = double.tryParse(latestData['moisture'].toString()) ?? 0.0;
          double ph = double.tryParse(latestData['ph'].toString()) ?? 0.0;
          
          bool tSensor = latestData['temp_status'] ?? true;
          bool mSensor = latestData['moisture_status'] ?? true;
          bool pSensor = latestData['ph_status'] ?? true;

          // Core System Algorithm Execution
          bool isReady = (temp >= 55 && temp <= 70) && 
                         (moisture >= 50 && moisture <= 60) && 
                         (ph >= 6.5 && ph <= 7.5);

          double readinessPercentage = isReady ? 100.0 : 45.0; 

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circular Progress Dashboard Display
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Overall Readiness Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: readinessPercentage / 100,
                                strokeWidth: 10,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(isReady ? Colors.green : Colors.orange),
                              ),
                            ),
                            Text('${readinessPercentage.toInt()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isReady ? 'Compost Ready for Use!' : 'Still Composting',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isReady ? Colors.green : Colors.orange),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Live Sensor Readings Grid
                const Text('Live Sensor Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildSensorCard('Temperature', '$temp °C', Icons.thermostat, Colors.red),
                    _buildSensorCard('Moisture', '$moisture %', Icons.water_drop, Colors.blue),
                    _buildSensorCard('pH Level', '$ph', Icons.science, Colors.purple),
                  ],
                ),
                const SizedBox(height: 24),

                // Hardware Fault Identification System
                const Text('Hardware Integrity Checks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String sensorName, bool isConnected) {
    return Card(
      child: ListTile(
        title: Text(sensorName),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isConnected ? Colors.green[100] : Colors.red[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(color: isConnected ? Colors.green[800] : Colors.red[800], fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// --- COMPOST HISTORY ---
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> historyData = [
      {'batch': '#2', 'started': 'Feb 08', 'ready': 'Mar 12', 'days': '27 Days'},
      {'batch': '#1', 'started': 'Jan 10', 'ready': 'Feb 03', 'days': '24 Days'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Compost History'), backgroundColor: Colors.green),
      body: ListView.builder(
        itemCount: historyData.length,
        itemBuilder: (context, index) {
          final item = historyData[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.green, child: Text(item['batch']!)),
              title: Text('Cycle Duration: ${item['days']}'),
              subtitle: Text('Started: ${item['started']} | Ended: ${item['ready']}'),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
          );
        },
      ),
    );
  }
}

// --- ALERTS HISTORY ---
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> alerts = [
      {'title': 'Temperature High', 'time': 'Yesterday', 'desc': 'Temperature peaked above optimum bounds.'},
      {'title': 'Moisture Low', 'time': '2 days ago', 'desc': 'Critical level: Add water immediately.'},
      {'title': 'Compost Ready', 'time': '5 days ago', 'desc': 'Batch #1 conditions met successfully.'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Logs'), backgroundColor: Colors.green),
      body: ListView.builder(
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.amber),
              title: Text(alerts[index]['title']!),
              subtitle: Text(alerts[index]['desc']!),
              trailing: Text(alerts[index]['time']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }
}

// --- USER PROFILE SCREEN ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Farmer Profile'), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 16),
            Center(
              child: Text(user?.email ?? 'farmer@smartcompost.com', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size.fromHeight(50)),
            )
          ],
        ),
      ),
    );
  }
}