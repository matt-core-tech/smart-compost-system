import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const MethodChannel _notificationChannel = MethodChannel('com.example.smart_compost_system/notifications');

// Supabase Configuration
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
// 1. DATA MODELS & ENUMS
// ==========================================
enum StatusLevel { onTrack, warning, critical, completed }

class DayReading {
  final int? id;
  final String? pileId;
  final int day;
  final String dateStr;
  final double? temp;
  final double? moisture;      // Raw ADC (preserved for backward compatibility)
  final double? rawMoisture;   // Raw ADC value (e.g. 0 - 4095)
  final double? moisturePct;   // Calibrated moisture percentage (0.0% - 100.0%)
  final double? ph;
  final DateTime? createdAt;

  DayReading({
    this.id,
    this.pileId,
    required this.day,
    required this.dateStr,
    this.temp,
    this.moisture,
    this.rawMoisture,
    this.moisturePct,
    this.ph,
    this.createdAt,
  });

  factory DayReading.fromMap(Map<String, dynamic> map) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    String dateDisplay = 'Today';
    DateTime? created;
    if (map['created_at'] != null) {
      try {
        created = DateTime.parse(map['created_at'].toString());
        dateDisplay = '${_monthName(created.month)} ${created.day.toString().padLeft(2, '0')} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    } else if (map['reading_date'] != null) {
      dateDisplay = map['reading_date'].toString();
    }

    final parsedMoisture = parseDouble(map['moisture']);
    final parsedRawMoisture = parseDouble(map['raw_moisture']) ?? parsedMoisture;
    final parsedMoisturePct = parseDouble(map['moisture_pct']);

    return DayReading(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      pileId: map['pile_id']?.toString(),
      day: map['day_number'] != null ? int.tryParse(map['day_number'].toString()) ?? 1 : 1,
      dateStr: dateDisplay,
      temp: parseDouble(map['temp']),
      moisture: parsedMoisture,
      rawMoisture: parsedRawMoisture,
      moisturePct: parsedMoisturePct,
      ph: parseDouble(map['ph']),
      createdAt: created,
    );
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  String get tempDisplay => temp != null ? '${temp!.round()}°C' : 'Not available';
  
  String get moistureDisplay {
    if (moisturePct != null) {
      return '${moisturePct!.round()}%';
    } else if (rawMoisture != null) {
      return '${rawMoisture!.round()} ADC (Pending Calibration)';
    } else if (moisture != null) {
      return '${moisture!.round()} ADC (Pending Calibration)';
    } else {
      return 'Not available';
    }
  }

  String get phDisplay => ph != null ? ph!.toStringAsFixed(1) : 'Not available';
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
  final String? userId;
  final int? pileNumber;
  final String name;
  final String category;
  StatusLevel status;
  double? temp;
  double? moisture;
  double? ph;
  List<DayReading> history;
  bool isArchived;
  DateTime startDate;

  CompostPile({
    required this.id,
    this.userId,
    this.pileNumber,
    required this.name,
    required this.category,
    required this.status,
    this.temp,
    this.moisture,
    this.ph,
    required this.history,
    this.isArchived = false,
    required this.startDate,
  });

  factory CompostPile.fromMap(Map<String, dynamic> map, {List<DayReading>? historyReadings}) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    DateTime parsedStart = DateTime.now();
    if (map['start_date'] != null) {
      try {
        parsedStart = DateTime.parse(map['start_date'].toString());
      } catch (_) {}
    } else if (map['created_at'] != null) {
      try {
        parsedStart = DateTime.parse(map['created_at'].toString());
      } catch (_) {}
    }

    StatusLevel parsedStatus = StatusLevel.onTrack;
    if (map['status'] != null) {
      String statusStr = map['status'].toString().toLowerCase();
      if (statusStr.contains('warning')) {
        parsedStatus = StatusLevel.warning;
      } else if (statusStr.contains('critical')) {
        parsedStatus = StatusLevel.critical;
      } else if (statusStr.contains('completed') || statusStr.contains('ready')) {
        parsedStatus = StatusLevel.completed;
      }
    }

    List<DayReading> sortedHistory = historyReadings ?? [];
    double? latestTemp = parseDouble(map['temp']);
    double? latestMoisture = parseDouble(map['moisture']);
    double? latestPh = parseDouble(map['ph']);

    if (sortedHistory.isNotEmpty) {
      final latestReading = sortedHistory.last;
      latestTemp ??= latestReading.temp;
      latestMoisture ??= latestReading.moisture;
      latestPh ??= latestReading.ph;
    }

    int? parsedPileNumber;
    if (map['pile_number'] != null) {
      parsedPileNumber = int.tryParse(map['pile_number'].toString());
    }

    final pile = CompostPile(
      id: map['id'].toString(),
      userId: map['user_id']?.toString(),
      pileNumber: parsedPileNumber,
      name: map['name'] ?? 'Unnamed Pile',
      category: map['category'] ?? 'General Organic Waste',
      status: parsedStatus,
      temp: latestTemp,
      moisture: latestMoisture,
      ph: latestPh,
      history: sortedHistory,
      isArchived: map['is_archived'] == true,
      startDate: parsedStart,
    );

    pile._updateStatus();
    return pile;
  }

  String get displayName => pileNumber != null ? 'Pile #$pileNumber — $name' : name;
  String get tempDisplay => temp != null ? '${temp!.round()}°C' : 'Not available';
  
  String get moistureDisplay {
    if (history.isNotEmpty && history.last.moisturePct != null) {
      return '${history.last.moisturePct!.round()}%';
    } else if (history.isNotEmpty && history.last.rawMoisture != null) {
      return '${history.last.rawMoisture!.round()} ADC (Pending Calibration)';
    } else if (moisture != null) {
      return '${moisture!.round()} ADC (Pending Calibration)';
    } else {
      return 'Not available';
    }
  }

  String get phDisplay => ph != null ? ph!.toStringAsFixed(1) : 'Not available';

  void _updateStatus() {
    if (isArchived) {
      status = StatusLevel.completed;
      return;
    }
    if (temp != null && (temp! < 35.0 || temp! > 70.0)) {
      status = StatusLevel.critical;
    } else if (temp != null && (temp! < 45.0 || temp! > 65.0)) {
      status = StatusLevel.warning;
    } else {
      status = StatusLevel.onTrack;
    }
  }
}

// Admin Models
class AdminAppUser {
  final String id;
  final String email;
  final String fullName;
  final DateTime? createdAt;
  final String role;
  final int pileCount;

  AdminAppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.createdAt,
    this.role = 'user',
    this.pileCount = 0,
  });
}

class AdminDeviceNode {
  final String id;
  final String deviceCode;
  final String? pileId;
  final DateTime? lastSeen;
  final bool isOnline;

  AdminDeviceNode({
    required this.id,
    required this.deviceCode,
    this.pileId,
    this.lastSeen,
    this.isOnline = false,
  });
}

class AdminAuditLog {
  final String id;
  final String? userId;
  final String action;
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic>? details;
  final DateTime? createdAt;

  AdminAuditLog({
    required this.id,
    this.userId,
    required this.action,
    this.targetType,
    this.targetId,
    this.details,
    this.createdAt,
  });
}

// Helper Color Functions
Color getStatusColor(StatusLevel status) {
  switch (status) {
    case StatusLevel.onTrack: return const Color(0xFF00A896);
    case StatusLevel.warning: return Colors.orange.shade700;
    case StatusLevel.critical: return Colors.red.shade700;
    case StatusLevel.completed: return Colors.green.shade800;
  }
}

Color getHeaderColor(StatusLevel status) {
  switch (status) {
    case StatusLevel.onTrack: return const Color(0xFF1B3B2B);
    case StatusLevel.warning: return const Color(0xFF7B341E);
    case StatusLevel.critical: return const Color(0xFF742A2A);
    case StatusLevel.completed: return const Color(0xFF276749);
  }
}

Color getMetricColor(StatusLevel status) {
  switch (status) {
    case StatusLevel.onTrack: return const Color(0xFF1B3B2B);
    case StatusLevel.warning: return const Color(0xFFC05621);
    case StatusLevel.critical: return const Color(0xFFC53030);
    case StatusLevel.completed: return const Color(0xFF22543D);
  }
}

Color getBadgeBgColor(StatusLevel status) {
  switch (status) {
    case StatusLevel.onTrack: return const Color(0xFFE6FFFA);
    case StatusLevel.warning: return const Color(0xFFFEEBC8);
    case StatusLevel.critical: return const Color(0xFFFED7D7);
    case StatusLevel.completed: return const Color(0xFFC6F6D5);
  }
}

Color getBadgeTextColor(StatusLevel status) {
  switch (status) {
    case StatusLevel.onTrack: return const Color(0xFF234E52);
    case StatusLevel.warning: return const Color(0xFF7B341E);
    case StatusLevel.critical: return const Color(0xFF742A2A);
    case StatusLevel.completed: return const Color(0xFF22543D);
  }
}

String getStatusLabel(StatusLevel status) {
  switch (status) {
    case StatusLevel.onTrack: return 'On track';
    case StatusLevel.warning: return 'Warning';
    case StatusLevel.critical: return 'Critical';
    case StatusLevel.completed: return 'Completed';
  }
}

String getRealtimeGreeting(String userName) {
  final hour = DateTime.now().hour;
  String timeGreeting = 'Good morning';
  if (hour >= 12 && hour < 17) {
    timeGreeting = 'Good afternoon';
  } else if (hour >= 17) {
    timeGreeting = 'Good evening';
  }
  return '$timeGreeting, $userName!';
}

// ==========================================
// 2. ROOT APPLICATION & AUTH GUARD
// ==========================================
class CompostWiseApp extends StatelessWidget {
  const CompostWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Compost System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B3B2B)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F4F5),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _currentUser = data.session?.user;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _checkAuth() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (mounted) {
      setState(() {
        _currentUser = session?.user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B3B2B),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_currentUser == null) {
      return const LoginScreen();
    }

    return const MainNavigation();
  }
}

// ==========================================
// 3. AUTHENTICATION SCREENS
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login error: ${e.toString()}'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.eco, size: 64, color: Color(0xFF1B3B2B)),
                const SizedBox(height: 12),
                const Text('Welcome Back', style: TextStyle(fontFamily: 'Serif', fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
                const SizedBox(height: 6),
                Text('Log in to monitor your compost piles', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                const SizedBox(height: 32),

                Align(alignment: Alignment.centerLeft, child: Text('Email address', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 13))),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'farmer@example.com',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
                const SizedBox(height: 16),

                Align(alignment: Alignment.centerLeft, child: Text('Password', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 13))),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B3B2B),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Log In', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("New here? ", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
                      child: const Text('Create an account', style: TextStyle(color: Color(0xFF1B3B2B), fontWeight: FontWeight.bold, fontSize: 13)),
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

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signUp() async {
    final name = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully! Logging in...'), backgroundColor: Color(0xFF1B3B2B)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign up error: ${e.toString()}'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F5),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Color(0xFF1B3B2B))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.eco, size: 64, color: Color(0xFF1B3B2B)),
                const SizedBox(height: 12),
                const Text('Create Account', style: TextStyle(fontFamily: 'Serif', fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
                const SizedBox(height: 6),
                Text('Start monitoring your compost scientifically', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                const SizedBox(height: 28),

                Align(alignment: Alignment.centerLeft, child: Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 13))),
                const SizedBox(height: 6),
                TextField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    hintText: 'John Doe',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
                const SizedBox(height: 16),

                Align(alignment: Alignment.centerLeft, child: Text('Email address', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 13))),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'farmer@example.com',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
                const SizedBox(height: 16),

                Align(alignment: Alignment.centerLeft, child: Text('Password', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 13))),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B3B2B),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. MAIN NAVIGATION & USER APP STATE
// ==========================================
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _hasUnreadAlerts = false;
  bool _isLoadingPiles = true;
  bool _isAdmin = false;
  String? _errorMessage;
  String? _selectedPileUuid;
  String? _activeReadingPileUuid;
  DateTime? _getReadingsStartTime;
  DayReading? _lastReceivedReading;
  final Set<String> _notified5DayPiles = {};
  final Set<String> _notifiedCompletedPiles = {};
  RealtimeChannel? _realtimeChannel;

  List<CompostAlert> alertsList = [];
  List<CompostPile> piles = [];

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    _fetchCompostPilesAndReadings();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _checkAdminRole() async {
    try {
      final dynamic isAdminRes = await Supabase.instance.client.rpc('is_admin');
      if (mounted && isAdminRes == true) {
        setState(() => _isAdmin = true);
      }
    } catch (_) {}
  }

  void _subscribeToRealtime() {
    try {
      _realtimeChannel = Supabase.instance.client
          .channel('public:telemetry')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'day_readings',
        callback: (payload) {
          _handleIncomingTelemetryPayload(Map<String, dynamic>.from(payload.newRecord));
        },
      )
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'compost_piles',
        callback: (payload) {
          _fetchCompostPilesAndReadings(silent: true);
        },
      )
          .subscribe();
    } catch (_) {}
  }

  void _handleIncomingTelemetryPayload(Map<String, dynamic> recordMap) {
    final newReading = DayReading.fromMap(recordMap);

    if (_activeReadingPileUuid != null && newReading.pileId == _activeReadingPileUuid) {
      if (newReading.createdAt != null &&
          _getReadingsStartTime != null &&
          newReading.createdAt!.isBefore(_getReadingsStartTime!)) {
        return;
      }

      if (_lastReceivedReading != null &&
          _lastReceivedReading!.temp == newReading.temp &&
          _lastReceivedReading!.moisture == newReading.moisture &&
          _lastReceivedReading!.createdAt != null &&
          newReading.createdAt != null &&
          newReading.createdAt!.difference(_lastReceivedReading!.createdAt!).inSeconds.abs() < 30) {
        return;
      }

      _lastReceivedReading = newReading;
      _activeReadingPileUuid = null;
    }

    _fetchCompostPilesAndReadings(silent: true);
  }

  Future<void> _handleGetReadingsClicked(CompostPile pile) async {
    setState(() => _activeReadingPileUuid = pile.id);
    try {
      final rows = await Supabase.instance.client
          .from('day_readings')
          .select()
          .eq('pile_id', pile.id)
          .order('created_at', ascending: true);

      // Refresh the pile list so its latest sensor values and history are rebuilt
      // from the same database records shown on the detail screen.
      await _fetchCompostPilesAndReadings(silent: true);
      if (!mounted) return;
      final count = (rows as List).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count == 0
              ? 'No readings are stored for ${pile.displayName} yet.'
              : 'Retrieved $count database reading${count == 1 ? '' : 's'} for ${pile.displayName}.'),
          backgroundColor: const Color(0xFF1B3B2B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not retrieve readings: $e'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _activeReadingPileUuid = null);
    }
  }

  Future<void> _fetchCompostPilesAndReadings({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingPiles = true;
        _errorMessage = null;
      });
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id;

      if (userId == null) {
        setState(() {
          _isLoadingPiles = false;
          piles = [];
          _selectedPileUuid = null;
        });
        return;
      }

      // Query compost_piles belonging strictly to the authenticated user
      final dynamic pileRows = await Supabase.instance.client
          .from('compost_piles')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      List<CompostPile> fetchedPiles = [];

      if (pileRows != null && (pileRows as List).isNotEmpty) {
        for (var pMap in (pileRows as List)) {
          final pileMap = Map<String, dynamic>.from(pMap as Map);
          final pileId = pileMap['id'].toString();

          // Query day_readings strictly using pile_id UUID
          final dynamic readingRows = await Supabase.instance.client
              .from('day_readings')
              .select()
              .eq('pile_id', pileId)
              .order('created_at', ascending: true);

          List<DayReading> history = [];
          if (readingRows != null && (readingRows as List).isNotEmpty) {
            history = (readingRows as List)
                .map((r) => DayReading.fromMap(Map<String, dynamic>.from(r as Map)))
                .toList();
          }

          fetchedPiles.add(CompostPile.fromMap(pileMap, historyReadings: history));
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final savedUuid = prefs.getString('selected_compost_pile_uuid');

      String? validatedUuid;
      if (fetchedPiles.isNotEmpty) {
        bool isValid = savedUuid != null && fetchedPiles.any((p) => p.id == savedUuid);
        if (isValid) {
          validatedUuid = savedUuid;
        } else {
          validatedUuid = fetchedPiles.first.id;
          await prefs.setString('selected_compost_pile_uuid', validatedUuid);
        }
      } else {
        validatedUuid = null;
        await prefs.remove('selected_compost_pile_uuid');
      }

      if (mounted) {
        setState(() {
          piles = fetchedPiles;
          _selectedPileUuid = validatedUuid;
          _isLoadingPiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Database sync error: ${e.toString()}';
          _isLoadingPiles = false;
        });
      }
    }
  }

  void _checkAndTriggerReadinessAlerts() {
    // A five-reading milestone is a data-count notification, not a maturity claim.
    // Compost maturity must not be inferred from elapsed days alone.
    for (final pile in piles) {
      if (pile.history.length >= 5 && !_notified5DayPiles.contains(pile.id)) {
        _notified5DayPiles.add(pile.id);
        try {
          _notificationChannel.invokeMethod('show5DayMilestone', {'pileName': pile.displayName});
        } catch (_) {}
      }
    }
  }

  // Create Pile Form (EXACTLY 3 FIELDS: Pile Number, Name, Category)
  void _openAddPileModal() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create a compost pile.')),
      );
      return;
    }

    int suggestedNumber = 1;
    try {
      final reservedRows = await Supabase.instance.client
          .from('reserved_pile_numbers')
          .select('pile_number')
          .eq('user_id', user.id);

      if (reservedRows != null && (reservedRows as List).isNotEmpty) {
        int maxNum = 0;
        for (var r in (reservedRows as List)) {
          final pNum = int.tryParse(r['pile_number'].toString()) ?? 0;
          if (pNum > maxNum) maxNum = pNum;
        }
        suggestedNumber = maxNum + 1;
      } else if (piles.isNotEmpty) {
        int maxNum = 0;
        for (var p in piles) {
          if (p.pileNumber != null && p.pileNumber! > maxNum) {
            maxNum = p.pileNumber!;
          }
        }
        suggestedNumber = maxNum + 1;
      }
    } catch (_) {}

    final pileNumberController = TextEditingController(text: suggestedNumber.toString());
    final nameController = TextEditingController();
    final categoryController = TextEditingController();

    if (!mounted) return;

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
              const SizedBox(height: 4),
              const Text('Start with Pile ID 1 if this is your first compost pile.', style: TextStyle(fontSize: 12, color: Color(0xFF00A896), fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),

              // 1. Pile Number
              TextField(
                controller: pileNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '1. Numeric Pile ID (e.g. 1, 2, 3)',
                  hintText: '1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Pile Name
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '2. Pile Name (e.g. Maize Stalks)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              // 3. Category
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: '3. Compost Category (e.g. Agricultural Refuse)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3B2B), minimumSize: const Size(double.infinity, 50)),
                onPressed: () async {
                  final rawNumber = pileNumberController.text.trim();
                  final enteredNumber = int.tryParse(rawNumber);

                  if (enteredNumber == null || enteredNumber <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid Pile ID. Enter a positive whole number greater than zero.')),
                    );
                    return;
                  }

                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a name for your compost pile.')),
                    );
                    return;
                  }

                  try {
                    // Exclusive RPC creation procedure
                    await Supabase.instance.client.rpc(
                      'create_compost_pile_with_reservation',
                      params: {
                        'p_pile_number': enteredNumber,
                        'p_name': nameController.text.trim(),
                        'p_category': categoryController.text.trim().isEmpty ? 'General Waste' : categoryController.text.trim(),
                      },
                    );

                    await _fetchCompostPilesAndReadings();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Compost Pile #$enteredNumber created successfully!'), backgroundColor: const Color(0xFF1B3B2B)),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      String errorMsg = e.toString();
                      if (errorMsg.contains('already been used') ||
                          errorMsg.contains('reserved_pile_numbers_user_pile_key') ||
                          errorMsg.contains('compost_piles_user_pile_key') ||
                          errorMsg.contains('duplicate key')) {
                        errorMsg = 'Pile ID #$enteredNumber has already been used on your account. Please choose a different numeric ID.';
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 4)),
                      );
                    }
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
        isLoading: _isLoadingPiles,
        activeReadingPileUuid: _activeReadingPileUuid,
        onGetReadingsClicked: _handleGetReadingsClicked,
        onRefresh: _fetchCompostPilesAndReadings,
        onPileUpdated: () => _fetchCompostPilesAndReadings(silent: true),
        onOpenDetail: (pile) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PileDetailScreen(pile: pile, onRefreshNeeded: _fetchCompostPilesAndReadings)));
        },
      ),
      PilesTabScreen(
        piles: activePiles,
        isLoading: _isLoadingPiles,
        onRefresh: _fetchCompostPilesAndReadings,
        onOpenDetail: (pile) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PileDetailScreen(pile: pile, onRefreshNeeded: _fetchCompostPilesAndReadings)));
        },
      ),
      TrendsScreen(piles: piles),
      AlertsScreen(alerts: alertsList),
      ArchivesScreen(archivedPiles: archivedPiles, activePiles: activePiles),
      SettingsScreen(isAdmin: _isAdmin),
    ];

    return Scaffold(
      appBar: _isAdmin
          ? AppBar(
        backgroundColor: const Color(0xFF1B3B2B),
        elevation: 0,
        title: const Text('CompostWise Mobile', style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.admin_panel_settings, color: Color(0xFF81E6D9)),
            label: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
            },
          ),
        ],
      )
          : null,
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
// 5. HOME SCREEN WITH REALTIME USER PILES & EMPTY STATE
// ==========================================
class HomeScreen extends StatelessWidget {
  final List<CompostPile> piles;
  final bool isLoading;
  final String? activeReadingPileUuid;
  final Function(CompostPile)? onGetReadingsClicked;
  final Future<void> Function() onRefresh;
  final VoidCallback onPileUpdated;
  final Function(CompostPile) onOpenDetail;

  const HomeScreen({
    super.key,
    required this.piles,
    this.isLoading = false,
    this.activeReadingPileUuid,
    this.onGetReadingsClicked,
    required this.onRefresh,
    required this.onPileUpdated,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    int needsAttentionCount = piles.where((p) => p.status != StatusLevel.onTrack).length;

    String displayName = 'Farmer';
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final metaName = user.userMetadata?['full_name'];
        if (metaName != null && metaName.toString().trim().isNotEmpty) {
          displayName = metaName.toString().trim();
        } else if (user.email != null && user.email!.isNotEmpty) {
          displayName = user.email!.split('@').first;
        }
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F5),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          color: const Color(0xFF1B3B2B),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      Text(getRealtimeGreeting(displayName), style: const TextStyle(fontFamily: 'Serif', color: Colors.white, fontSize: 22)),
                      const SizedBox(height: 2),
                      Text('${piles.length} active piles monitored', style: const TextStyle(color: Color(0xFF81E6D9), fontSize: 13)),
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

                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF1B3B2B))),
                        )
                      else if (piles.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.eco_outlined, size: 64, color: Color(0xFF1B3B2B)),
                                const SizedBox(height: 16),
                                const Text('No active compost piles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
                                const SizedBox(height: 6),
                                Text('Tap the + button below to add your first compost pile.', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                              ],
                            ),
                          ),
                        )
                      else
                        ...piles.map((pile) => _buildPileCard(context, pile)),
                    ],
                  ),
                ),
              ],
            ),
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
                  Text(pile.displayName, style: const TextStyle(fontFamily: 'Serif', color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category: ${pile.category}', style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568))),
                          const SizedBox(height: 2),
                          Text('Started: ${_formatDate(pile.startDate)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeReadingPileUuid == pile.id ? const Color(0xFF00A896) : const Color(0xFF1B3B2B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: activeReadingPileUuid == null
                            ? (onGetReadingsClicked != null ? () => onGetReadingsClicked!(pile) : null)
                            : null,
                        child: activeReadingPileUuid == pile.id
                            ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 10, height: 10, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 4),
                            Text('Listening...', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        )
                            : const Text('Get Readings', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricTile('Temperature', pile.tempDisplay, metricColor),
                      _buildMetricTile('Moisture', pile.moistureDisplay, metricColor),
                      _buildMetricTile('pH Level', pile.phDisplay, metricColor),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ==========================================
// 6. DETAILED PILE BREAKDOWN & HISTORY SCREEN WITH GET READINGS
// ==========================================
class PileDetailScreen extends StatefulWidget {
  final CompostPile pile;
  final Future<void> Function()? onRefreshNeeded;

  const PileDetailScreen({super.key, required this.pile, this.onRefreshNeeded});

  @override
  State<PileDetailScreen> createState() => _PileDetailScreenState();
}

class _PileDetailScreenState extends State<PileDetailScreen> {
  bool _isLoadingReadings = false;
  String? _errorMessage;
  List<DayReading> _readingsList = [];

  @override
  void initState() {
    super.initState();
    _readingsList = widget.pile.history;
    _fetchReadingsFromSupabase();
  }

  Future<void> _fetchReadingsFromSupabase() async {
    if (!mounted) return;
    setState(() {
      _isLoadingReadings = true;
      _errorMessage = null;
    });

    try {
      final dynamic rows = await Supabase.instance.client
          .from('day_readings')
          .select()
          .eq('pile_id', widget.pile.id)
          .order('created_at', ascending: false);

      List<DayReading> fetched = [];
      if (rows != null && (rows as List).isNotEmpty) {
        fetched = (rows as List)
            .map((r) => DayReading.fromMap(Map<String, dynamic>.from(r as Map)))
            .toList();
      }

      if (mounted) {
        setState(() {
          _readingsList = fetched;
          _isLoadingReadings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load readings: ${e.toString()}';
          _isLoadingReadings = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pile = widget.pile;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B2B),
        title: Text(pile.displayName, style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Readings',
            onPressed: _fetchReadingsFromSupabase,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pile.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
                    const SizedBox(height: 4),
                    Text('Category: ${pile.category}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    Text('Started: ${pile.startDate.toLocal().toString().split(' ').first}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryBox('Temperature', pile.tempDisplay, const Color(0xFF1B3B2B)),
                        _buildSummaryBox('Moisture', pile.moistureDisplay, const Color(0xFF1B3B2B)),
                        _buildSummaryBox('pH Level', pile.phDisplay, const Color(0xFF1B3B2B)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Get Readings Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B3B2B),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isLoadingReadings
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.download, color: Colors.white),
              label: Text(
                _isLoadingReadings ? 'Retrieving Records...' : 'Get Readings from Database',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: _isLoadingReadings ? null : _fetchReadingsFromSupabase,
            ),
            const SizedBox(height: 20),

            const Text('Historical Sensor Readings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
            const SizedBox(height: 10),

            if (_isLoadingReadings)
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: Color(0xFF1B3B2B))))
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: _fetchReadingsFromSupabase, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_readingsList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                    child: Text(
                      'No sensor readings available for this compost pile yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              else
                ..._readingsList.map((reading) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('Date: ${reading.dateStr}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(
                      'Temp: ${reading.tempDisplay}  |  Moisture: ${reading.moistureDisplay}  |  pH: ${reading.phDisplay}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text('Day ${reading.day}', style: const TextStyle(color: Color(0xFF00A896), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ==========================================
// 7. OTHER MOBILE TABS
// ==========================================
class PilesTabScreen extends StatelessWidget {
  final List<CompostPile> piles;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Function(CompostPile) onOpenDetail;

  const PilesTabScreen({
    super.key,
    required this.piles,
    this.isLoading = false,
    required this.onRefresh,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Compost Piles', style: TextStyle(fontFamily: 'Serif', color: Colors.white)),
        backgroundColor: const Color(0xFF1B3B2B),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B3B2B)))
            : piles.isEmpty
            ? const Center(child: Text('No active compost piles.', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: piles.length,
          itemBuilder: (context, index) {
            final pile = piles[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(pile.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Category: ${pile.category} | Temp: ${pile.tempDisplay}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => onOpenDetail(pile),
              ),
            );
          },
        ),
      ),
    );
  }
}

class TrendsScreen extends StatelessWidget {
  final List<CompostPile> piles;

  const TrendsScreen({super.key, required this.piles});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telemetry Analytics', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1B3B2B)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Platform Telemetry Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Total Piles Monitored: ${piles.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Temperature and moisture analytics reflect real readings fetched from Supabase.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertsScreen extends StatelessWidget {
  final List<CompostAlert> alerts;

  const AlertsScreen({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compost Alerts', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1B3B2B)),
      body: alerts.isEmpty
          ? const Center(child: Text('No unread alerts.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: alert.color, radius: 8),
              title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(alert.body),
              trailing: Text(alert.time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          );
        },
      ),
    );
  }
}

class ArchivesScreen extends StatelessWidget {
  final List<CompostPile> archivedPiles;
  final List<CompostPile> activePiles;

  const ArchivesScreen({super.key, required this.archivedPiles, required this.activePiles});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived Piles', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1B3B2B)),
      body: archivedPiles.isEmpty
          ? const Center(child: Text('No archived compost piles.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: archivedPiles.length,
        itemBuilder: (context, index) {
          final pile = archivedPiles[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(pile.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Category: ${pile.category} | Status: Completed'),
            ),
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final bool isAdmin;

  const SettingsScreen({super.key, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1B3B2B)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF1B3B2B)),
              title: Text(user?.email ?? 'Logged in User'),
              subtitle: Text(isAdmin ? 'Role: Administrator' : 'Role: Standard User'),
            ),
          ),
          if (isAdmin)
            Card(
              color: const Color(0xFFE6FFFA),
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF00A896)),
                title: const Text('Open Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
                },
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 8. ADMIN DASHBOARD MODULE (WEB & MOBILE RESPONSIVE)
// ==========================================
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedAdminTab = 0;
  bool _isLoading = true;
  bool _isAdminVerified = false;

  // Real Stats
  int _totalUsers = 0;
  int _totalPiles = 0;
  int _activePiles = 0;
  int _completedPiles = 0;
  int _totalReadings = 0;
  int _onlineDevices = 0;

  List<AdminAppUser> _usersList = [];
  List<CompostPile> _allPilesList = [];
  List<DayReading> _allReadingsList = [];
  List<AdminDeviceNode> _devicesList = [];
  List<AdminAuditLog> _auditLogsList = [];

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final dynamic isAdminRes = await Supabase.instance.client.rpc('is_admin');
      if (isAdminRes != true) {
        if (mounted) setState(() { _isAdminVerified = false; _isLoading = false; });
        return;
      }
      _isAdminVerified = true;

      // Load core datasets independently. An optional table (devices/audit_logs/
      // user_roles) being absent must not prevent piles and readings from loading.
      List<dynamic> pileRows = [];
      List<dynamic> readingRows = [];
      List<dynamic> deviceRows = [];
      List<dynamic> auditRows = [];
      List<dynamic> roleRows = [];

      try { pileRows = await Supabase.instance.client.from('compost_piles').select(); } catch (_) {}
      try { readingRows = await Supabase.instance.client.from('day_readings').select().order('created_at', ascending: false); } catch (_) {}
      try { deviceRows = await Supabase.instance.client.from('devices').select(); } catch (_) {}
      try { auditRows = await Supabase.instance.client.from('audit_logs').select().order('created_at', ascending: false); } catch (_) {}
      try { roleRows = await Supabase.instance.client.from('user_roles').select(); } catch (_) {}

      final loadedPiles = pileRows
          .map((p) => CompostPile.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList();
      final loadedReadings = readingRows
          .map((r) => DayReading.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();

      final loadedDevices = <AdminDeviceNode>[];
      for (final d in deviceRows) {
        final dMap = Map<String, dynamic>.from(d as Map);
        final lastSeenDt = dMap['last_seen'] == null ? null : DateTime.tryParse(dMap['last_seen'].toString());
        final isOnline = lastSeenDt != null && DateTime.now().difference(lastSeenDt).inMinutes < 5;
        loadedDevices.add(AdminDeviceNode(
          id: dMap['id']?.toString() ?? '',
          deviceCode: dMap['device_code']?.toString() ?? 'Unknown device',
          pileId: dMap['pile_id']?.toString(),
          lastSeen: lastSeenDt,
          isOnline: isOnline,
        ));
      }

      final loadedAudits = <AdminAuditLog>[];
      for (final a in auditRows) {
        final aMap = Map<String, dynamic>.from(a as Map);
        loadedAudits.add(AdminAuditLog(
          id: aMap['id']?.toString() ?? '',
          userId: aMap['user_id']?.toString(),
          action: aMap['action']?.toString() ?? 'SYSTEM_EVENT',
          targetType: aMap['target_type']?.toString(),
          targetId: aMap['target_id']?.toString(),
          details: aMap['details'] is Map ? Map<String, dynamic>.from(aMap['details'] as Map) : null,
          createdAt: aMap['created_at'] == null ? null : DateTime.tryParse(aMap['created_at'].toString()),
        ));
      }

      // The Supabase client must not query auth.users directly. Until a protected
      // admin RPC supplies email/name fields, show honest account identifiers only.
      final userIds = <String>{
        ...loadedPiles.where((p) => p.userId != null).map((p) => p.userId!),
        ...roleRows.where((r) => r['user_id'] != null).map((r) => r['user_id'].toString()),
      };
      final loadedUsers = userIds.map((uId) {
        final roleMatch = roleRows.where((r) => r['user_id']?.toString() == uId).toList();
        final roleStr = roleMatch.isNotEmpty ? (roleMatch.first['role']?.toString() ?? 'user') : 'user';
        return AdminAppUser(
          id: uId,
          email: 'Not available through the client API',
          fullName: 'Account ${uId.substring(0, uId.length < 8 ? uId.length : 8)}',
          role: roleStr,
          pileCount: loadedPiles.where((p) => p.userId == uId).length,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _allPilesList = loadedPiles;
          _allReadingsList = loadedReadings;
          _devicesList = loadedDevices;
          _auditLogsList = loadedAudits;
          _usersList = loadedUsers;
          _totalUsers = loadedUsers.length;
          _totalPiles = loadedPiles.length;
          _activePiles = loadedPiles.where((p) => !p.isArchived).length;
          _completedPiles = loadedPiles.where((p) => p.isArchived).length;
          _totalReadings = loadedReadings.length;
          _onlineDevices = loadedDevices.where((d) => d.isOnline).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Admin dashboard could not load: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _exportCSVReport(String filename, List<List<String>> rows) async {
    String escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';
    final csvContent = rows.map((row) => row.map(escapeCsv).join(',')).join('\r\n');
    try {
      final directory = await getTemporaryDirectory();
      final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File('${directory.path}/$safeName');
      await file.writeAsString(csvContent, flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv', name: safeName)], text: safeName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV export failed: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B3B2B),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (!_isAdminVerified) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied'), backgroundColor: Colors.red.shade800),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Administrator Access Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Your account does not have administrator privileges.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Application')),
            ],
          ),
        ),
      );
    }

    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B2B),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Color(0xFF81E6D9)),
            SizedBox(width: 8),
            Text('Smart Compost Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchAdminData),
        ],
      ),
      body: Row(
        children: [
          if (isWideScreen)
            NavigationRail(
              backgroundColor: const Color(0xFF1B3B2B),
              selectedIndex: _selectedAdminTab,
              onDestinationSelected: (idx) => setState(() => _selectedAdminTab = idx),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: Color(0xFF81E6D9)),
              unselectedIconTheme: const IconThemeData(color: Colors.white60),
              selectedLabelTextStyle: const TextStyle(color: Color(0xFF81E6D9), fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white60, fontSize: 11),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Overview')),
                NavigationRailDestination(icon: Icon(Icons.people), label: Text('Users')),
                NavigationRailDestination(icon: Icon(Icons.layers), label: Text('Piles')),
                NavigationRailDestination(icon: Icon(Icons.sensors), label: Text('Sensors')),
                NavigationRailDestination(icon: Icon(Icons.developer_board), label: Text('Devices')),
                NavigationRailDestination(icon: Icon(Icons.history), label: Text('Audit Logs')),
                NavigationRailDestination(icon: Icon(Icons.analytics), label: Text('Reports')),
              ],
            ),
          Expanded(
            child: Column(
              children: [
                if (!isWideScreen)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildNavChip(0, 'Overview', Icons.dashboard),
                        _buildNavChip(1, 'Users', Icons.people),
                        _buildNavChip(2, 'Piles', Icons.layers),
                        _buildNavChip(3, 'Sensors', Icons.sensors),
                        _buildNavChip(4, 'Devices', Icons.developer_board),
                        _buildNavChip(5, 'Audit Logs', Icons.history),
                        _buildNavChip(6, 'Reports', Icons.analytics),
                      ],
                    ),
                  ),
                Expanded(child: _buildAdminTabContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavChip(int index, String label, IconData icon) {
    final isSelected = _selectedAdminTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF1B3B2B)),
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1B3B2B), fontSize: 12)),
        selected: isSelected,
        selectedColor: const Color(0xFF1B3B2B),
        onSelected: (_) => setState(() => _selectedAdminTab = index),
      ),
    );
  }

  Widget _buildAdminTabContent() {
    switch (_selectedAdminTab) {
      case 0: return _buildOverviewTab();
      case 1: return _buildUsersTab();
      case 2: return _buildPilesTab();
      case 3: return _buildSensorsTab();
      case 4: return _buildDevicesTab();
      case 5: return _buildAuditLogsTab();
      case 6: return _buildReportsTab();
      default: return _buildOverviewTab();
    }
  }

  // 1. Overview Tab
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Overview & Realtime Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
          const SizedBox(height: 16),

          // Stat Cards Grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatCard('Total Users', '$_totalUsers', Icons.people, const Color(0xFF1B3B2B)),
              _buildStatCard('Total Piles', '$_totalPiles', Icons.layers, const Color(0xFF00A896)),
              _buildStatCard('Active Piles', '$_activePiles', Icons.eco, Colors.green.shade700),
              _buildStatCard('Completed Piles', '$_completedPiles', Icons.check_circle, Colors.teal.shade800),
              _buildStatCard('Sensor Readings', '$_totalReadings', Icons.query_stats, Colors.blue.shade800),
              _buildStatCard('Online ESP32s', '$_onlineDevices', Icons.wifi, Colors.purple.shade800),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Activity Log
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Platform Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
                  const SizedBox(height: 12),
                  if (_auditLogsList.isEmpty)
                    const Text('No recent audit log entries.', style: TextStyle(color: Colors.grey, fontSize: 13))
                  else
                    ..._auditLogsList.take(5).map((log) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, color: Color(0xFF1B3B2B), size: 20),
                      title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      subtitle: Text('Target: ${log.targetType ?? "System"} | ${log.createdAt?.toLocal().toString().split(".").first ?? "Just now"}'),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // 2. Users Tab
  Widget _buildUsersTab() {
    final filteredUsers = _usersList.where((u) => u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) || u.email.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Registered Users Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3B2B)),
                icon: const Icon(Icons.download, color: Colors.white, size: 16),
                label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () {
                  final rows = [['User ID', 'Role', 'Pile Count']];
                  for (var u in _usersList) {
                    rows.add([u.id, u.role, u.pileCount.toString()]);
                  }
                  _exportCSVReport('Registered_Users_Report.csv', rows);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            decoration: InputDecoration(
              hintText: 'Search accounts by ID or role...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 16),

          if (filteredUsers.isEmpty)
            const Center(child: Text('No users found.', style: TextStyle(color: Colors.grey)))
          else
            ...filteredUsers.map((u) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: u.role == 'admin' ? Colors.purple : const Color(0xFF1B3B2B), child: Icon(u.role == 'admin' ? Icons.admin_panel_settings : Icons.person, color: Colors.white, size: 18)),
                title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Account ID: ${u.id} | Role: ${u.role.toUpperCase()}\nEmail: ${u.email}'),
                trailing: Chip(label: Text('${u.pileCount} Piles', style: const TextStyle(fontSize: 11)), backgroundColor: const Color(0xFFE6FFFA)),
              ),
            )),
        ],
      ),
    );
  }

  // 3. Piles Tab
  Widget _buildPilesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('All Platform Compost Piles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3B2B)),
                icon: const Icon(Icons.download, color: Colors.white, size: 16),
                label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () {
                  final rows = [['Pile UUID', 'Pile #', 'Name', 'Category', 'User ID', 'Archived']];
                  for (var p in _allPilesList) {
                    rows.add([p.id, p.pileNumber?.toString() ?? '', p.name, p.category, p.userId ?? '', p.isArchived.toString()]);
                  }
                  _exportCSVReport('All_Compost_Piles_Report.csv', rows);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_allPilesList.isEmpty)
            const Center(child: Text('No compost piles found in database.', style: TextStyle(color: Colors.grey)))
          else
            ..._allPilesList.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: getHeaderColor(p.status), child: Text('#${p.pileNumber ?? "?"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                title: Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Category: ${p.category} | Temp: ${p.tempDisplay} | Owner: ${p.userId == null ? 'Unknown' : p.userId!.substring(0, p.userId!.length < 8 ? p.userId!.length : 8)}...'),
                trailing: Chip(label: Text(getStatusLabel(p.status), style: TextStyle(color: getBadgeTextColor(p.status), fontSize: 10)), backgroundColor: getBadgeBgColor(p.status)),
              ),
            )),
        ],
      ),
    );
  }

  // 4. Sensors Tab
  Widget _buildSensorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sensor Telemetry Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3B2B)),
                icon: const Icon(Icons.download, color: Colors.white, size: 16),
                label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () {
                  final rows = [['Reading ID', 'Pile UUID', 'Temp (°C)', 'Moisture ADC', 'pH', 'Date Logged']];
                  for (var r in _allReadingsList) {
                    rows.add([r.id?.toString() ?? '', r.pileId ?? '', r.tempDisplay, r.moistureDisplay, r.phDisplay, r.dateStr]);
                  }
                  _exportCSVReport('Sensor_Telemetry_Logs.csv', rows);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_allReadingsList.isEmpty)
            const Center(child: Text('No sensor telemetry logs found.', style: TextStyle(color: Colors.grey)))
          else
            ..._allReadingsList.map((r) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text('Pile UUID: ${r.pileId ?? "Unknown"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                subtitle: Text('Temp: ${r.tempDisplay}  |  Moisture: ${r.moistureDisplay}  |  pH: ${r.phDisplay}'),
                trailing: Text(r.dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            )),
        ],
      ),
    );
  }

  // 5. Devices Tab
  Widget _buildDevicesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ESP32 IoT Node Monitoring', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
          const SizedBox(height: 16),

          if (_devicesList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Center(
                child: Text('No registered ESP32 devices found in public.devices table.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            ..._devicesList.map((d) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.developer_board, color: d.isOnline ? Colors.green : Colors.grey),
                title: Text('Device Code: ${d.deviceCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Target Pile: ${d.pileId ?? "Unassigned"} | Last Seen: ${d.lastSeen?.toLocal().toString().split(".").first ?? "Never"}'),
                trailing: Chip(
                  label: Text(d.isOnline ? 'Online' : 'Offline', style: TextStyle(color: d.isOnline ? Colors.green.shade900 : Colors.grey.shade800, fontSize: 10)),
                  backgroundColor: d.isOnline ? Colors.green.shade100 : Colors.grey.shade200,
                ),
              ),
            )),
        ],
      ),
    );
  }

  // 6. Audit Logs Tab
  Widget _buildAuditLogsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security Audit Trail & Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
          const SizedBox(height: 16),

          if (_auditLogsList.isEmpty)
            const Center(child: Text('No audit logs recorded.', style: TextStyle(color: Colors.grey)))
          else
            ..._auditLogsList.map((a) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.shield, color: Color(0xFF1B3B2B)),
                title: Text(a.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('User ID: ${a.userId ?? "System"} | Details: ${a.details ?? {}}'),
                trailing: Text(a.createdAt?.toLocal().toString().split(".").first ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            )),
        ],
      ),
    );
  }

  // 7. Reports Tab
  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CSV Reports & Platform Export Engine', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available System CSV Exports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.people, color: Color(0xFF1B3B2B)),
                    title: const Text('Export Registered Users Report'),
                    trailing: const Icon(Icons.download),
                    onTap: () {
                      final rows = [['User ID', 'Role', 'Pile Count']];
                      for (var u in _usersList) {
                        rows.add([u.id, u.role, u.pileCount.toString()]);
                      }
                      _exportCSVReport('Users_Report.csv', rows);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.layers, color: Color(0xFF1B3B2B)),
                    title: const Text('Export Compost Piles Summary Report'),
                    trailing: const Icon(Icons.download),
                    onTap: () {
                      final rows = [['Pile UUID', 'Pile #', 'Name', 'Category', 'User ID', 'Archived']];
                      for (var p in _allPilesList) {
                        rows.add([p.id, p.pileNumber?.toString() ?? '', p.name, p.category, p.userId ?? '', p.isArchived.toString()]);
                      }
                      _exportCSVReport('Compost_Piles_Summary.csv', rows);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.sensors, color: Color(0xFF1B3B2B)),
                    title: const Text('Export All Sensor Telemetry Logs'),
                    trailing: const Icon(Icons.download),
                    onTap: () {
                      final rows = [['Reading ID', 'Pile UUID', 'Temp (°C)', 'Moisture ADC', 'pH', 'Date Logged']];
                      for (var r in _allReadingsList) {
                        rows.add([r.id?.toString() ?? '', r.pileId ?? '', r.tempDisplay, r.moistureDisplay, r.phDisplay, r.dateStr]);
                      }
                      _exportCSVReport('All_Sensor_Telemetry_Logs.csv', rows);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Single Pile PDF Engine
Future<File> generateSinglePilePdfReport(CompostPile pile) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.5, color: PdfColors.green800)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Smart Compost Monitoring System', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    pw.Text('Individual Pile Telemetry Report', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(DateTime.now().toLocal().toString().split(' ').first, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(pile.displayName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
          pw.Text('Category: ${pile.category}', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          if (pile.history.isEmpty)
            pw.Text('No historical logs recorded for this pile.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              cellHeight: 20,
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headers: ['Date Logged', 'Day #', 'Temp (°C)', 'Moisture (ADC)', 'pH Level'],
              data: pile.history.map((r) => [r.dateStr, 'Day ${r.day}', r.tempDisplay, r.moistureDisplay, r.phDisplay]).toList(),
            ),
        ];
      },
    ),
  );

  final output = await getTemporaryDirectory();
  final sanitizedName = pile.displayName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
  final file = File('${output.path}/${sanitizedName}_Report.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}
