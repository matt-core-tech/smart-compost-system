import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';

// Supabase Credentials
const String supabaseUrl = 'https://rlhfqpufrqibnmyhmtii.supabase.co';
const String supabaseAnonKey = 'sb_publishable_tQ2Q1GV0jRX5dlqi_wWSBg_qP3l8wJR';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const CompostWiseApp());
}

// ==========================================
// 1. DATA MODELS & RANDOM FOREST PREDICTOR
// ==========================================
enum StatusLevel { onTrack, warning, critical, completed }

enum CompostStage { mesophilic, thermophilic, cooling, maturation }

class DayReading {
  final int day;
  final String dateStr;
  final double temp;
  final double moisture;
  final double ph;

  DayReading({
    required this.day,
    required this.dateStr,
    required this.temp,
    required this.moisture,
    required this.ph,
  });
}

class CompostAlert {
  final String id;
  final String title;
  final String time;
  final String body;
  final Color color;

  CompostAlert({
    required this.id,
    required this.title,
    required this.time,
    required this.body,
    required this.color,
  });
}

class CompostPile {
  final String id;
  final String name;
  final String category;
  StatusLevel status;
  double temp;
  double moisture;
  double ph;
  List<DayReading> history;
  bool isArchived;
  DateTime startDate;
  int targetTotalDays;

  CompostPile({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.temp,
    required this.moisture,
    required this.ph,
    required this.history,
    this.isArchived = false,
    required this.startDate,
    this.targetTotalDays = 30,
  });

  // Dynamic Overall Progress Percentage
  double get readinessPercent {
    if (isArchived) return 100.0;

    // Evaluate parameter ideal ranges
    double tempScore = (temp >= 50 && temp <= 65) ? 1.0 : (temp / 60.0).clamp(0.1, 1.0);
    double moistureScore = (moisture >= 45 && moisture <= 65) ? 1.0 : (moisture / 55.0).clamp(0.1, 1.0);
    double phScore = (ph >= 6.5 && ph <= 8.0) ? 1.0 : (ph / 7.0).clamp(0.1, 1.0);

    // Calculate progression weighted against elapsed time and optimal conditions
    int daysActive = DateTime.now().difference(startDate).inDays.clamp(1, targetTotalDays);
    double timeProgress = (daysActive / targetTotalDays).clamp(0.0, 1.0);
    double healthFactor = (tempScore * 0.40 + moistureScore * 0.35 + phScore * 0.25);

    double overall = (timeProgress * 0.60 + healthFactor * 0.40) * 100;
    return overall.clamp(0.0, 100.0);
  }

  // Active Stage Detection
  CompostStage get currentStage {
    double progress = readinessPercent;
    if (progress < 25) return CompostStage.mesophilic;
    if (progress < 65) return CompostStage.thermophilic;
    if (progress < 90) return CompostStage.cooling;
    return CompostStage.maturation;
  }

  // Real-time Random Forest Decision Ensemble Simulator
  int get predictedDaysRemaining {
    if (isArchived || readinessPercent >= 99.5) return 0;

    // Tree 1: Thermal Activity Model
    double tree1Days = 0;
    if (temp < 40) {
      tree1Days += 18;
    } else if (temp >= 40 && temp <= 65) {
      tree1Days += 8;
    } else {
      tree1Days += 12;
    }

    // Tree 2: Moisture & pH Balance Model
    double tree2Days = 0;
    if (moisture < 40) {
      tree2Days += 15;
    } else if (moisture > 70) {
      tree2Days += 12;
    } else {
      tree2Days += 5;
    }

    if (ph < 6.0) {
      tree2Days += 10;
    } else if (ph >= 6.5 && ph <= 8.0) {
      tree2Days += 2;
    }

    // Tree 3: Substrate Decay Dynamics
    double tree3Days = targetTotalDays * (1.0 - (readinessPercent / 100.0));
    if (category.toLowerCase().contains('wood') || category.toLowerCase().contains('sawdust')) {
      tree3Days *= 1.25;
    } else if (category.toLowerCase().contains('kitchen') || category.toLowerCase().contains('grounds')) {
      tree3Days *= 0.85;
    }

    // Ensemble Average
    double forestPrediction = (tree1Days * 0.30) + (tree2Days * 0.30) + (tree3Days * 0.40);
    _updateStatus();

    return forestPrediction.round().clamp(0, 90);
  }

  void _updateStatus() {
    if (isArchived || readinessPercent >= 99.5) {
      status = StatusLevel.completed;
      return;
    }
    if (temp < 40 || temp > 70 || moisture > 70 || ph < 5.8) {
      status = StatusLevel.critical;
    } else if (temp < 50 || moisture < 45 || moisture > 65 || ph < 6.5) {
      status = StatusLevel.warning;
    } else {
      status = StatusLevel.onTrack;
    }
  }
}

// Styling & Helper Functions
Color getHeaderColor(StatusLevel status) {
  switch (status) {
    case StatusLevel.onTrack:
      return const Color(0xFF1B3B2B);
    case StatusLevel.warning:
      return const Color(0xFF9E4B18);
    case StatusLevel.critical:
      return const Color(0xFF7A1C1C);
    case StatusLevel.completed:
      return const Color(0xFF2F855A);
  }
}

Color getMetricColor(StatusLevel status) {
  switch (status) {
    case StatusLevel.onTrack:
      return const Color(0xFF38A169);
    case StatusLevel.warning:
      return const Color(0xFFDD6B20);
    case StatusLevel.critical:
      return const Color(0xFFE53E3E);
    case StatusLevel.completed:
      return const Color(0xFF2F855A);
  }
}

Color getBadgeBgColor(StatusLevel status) {
  switch (status) {
    case StatusLevel.onTrack:
      return const Color(0xFF68D391);
    case StatusLevel.warning:
      return const Color(0xFFFEEBC8);
    case StatusLevel.critical:
      return const Color(0xFFFED7D7);
    case StatusLevel.completed:
      return const Color(0xFFC6F6D5);
  }
}

Color getBadgeTextColor(StatusLevel status) {
  switch (status) {
    case StatusLevel.onTrack:
      return const Color(0xFF1A202C);
    case StatusLevel.warning:
      return const Color(0xFF742A2A);
    case StatusLevel.critical:
      return const Color(0xFF742A2A);
    case StatusLevel.completed:
      return const Color(0xFF22543D);
  }
}

String getStatusLabel(StatusLevel status) {
  switch (status) {
    case StatusLevel.onTrack:
      return 'On track';
    case StatusLevel.warning:
      return 'Warning';
    case StatusLevel.critical:
      return 'Critical';
    case StatusLevel.completed:
      return 'Ready';
  }
}

String getRealtimeGreeting(String userName) {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning, $userName';
  if (hour < 17) return 'Good afternoon, $userName';
  return 'Good evening, $userName';
}

// ==========================================
// 2. ROOT APP WIDGET
// ==========================================
class CompostWiseApp extends StatelessWidget {
  const CompostWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    bool isLoggedIn = false;
    try {
      isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    } catch (_) {}

    return MaterialApp(
      title: 'CompostWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1B3B2B),
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B3B2B),
          primary: const Color(0xFF1B3B2B),
        ),
      ),
      home: isLoggedIn ? const MainNavigation() : const OnboardingScreen(),
    );
  }
}

// ==========================================
// 3. ONBOARDING & LOGIN SCREENS
// ==========================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, String>> _pages = const [
    {
      'title': 'Welcome to CompostWise.',
      'subtitle': 'Automated monitoring and smart predictions for perfect compost.',
    },
    {
      'title': 'Real-time Telemetry Alerts',
      'subtitle': 'Instant notifications when temperature or pH level drifts.',
    },
    {
      'title': 'Export Reports',
      'subtitle': 'Generate downloadable PDF and email summaries of compost readiness.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentPage < _pages.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            SizedBox(
              height: 280,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.eco_outlined, size: 48, color: Color(0xFF1B3B2B)),
                            const SizedBox(height: 16),
                            Text(
                              _pages[index]['title']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _pages[index]['subtitle']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
                  height: 8,
                  width: _currentPage == index ? 20 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? const Color(0xFF1B3B2B) : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B3B2B),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                },
                child: const Text('Get Started', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'mathews@northrise.ac.zm');
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (mounted && response.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully logged in!'), backgroundColor: Color(0xFF1B3B2B)),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        String msg = e.message;
        if (e.message.toLowerCase().contains('invalid login credentials')) {
          msg = 'Incorrect email or password. Please check your details and try again.';
        } else if (e.message.toLowerCase().contains('email not confirmed')) {
          msg = 'Email address has not been confirmed. Please check your email inbox.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.eco, size: 56, color: Color(0xFF1B3B2B)),
              const SizedBox(height: 16),
              const Text(
                'Welcome Back',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B)),
              ),
              const SizedBox(height: 6),
              Text(
                'Log in to monitor your compost piles',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
              const SizedBox(height: 32),
              _buildInputField(label: 'Email address', hint: 'mathews@northrise.ac.zm', controller: _emailController),
              const SizedBox(height: 16),
              _buildInputField(label: 'Password', hint: '••••••••', isPassword: true, controller: _passwordController),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B3B2B),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Log In', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('New here? ', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: const Text(
                      'Create an account',
                      style: TextStyle(
                        color: Color(0xFF1B3B2B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({required String label, required String hint, required TextEditingController controller, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1B3B2B))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ],
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      if (mounted) {
        if (response.user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created! Logging in...'), backgroundColor: Color(0xFF1B3B2B)),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created! Please check your email if confirmation is required.')),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String msg = e.message;
        if (e.message.toLowerCase().contains('already registered') || e.message.toLowerCase().contains('user_already_exists')) {
          msg = 'An account with this email address already exists. Please log in instead.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign up failed: ${e.toString()}'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.eco, size: 56, color: Color(0xFF1B3B2B)),
              const SizedBox(height: 16),
              const Text(
                'Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B)),
              ),
              const SizedBox(height: 6),
              Text(
                'Sign up to get started with CompostWise',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
              const SizedBox(height: 28),
              _buildInputField(label: 'Full Name', hint: 'Mathews Chanda', controller: _nameController),
              const SizedBox(height: 16),
              _buildInputField(label: 'Email address', hint: 'mathews@northrise.ac.zm', controller: _emailController),
              const SizedBox(height: 16),
              _buildInputField(label: 'Password', hint: '••••••••', isPassword: true, controller: _passwordController),
              const SizedBox(height: 16),
              _buildInputField(label: 'Confirm Password', hint: '••••••••', isPassword: true, controller: _confirmPasswordController),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B3B2B),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: _isLoading ? null : _handleSignUp,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Sign Up', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        color: Color(0xFF1B3B2B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({required String label, required String hint, required TextEditingController controller, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1B3B2B))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// SETTINGS SCREEN
// ==========================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String userEmail = 'Mathews — Northrise University';
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.email != null) {
        userEmail = user.email!;
      }
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B2B),
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF1B3B2B)),
                  title: const Text('Account Profile'),
                  subtitle: Text(userEmail),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications, color: Color(0xFF1B3B2B)),
                  title: const Text('Notifications & Alerts'),
                  subtitle: const Text('Manage telemetry push alerts'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.thermostat, color: Color(0xFF1B3B2B)),
                  title: const Text('Temperature Units'),
                  subtitle: const Text('Celsius (°C)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Color(0xFF1B3B2B)),
                  title: const Text('About CompostWise'),
                  subtitle: const Text('Version 1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {}
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. MAIN NAVIGATION HOLDER & GLOBAL STATE
// ==========================================
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _hasUnreadAlerts = true;

  List<CompostAlert> alertsList = [
    CompostAlert(
      id: '1',
      title: 'Pile B — low moisture warning',
      time: '1h ago',
      body: 'Moisture level dropped to 38%. Water addition needed.',
      color: Colors.orange,
    ),
    CompostAlert(
      id: '2',
      title: 'Pile C — critical pH drift',
      time: '3h ago',
      body: 'pH recorded at 5.5. Turn the pile to increase aeration.',
      color: Colors.red,
    ),
  ];

  List<CompostPile> piles = [
    CompostPile(
      id: 'A',
      name: 'Pile A — Maize stalks',
      category: 'Maize stalks',
      status: StatusLevel.onTrack,
      temp: 63.0,
      moisture: 55.0,
      ph: 7.2,
      targetTotalDays: 30,
      startDate: DateTime.now().subtract(const Duration(days: 28)),
      history: [
        DayReading(day: 1, dateStr: 'Aug 20', temp: 32, moisture: 60, ph: 6.2),
        DayReading(day: 7, dateStr: 'Aug 27', temp: 55, moisture: 58, ph: 6.5),
        DayReading(day: 14, dateStr: 'Sep 03', temp: 65, moisture: 56, ph: 6.8),
        DayReading(day: 21, dateStr: 'Sep 10', temp: 64, moisture: 55, ph: 7.0),
        DayReading(day: 28, dateStr: 'Sep 17', temp: 63, moisture: 55, ph: 7.2),
      ],
    ),
    CompostPile(
      id: 'B',
      name: 'Pile B — Kitchen waste',
      category: 'Kitchen waste',
      status: StatusLevel.warning,
      temp: 48.0,
      moisture: 64.0,
      ph: 6.1,
      targetTotalDays: 20,
      startDate: DateTime.now().subtract(const Duration(days: 12)),
      history: [
        DayReading(day: 1, dateStr: 'Sep 05', temp: 30, moisture: 68, ph: 5.8),
        DayReading(day: 6, dateStr: 'Sep 10', temp: 45, moisture: 65, ph: 6.0),
        DayReading(day: 12, dateStr: 'Sep 16', temp: 48, moisture: 64, ph: 6.1),
      ],
    ),
    CompostPile(
      id: 'C',
      name: 'Pile C — Garden mix',
      category: 'Garden mix',
      status: StatusLevel.critical,
      temp: 38.0,
      moisture: 72.0,
      ph: 5.5,
      targetTotalDays: 25,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      history: [
        DayReading(day: 1, dateStr: 'Sep 12', temp: 28, moisture: 75, ph: 5.4),
        DayReading(day: 5, dateStr: 'Sep 16', temp: 38, moisture: 72, ph: 5.5),
      ],
    ),
    CompostPile(
      id: 'D',
      name: 'Pile D — Sawdust & Manure',
      category: 'Wood & Manure',
      status: StatusLevel.onTrack,
      temp: 58.0,
      moisture: 52.0,
      ph: 6.8,
      targetTotalDays: 45,
      startDate: DateTime.now().subtract(const Duration(days: 44)),
      history: [
        DayReading(day: 1, dateStr: 'Aug 03', temp: 30, moisture: 50, ph: 6.0),
        DayReading(day: 20, dateStr: 'Aug 23', temp: 62, moisture: 54, ph: 6.5),
        DayReading(day: 44, dateStr: 'Sep 16', temp: 58, moisture: 52, ph: 6.8),
      ],
    ),
    CompostPile(
      id: 'E',
      name: 'Pile E — Coffee Grounds',
      category: 'Organic Grounds',
      status: StatusLevel.warning,
      temp: 42.0,
      moisture: 35.0,
      ph: 6.0,
      targetTotalDays: 25,
      startDate: DateTime.now().subtract(const Duration(days: 18)),
      history: [
        DayReading(day: 1, dateStr: 'Aug 30', temp: 29, moisture: 40, ph: 5.9),
        DayReading(day: 18, dateStr: 'Sep 16', temp: 42, moisture: 35, ph: 6.0),
      ],
    ),
    CompostPile(
      id: 'F',
      name: 'Pile F — Sugarcane Bagasse',
      category: 'Crop Refuse',
      status: StatusLevel.onTrack,
      temp: 60.0,
      moisture: 58.0,
      ph: 7.0,
      targetTotalDays: 35,
      startDate: DateTime.now().subtract(const Duration(days: 15)),
      history: [
        DayReading(day: 1, dateStr: 'Sep 02', temp: 31, moisture: 60, ph: 6.2),
        DayReading(day: 15, dateStr: 'Sep 16', temp: 60, moisture: 58, ph: 7.0),
      ],
    ),
    CompostPile(
      id: 'G',
      name: 'Pile G — Poultry Litter',
      category: 'High Nitrogen Waste',
      status: StatusLevel.critical,
      temp: 74.0,
      moisture: 30.0,
      ph: 8.2,
      targetTotalDays: 28,
      startDate: DateTime.now().subtract(const Duration(days: 8)),
      history: [
        DayReading(day: 1, dateStr: 'Sep 09', temp: 40, moisture: 45, ph: 7.5),
        DayReading(day: 8, dateStr: 'Sep 16', temp: 74, moisture: 30, ph: 8.2),
      ],
    ),
    CompostPile(
      id: 'H',
      name: 'Pile H — Market Vegetable Leaves',
      category: 'Fresh Green Waste',
      status: StatusLevel.warning,
      temp: 45.0,
      moisture: 68.0,
      ph: 6.3,
      targetTotalDays: 18,
      startDate: DateTime.now().subtract(const Duration(days: 4)),
      history: [
        DayReading(day: 1, dateStr: 'Sep 13', temp: 26, moisture: 70, ph: 6.1),
        DayReading(day: 4, dateStr: 'Sep 16', temp: 45, moisture: 68, ph: 6.3),
      ],
    ),
    CompostPile(
      id: 'Z',
      name: 'Pile F — Dry Leaves',
      category: 'Yard Waste',
      status: StatusLevel.completed,
      temp: 25.0,
      moisture: 20.0,
      ph: 7.0,
      isArchived: true,
      startDate: DateTime.now().subtract(const Duration(days: 60)),
      history: [
        DayReading(day: 1, dateStr: 'Jul 18', temp: 25, moisture: 50, ph: 6.5),
        DayReading(day: 60, dateStr: 'Sep 16', temp: 25, moisture: 20, ph: 7.0),
      ],
    ),
  ];

  void _checkAndTriggerReadinessAlerts() {
    for (var pile in piles) {
      if (!pile.isArchived && pile.readinessPercent >= 99.5) {
        pile.isArchived = true;
        pile.status = StatusLevel.completed;

        // Auto add Alert
        alertsList.insert(
          0,
          CompostAlert(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: '${pile.name} is READY!',
            time: 'Just now',
            body: 'Pile has reached 100% maturity stage. Automatically moved to Archives.',
            color: Colors.green,
          ),
        );
        _hasUnreadAlerts = true;
      }
    }
  }

  void _openAddPileModal() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Compost Pile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Pile Name (e.g. Pile I - Shells)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category (e.g. Agricultural Refuse)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3B2B), minimumSize: const Size(double.infinity, 50)),
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    setState(() {
                      piles.add(CompostPile(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        category: categoryController.text.isEmpty ? 'General Organic Waste' : categoryController.text,
                        status: StatusLevel.onTrack,
                        temp: 55.0,
                        moisture: 55.0,
                        ph: 7.0,
                        startDate: DateTime.now(),
                        history: [DayReading(day: 1, dateStr: 'Today', temp: 55, moisture: 55, ph: 7.0)],
                      ));
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Create Pile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _checkAndTriggerReadinessAlerts();

    final activePiles = piles.where((p) => !p.isArchived).toList();
    final archivedPiles = piles.where((p) => p.isArchived).toList();

    final List<Widget> screens = [
      HomeScreen(
        piles: activePiles,
        onPileUpdated: () => setState(() {}),
        onOpenDetail: (pile) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PileDetailScreen(pile: pile)));
        },
      ),
      PilesTabScreen(piles: activePiles),
      const TrendsScreen(),
      AlertsScreen(alerts: alertsList),
      ArchivesScreen(archivedPiles: archivedPiles, activePiles: activePiles),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddPileModal,
        backgroundColor: const Color(0xFF1B3B2B),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5))),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1B3B2B),
          unselectedItemColor: Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              if (index == 3) _hasUnreadAlerts = false;
            });
          },
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home, size: 20), label: 'Home'),
            const BottomNavigationBarItem(icon: Icon(Icons.layers, size: 20), label: 'Piles'),
            const BottomNavigationBarItem(icon: Icon(Icons.show_chart, size: 20), label: 'Trends'),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications, size: 20),
                  if (_hasUnreadAlerts)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    )
                ],
              ),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.archive, size: 20), label: 'Archives'),
            const BottomNavigationBarItem(icon: Icon(Icons.settings, size: 20), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. HOME SCREEN WITH FLOATING PERCENTAGE PROGRESS
// ==========================================
class HomeScreen extends StatelessWidget {
  final List<CompostPile> piles;
  final VoidCallback onPileUpdated;
  final Function(CompostPile) onOpenDetail;

  const HomeScreen({
    super.key,
    required this.piles,
    required this.onPileUpdated,
    required this.onOpenDetail,
  });

  void _showAdjustParametersModal(BuildContext context, CompostPile pile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Adjust Parameters — ${pile.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF1B3B2B), borderRadius: BorderRadius.circular(12)),
                        child: Text('${pile.predictedDaysRemaining} Days Left', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Temp Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Temperature: ${pile.temp.round()}°C', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(pile.temp < 40 ? "Low" : pile.temp > 68 ? "Critical High" : "Optimal", style: TextStyle(color: pile.temp < 40 || pile.temp > 68 ? Colors.red : Colors.green, fontSize: 12)),
                    ],
                  ),
                  Slider(
                    value: pile.temp,
                    min: 20,
                    max: 80,
                    activeColor: const Color(0xFF1B3B2B),
                    onChanged: (v) {
                      setModalState(() => pile.temp = v);
                      onPileUpdated();
                    },
                  ),

                  // Moisture Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Moisture: ${pile.moisture.round()}%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(pile.moisture < 40 ? "Dry" : pile.moisture > 70 ? "Soggy" : "Optimal", style: TextStyle(color: pile.moisture < 40 || pile.moisture > 70 ? Colors.orange : Colors.green, fontSize: 12)),
                    ],
                  ),
                  Slider(
                    value: pile.moisture,
                    min: 10,
                    max: 90,
                    activeColor: const Color(0xFF1B3B2B),
                    onChanged: (v) {
                      setModalState(() => pile.moisture = v);
                      onPileUpdated();
                    },
                  ),

                  // pH Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('pH Level: ${pile.ph.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(pile.ph < 6.0 ? "Acidic" : pile.ph > 8.0 ? "Alkaline" : "Balanced", style: TextStyle(color: pile.ph < 6.0 || pile.ph > 8.0 ? Colors.orange : Colors.green, fontSize: 12)),
                    ],
                  ),
                  Slider(
                    value: pile.ph,
                    min: 4.0,
                    max: 10.0,
                    divisions: 60,
                    activeColor: const Color(0xFF1B3B2B),
                    onChanged: (v) {
                      setModalState(() => pile.ph = double.parse(v.toStringAsFixed(1)));
                      onPileUpdated();
                    },
                  ),

                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3B2B), minimumSize: const Size(double.infinity, 44)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int needsAttentionCount = piles.where((p) => p.status != StatusLevel.onTrack).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFF1B3B2B),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(getRealtimeGreeting('Mathews'), style: const TextStyle(fontFamily: 'Serif', color: Colors.white, fontSize: 22)),
                    const SizedBox(height: 2),
                    Text('${piles.length} active piles monitored - Ndola, CB', style: const TextStyle(color: Color(0xFF81E6D9), fontSize: 13)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: const Color(0xFF1B3B2B), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Active piles', style: TextStyle(color: Color(0xFF81E6D9), fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('${piles.length}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Needs attention', style: TextStyle(color: Color(0xFF92400E), fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('$needsAttentionCount', style: const TextStyle(color: Color(0xFF92400E), fontSize: 26, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Text('YOUR COMPOST PILES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
                    const SizedBox(height: 12),

                    ...piles.map((pile) => _buildPileCard(context, pile)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPileCard(BuildContext context, CompostPile pile) {
    Color headerColor = getHeaderColor(pile.status);
    Color metricColor = getMetricColor(pile.status);
    Color badgeBg = getBadgeBgColor(pile.status);
    Color badgeText = getBadgeTextColor(pile.status);
    double progress = pile.readinessPercent;

    return GestureDetector(
      onTap: () => onOpenDetail(pile),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: headerColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(pile.name, style: const TextStyle(fontFamily: 'Serif', color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
                    child: Text(getStatusLabel(pile.status), style: TextStyle(color: badgeText, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // OVERALL PROGRESS BAR WITH TOOLTIP BADGE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Overall Progress:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
                      Text('${progress.round()}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: metricColor)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      double width = constraints.maxWidth;
                      double badgePosition = (width * (progress / 100.0)).clamp(0.0, width - 36);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.translate(
                            offset: Offset(badgePosition, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF00A896), borderRadius: BorderRadius.circular(4)),
                              child: Text('${progress.round()}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress / 100.0,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              color: const Color(0xFF00A896),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${pile.predictedDaysRemaining}', style: TextStyle(fontFamily: 'Serif', fontSize: 28, color: metricColor)),
                          const Text('days remaining', style: TextStyle(fontSize: 12, color: Color(0xFF2D3748))),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B3B2B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _showAdjustParametersModal(context, pile),
                        child: const Text('Adjust Parameters', style: TextStyle(color: Colors.white, fontSize: 12)),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildParameterRow('Temp', '${pile.temp.round()}°C', pile.temp / 80.0, metricColor),
                  const SizedBox(height: 6),
                  _buildParameterRow('Moisture', '${pile.moisture.round()}%', pile.moisture / 100.0, metricColor),
                  const SizedBox(height: 6),
                  _buildParameterRow('pH', '${pile.ph}', pile.ph / 14.0, metricColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterRow(String label, String value, double progress, Color color) {
    return Row(
      children: [
        SizedBox(width: 65, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF2D3748)))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), backgroundColor: const Color(0xFFE2E8F0), color: color, minHeight: 8),
          ),
        ),
        SizedBox(width: 50, child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
      ],
    );
  }
}

// ==========================================
// SINGLE PILE PDF REPORT GENERATOR ENGINE
// ==========================================
Future<File> generateSinglePilePdfReport(CompostPile pile) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.5, color: PdfColors.green800)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CompostWise', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    pw.Text('Individual Pile Telemetry & Historical Report', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated: ${DateTime.now().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('Location: Ndola, CB', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Pile Header Box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(pile.name, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    pw.Text(
                      '${pile.readinessPercent.round()}% Ready (${getStatusLabel(pile.status)})',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: pile.isArchived ? PdfColors.green800 : PdfColors.orange800),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Category: ${pile.category}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    pw.Text('Target Total Days: ${pile.targetTotalDays}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    pw.Text('Est. Days Remaining: ${pile.predictedDaysRemaining}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Current Telemetry Metrics Section
          pw.Text('Current Telemetry Metrics', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('Temperature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('${pile.temp.round()}°C', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('Moisture Level', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('${pile.moisture.round()}%', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('pH Balance', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('${pile.ph}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('Current Stage', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text(pile.currentStage.name.toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Historical Parameter Change Log Table
          pw.Text('Parameter Change History & Progression Log', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
          pw.SizedBox(height: 8),
          if (pile.history.isEmpty)
            pw.Text('No historical logs recorded for this pile.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              cellHeight: 20,
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headers: ['Date Logged', 'Timeline', 'Temp (°C)', 'Moisture (%)', 'pH Level', 'Thermal Evaluation'],
              data: pile.history.map((reading) {
                String tempEval = (reading.temp >= 50 && reading.temp <= 65)
                    ? 'Optimal Active'
                    : (reading.temp < 40 ? 'Low Activity' : 'Critical High');
                return [
                  reading.dateStr,
                  'Day ${reading.day}',
                  '${reading.temp.round()}°C',
                  '${reading.moisture.round()}%',
                  '${reading.ph}',
                  tempEval,
                ];
              }).toList(),
            ),
        ];
      },
    ),
  );

  final output = await getTemporaryDirectory();
  final sanitizedName = pile.name.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
  final file = File('${output.path}/${sanitizedName}_Report.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

// ==========================================
// 6. DETAILED PILE BREAKDOWN & HISTORY SCREEN
// ==========================================
class PileDetailScreen extends StatelessWidget {
  final CompostPile pile;

  const PileDetailScreen({super.key, required this.pile});

  @override
  Widget build(BuildContext context) {
    CompostStage stage = pile.currentStage;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B2B),
        title: Text(pile.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Export Pile PDF Report',
            onPressed: () async {
              final pdfFile = await generateSinglePilePdfReport(pile);
              await Share.shareXFiles([XFile(pdfFile.path)], text: '${pile.name} Telemetry & Readiness Report');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STEPPER BREAKDOWN
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Decomposition Stage Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B3B2B))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStageStep('Mesophilic', stage.index >= 0, stage.index == 0),
                        _buildStageConnector(stage.index > 0),
                        _buildStageStep('Thermophilic', stage.index >= 1, stage.index == 1),
                        _buildStageConnector(stage.index > 1),
                        _buildStageStep('Cooling', stage.index >= 2, stage.index == 2),
                        _buildStageConnector(stage.index > 2),
                        _buildStageStep('Maturation', stage.index >= 3, stage.index == 3),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // LIVE METRICS & PREDICTOR BADGE
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Predictive Maturity Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: getBadgeBgColor(pile.status), borderRadius: BorderRadius.circular(12)),
                          child: Text('${pile.predictedDaysRemaining} Days Left', style: TextStyle(color: getBadgeTextColor(pile.status), fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricTile('Temperature', '${pile.temp.round()}°C', Icons.thermostat),
                        _buildMetricTile('Moisture', '${pile.moisture.round()}%', Icons.water_drop),
                        _buildMetricTile('pH Level', '${pile.ph}', Icons.science),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // PARAMETER CHANGE HISTORY LOG
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Parameter Change History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B3B2B))),
                    const SizedBox(height: 12),
                    if (pile.history.isEmpty)
                      const Text('No historical logs recorded yet.', style: TextStyle(color: Colors.grey, fontSize: 13))
                    else
                      ...pile.history.map((reading) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${reading.dateStr} (Day ${reading.day})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('Temp: ${reading.temp.round()}°C  |  Moisture: ${reading.moisture.round()}%  |  pH: ${reading.ph}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B3B2B),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text('Export Pile PDF Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () async {
                final pdfFile = await generateSinglePilePdfReport(pile);
                await Share.shareXFiles([XFile(pdfFile.path)], text: '${pile.name} Telemetry & Readiness Report');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageStep(String title, bool isDone, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isDone ? const Color(0xFF00A896) : Colors.grey.shade300,
            child: Icon(isDone ? Icons.check : Icons.circle, size: 12, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? const Color(0xFF00A896) : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStageConnector(bool isDone) {
    return Container(width: 12, height: 2, color: isDone ? const Color(0xFF00A896) : Colors.grey.shade300);
  }

  Widget _buildMetricTile(String title, String val, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF1B3B2B), size: 24),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
      ],
    );
  }
}

// ==========================================
// 7. PILES TAB SCREEN
// ==========================================
class PilesTabScreen extends StatelessWidget {
  final List<CompostPile> piles;

  const PilesTabScreen({super.key, required this.piles});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B2B),
        title: const Text('Active Piles', style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: piles.length,
        itemBuilder: (context, index) {
          final pile = piles[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1B3B2B),
                child: Icon(Icons.eco, color: Colors.white),
              ),
              title: Text(pile.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('Category: ${pile.category} • Readiness: ${pile.readinessPercent.round()}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PileDetailScreen(pile: pile)));
              },
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 8. TRENDS TAB SCREEN
// ==========================================
class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B2B),
        title: const Text('Trends', style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTrendCard('Temperature', '63°C avg', 'Min 52°C', 'Max 67°C', 'Trend: Optimal', Colors.green),
          _buildTrendCard('Moisture', '55% avg', 'Min 51%', 'Max 68%', 'Trend: Stable', Colors.green),
          _buildTrendCard('pH level', '7.2 avg', 'Min 6.2', 'Max 7.4', 'Trend: Rising', Colors.green),
        ],
      ),
    );
  }

  Widget _buildTrendCard(String title, String avg, String minVal, String maxVal, String trendText, Color trendColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(avg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 24),
            Center(child: Text('7-Day Telemetry Trend Graph', style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(minVal, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(maxVal, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(trendText, style: TextStyle(color: trendColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 9. ALERTS TAB SCREEN
// ==========================================
class AlertsScreen extends StatelessWidget {
  final List<CompostAlert> alerts;

  const AlertsScreen({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B2B),
        title: const Text('Alerts', style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final item = alerts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 6,
                    decoration: BoxDecoration(color: item.color, borderRadius: const BorderRadius.horizontal(left: Radius.circular(12))),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(item.time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(item.body, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// FULLY FUNCTIONAL PDF & EMAIL EXPORT ARCHIVES SCREEN
// ==========================================
class ArchivesScreen extends StatelessWidget {
  final List<CompostPile> archivedPiles;
  final List<CompostPile> activePiles;

  const ArchivesScreen({
    super.key,
    required this.archivedPiles,
    required this.activePiles,
  });

  // PDF Generator Engine with full pile details, telemetry snapshots & historical parameter logs
  Future<File> _generatePdfReport() async {
    final pdf = pw.Document();
    final allPiles = [...archivedPiles, ...activePiles];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          List<pw.Widget> content = [];

          // Document Header
          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1.5, color: PdfColors.green800)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CompostWise', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                      pw.Text('Telemetry, Readiness & Archive Report', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Generated: ${DateTime.now().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.Text('Location: Ndola, CB', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            ),
          );

          content.add(pw.SizedBox(height: 14));

          // Executive Summary Box
          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Executive Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Text('Total Piles: ${allPiles.length}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Completed / Archived: ${archivedPiles.length}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                      pw.Text('Active Monitored: ${activePiles.length}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    ],
                  ),
                ],
              ),
            ),
          );

          content.add(pw.SizedBox(height: 18));

          // Section Title
          content.add(pw.Text('Detailed Pile Telemetry & Historical Parameter Logs', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)));
          content.add(pw.SizedBox(height: 10));

          if (allPiles.isEmpty) {
            content.add(pw.Text('No compost pile records available.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)));
          } else {
            for (var pile in allPiles) {
              content.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 16),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Pile Header
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${pile.name} [${pile.isArchived ? "COMPLETED & ARCHIVED" : "ACTIVE"}]',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: pile.isArchived ? PdfColors.green800 : PdfColors.blue800),
                          ),
                          pw.Text(
                            'Readiness: ${pile.readinessPercent.round()}% | Status: ${getStatusLabel(pile.status)}',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Category: ${pile.category} | Target Total Days: ${pile.targetTotalDays} | Days Remaining: ${pile.predictedDaysRemaining}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 6),

                      // Current Parameter Snapshots
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: PdfColors.grey100,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Temperature: ${pile.temp.round()}°C', style: const pw.TextStyle(fontSize: 9)),
                            pw.Text('Moisture: ${pile.moisture.round()}%', style: const pw.TextStyle(fontSize: 9)),
                            pw.Text('pH Level: ${pile.ph}', style: const pw.TextStyle(fontSize: 9)),
                            pw.Text('Stage: ${pile.currentStage.name.toUpperCase()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 8),

                      // Historical Log Table for this Pile
                      pw.Text('Parameter Change History:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                      pw.SizedBox(height: 4),
                      if (pile.history.isEmpty)
                        pw.Text('No historical readings logged.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))
                      else
                        pw.TableHelper.fromTextArray(
                          cellHeight: 16,
                          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                          headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                          cellStyle: const pw.TextStyle(fontSize: 8),
                          headers: ['Date Logged', 'Timeline', 'Temp (°C)', 'Moisture (%)', 'pH', 'Thermal Evaluation'],
                          data: pile.history.map((reading) {
                            String tempEval = (reading.temp >= 50 && reading.temp <= 65)
                                ? 'Optimal Active'
                                : (reading.temp < 40 ? 'Low Activity' : 'Critical High');
                            return [
                              reading.dateStr,
                              'Day ${reading.day}',
                              '${reading.temp.round()}°C',
                              '${reading.moisture.round()}%',
                              '${reading.ph}',
                              tempEval,
                            ];
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              );
            }
          }

          return content;
        },
      ),
    );

    // Save PDF to temp device directory
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/CompostWise_Archive_Report.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  void _showExportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Export Telemetry & Readiness Report',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B3B2B)),
              ),
              const SizedBox(height: 8),
              Text(
                'Generate a PDF document or share via email for ${archivedPiles.length} completed and ${activePiles.length} active piles.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1B3B2B),
                  child: Icon(Icons.picture_as_pdf, color: Colors.white),
                ),
                title: const Text('Export & Open PDF File',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Generate and preview PDF file'),
                onTap: () async {
                  Navigator.pop(context);
                  final pdfFile = await _generatePdfReport();
                  await Share.shareXFiles([XFile(pdfFile.path)],
                      text: 'CompostWise Telemetry & Readiness Report PDF');
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1B3B2B),
                  child: Icon(Icons.email, color: Colors.white),
                ),
                title: const Text('Send Report via Email',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Share PDF directly via your mail client'),
                onTap: () async {
                  Navigator.pop(context);
                  final pdfFile = await _generatePdfReport();
                  await Share.shareXFiles(
                    [XFile(pdfFile.path)],
                    subject: 'CompostWise Telemetry Report',
                    text:
                    'Attached is the latest compost telemetry and readiness report.',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B2B),
        title: const Text('Compost Archives',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.white),
            onPressed: () => _showExportDialog(context),
          ),
        ],
      ),
      body: archivedPiles.isEmpty
          ? const Center(
        child: Text(
          'No completed compost piles archived yet.',
          style: TextStyle(color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: archivedPiles.length,
        itemBuilder: (context, index) {
          final pile = archivedPiles[index];
          return Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.check, color: Colors.white),
              ),
              title: Text(pile.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(
                  'Completed • Category: ${pile.category}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF1B3B2B)),
                    tooltip: 'Export Pile PDF Report',
                    onPressed: () async {
                      final pdfFile = await generateSinglePilePdfReport(pile);
                      await Share.shareXFiles([XFile(pdfFile.path)], text: '${pile.name} Telemetry Report PDF');
                    },
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PileDetailScreen(pile: pile),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}