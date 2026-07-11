import 'package:flutter/material.dart';

void main() {
  runApp(const CompostIQApp());
}

// ==========================================
// CENTRAL APPLICATION ROOT & THEME
// ==========================================
class CompostIQApp extends StatefulWidget {
  const CompostIQApp({super.key});

  @override
  State<CompostIQApp> createState() => _CompostIQAppState();
}

class _CompostIQAppState extends State<CompostIQApp> {
  bool _isEnglish = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Compost Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E352F),
          primary: const Color(0xFF1E352F),
          secondary: const Color(0xFFC68B59),
          surface: const Color(0xFFEFECE6),
          onSurface: const Color(0xFF1A1C1A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F6F0),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E352F), letterSpacing: -0.5),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF1A1C1A)),
        ),
      ),
      home: GetStartedScreen(
        isEnglish: _isEnglish,
        onLanguageChange: (val) => setState(() => _isEnglish = val)
      ),
    );
  }
}

// ==========================================
// TRANSLATION DICTIONARY ENGINE
// ==========================================
class AppStrings {
  static String get(String key, bool isEnglish) {
    final Map<String, Map<String, String>> localizedValues = {
      'appName': {'en': 'Smart Compost Monitor', 'bem': 'Icipanya ca Mufundo ca Smart'},
      'appPitch': {
        'en': 'Transform your organic waste into black gold. Track decomposition live with precision sensors, balance moisture, and know the exact moment your compost is ready to nourish your garden.',
        'bem': 'Alulani ifisoso fyenu ukuba umfundo mualuka uwasuma. Moneni umufundo ifyo ulepya pali fyonse nomba line, kabili ishibeni inshita fye nshita ilyo uliwama.'
      },
      'getStartedBtn': {'en': 'Get Started', 'bem': 'Tendekeni Pano'},
      'welcome': {'en': 'Welcome back!', 'bem': 'Mwapoleni na kabili!'},
      'loginSub': {'en': "Let's get back to tracking your compost pile.", 'bem': 'Katwalilile ukumona ifyo umbo lwenu lulepya.'},
      'signUpTitle': {'en': "Let's Get Started!", 'bem': 'Tuleenika Pano!'},
      'signUpSub': {'en': 'Start your journey to easy compost readiness monitoring!', 'bem': 'Tendekeni ukumona ifyo umbo lwenu lulepya bwino bwino!'},
      'email': {'en': 'Email Address', 'bem': 'Imisango ya Email'},
      'password': {'en': 'Password', 'bem': 'Inamba ya Cinfishe'},
      'loginBtn': {'en': 'Log In', 'bem': 'Ingileni'},
      'signUpBtn': {'en': 'Sign Up', 'bem': 'Lembesheni'},
      'google': {'en': 'Continue with Google', 'bem': 'Twalilileni na Google'},
      'toggleToSignUp': {'en': 'New here? Create an account', 'bem': 'Mulifya mupya? Pangeni akaundi'},
      'toggleToLogin': {'en': 'Already have an account? Log In', 'bem': 'Mulikwata akaundi? Ingileni'},
      'nameField': {'en': 'Your Name', 'bem': 'Ishina Lyenu'},
      'subGreeting': {'en': 'Your tracking overview looks excellent.', 'bem': 'Ifyo umbo lwenu lulepya fili bwino sana.'},
      'activeTag': {'en': 'Active Piles', 'bem': 'Imbo Shilebomba'},
      'overallStatus': {'en': 'Overall Readiness Status', 'bem': 'Ifyo Umbo Lulepya Lwata fyonse'},
      'healthyCooking': {'en': 'Healthy & Decaying Safely', 'bem': 'Lili bwino & Lilepya Bwino'},
      'liveConditions': {'en': 'Live Conditions (Swipe to view)', 'bem': 'Ifyo umbo luli pali nomba (Suntila kuli kulyo)'},
      'temp': {'en': 'Temperature', 'bem': 'Ukukaba kwa Umbo'},
      'moisture': {'en': 'Moisture Level', 'bem': 'Utunshi twa Munda'},
      'ph': {'en': 'pH Level Balance', 'bem': 'Ukuwama kwa Umba (pH)'},
      'aeration': {'en': 'Aeration Supply', 'bem': 'Umwela ulemoneka'},
      'optimal': {'en': 'Optimal', 'bem': 'Uwasuma'},
      'tipsTitle': {'en': 'Simple Action Tips', 'bem': 'Ifyo mufwile Ukucita Pano'},
      'tip1Title': {'en': 'The pile is a little too wet', 'bem': 'Umbo nalyatubika sana munda'},
      'tip1Desc': {
        'en': 'Toss in some dry crunchy leaves, twigs, or shredded cardboard to balance it out and absorb excess water.',
        'bem': 'Poosenimo amabula ya fyauma, utwicele, nangu amakatepa ya fyauma pa kuti yakope utunshi twacilamo.'
      },
      'historyTitle': {'en': 'Compost History', 'bem': 'Ifyalecitika Kale'},
      'historySub': {'en': 'Archive of fully processed compost piles transformed into organic soil.', 'bem': 'Imbo ishapya ishasanduka umfundo uwasuma uwa kulimina.'},
      'h1': {'en': 'Healthy Balance', 'bem': 'Lili Bwino Sana'},
      'alertsTitle': {'en': 'Alerts & Updates', 'bem': 'Ifisoso & Ifipya'},
      'alertsSub': {'en': 'Simple real-time advice for your compost pile.', 'bem': 'Amashwi aya kwafwa umbo lwenu pali nomba.'},
      'alert1Title': {'en': 'Moisture level is high', 'bem': 'Utunshi twacilamo munda'},
      'alert1Desc': {
        'en': 'Your compost pile is holding onto too much water. Add some dry leaves or cardboard to balance it out.',
        'bem': 'Umbo lyenu nalikwata amenshi ayengi. Bikenimo amabula ya fyauma nangu amakatepa pa kuti yaume.'
      },
      'settingsTitle': {'en': 'Settings', 'bem': 'Ukutantika'},
      'settingsSub': {'en': 'Logged in as', 'bem': 'Mwingile nga'},
      'langSection': {'en': 'App Language', 'bem': 'Ululimi lwa App'},
      'opt1': {'en': 'Edit Profile Details', 'bem': 'Alulani Ifya Kaundi'},
      'opt2': {'en': 'Security Options', 'bem': 'Ifya Cinfishe na Isentekelo'},
      'opt3': {'en': 'Help Center Support', 'bem': 'Ukwafwa na Masambililo'},
      'opt4': {'en': 'About Smart Compost Monitor', 'bem': 'Ifya Bashimika Pali App'},
      'logout': {'en': 'Log Out', 'bem': 'Fuminimo'},
    };
    return localizedValues[key]?[isEnglish ? 'en' : 'bem'] ?? key;
  }
}

// ==========================================
// SCREEN 0: GET STARTED ONBOARDING
// ==========================================
class GetStartedScreen extends StatelessWidget {
  final bool isEnglish;
  final ValueChanged<bool> onLanguageChange;

  const GetStartedScreen({super.key, required this.isEnglish, required this.onLanguageChange});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = isEnglish;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]
                  ),
                  child: const Icon(Icons.eco_rounded, size: 70, color: Color(0xFFF9F6F0)),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                AppStrings.get('appName', lang),
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 30, letterSpacing: -0.8),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  AppStrings.get('appPitch', lang),
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 15, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => WalkthroughTutorialScreen(isEnglish: isEnglish, onLanguageChange: onLanguageChange))
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(AppStrings.get('getStartedBtn', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("🌿 EN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Switch.adaptive(
                      value: !isEnglish,
                      activeColor: theme.colorScheme.secondary,
                      onChanged: (val) => onLanguageChange(!val),
                    ),
                    const Text("BEM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// NEW WALKTHROUGH TUTORIAL SYSTEM
// ==========================================
class WalkthroughTutorialScreen extends StatefulWidget {
  final bool isEnglish;
  final ValueChanged<bool> onLanguageChange;
  const WalkthroughTutorialScreen({super.key, required this.isEnglish, required this.onLanguageChange});

  @override
  State<WalkthroughTutorialScreen> createState() => _WalkthroughTutorialScreenState();
}

class _WalkthroughTutorialScreenState extends State<WalkthroughTutorialScreen> {
  int _currentStep = 0;
  final List<Map<String, dynamic>> _steps = [
    {
      "title": "Real-time Monitoring",
      "desc": "Track biological decomposition metric parameters instantly with telemetry sensor updates.",
      "icon": Icons.sensors_rounded
    },
    {
      "title": "Optimized Balancing",
      "desc": "Receive actionable data notifications when parameters like pH or nitrogen values fall out of balance.",
      "icon": Icons.balance_rounded
    },
    {
      "title": "Harvest Organic Gold",
      "desc": "Move completed organic piles automatically into your permanent history yields once fully cured.",
      "icon": Icons.compost_rounded
    }
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _steps[_currentStep];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen(isEnglish: widget.isEnglish, onLanguageChange: widget.onLanguageChange)));
                  },
                  child: const Text('Skip', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ),
              const Spacer(),
              Icon(current["icon"], size: 90, color: theme.colorScheme.secondary),
              const SizedBox(height: 40),
              Text(current["title"], style: theme.textTheme.displayLarge?.copyWith(fontSize: 24), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(current["desc"], style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.5), textAlign: TextAlign.center),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentStep == index ? 24 : 8,
                  decoration: BoxDecoration(color: _currentStep == index ? theme.colorScheme.primary : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                )),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  if (_currentStep < _steps.length - 1) {
                    setState(() => _currentStep++);
                  } else {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen(isEnglish: widget.isEnglish, onLanguageChange: widget.onLanguageChange)));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text(_currentStep == _steps.length - 1 ? 'Finish' : 'Next', style: const TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 1: LOGIN & AUTH INTEGRATION
// ==========================================
class LoginScreen extends StatefulWidget {
  final bool isEnglish;
  final ValueChanged<bool> onLanguageChange;

  const LoginScreen({super.key, required this.isEnglish, required this.onLanguageChange});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isSigningUp = false;
  final TextEditingController _nameController = TextEditingController(text: "Ayanokoji");

  void _executeAuthentication(String finalName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainNavigationController(
          userName: finalName,
          isEnglish: widget.isEnglish,
          onLanguageChange: widget.onLanguageChange,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = widget.isEnglish;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        height: 75,
                        width: 75,
                        decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(22)),
                        child: const Icon(Icons.eco_rounded, size: 40, color: Color(0xFFF9F6F0)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.get('appName', lang),
                      style: theme.textTheme.displayLarge?.copyWith(fontSize: 20, color: theme.colorScheme.primary.withOpacity(0.8)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      AppStrings.get(_isSigningUp ? 'signUpTitle' : 'welcome', lang),
                      style: theme.textTheme.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.get(_isSigningUp ? 'signUpSub' : 'loginSub', lang),
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 15, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    if (_isSigningUp) ...[
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: AppStrings.get('nameField', lang),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      decoration: InputDecoration(
                        labelText: AppStrings.get('email', lang),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: AppStrings.get('password', lang),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => _executeAuthentication(_nameController.text),
                      style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      child: Text(AppStrings.get(_isSigningUp ? 'signUpBtn' : 'loginBtn', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),

                    OutlinedButton(
                      onPressed: () => _executeAuthentication("Google Native User"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: Colors.white.withOpacity(0.7),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.redAccent),
                          const SizedBox(width: 4),
                          Text(AppStrings.get('google', lang), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _isSigningUp = !_isSigningUp),
                      child: Text(
                        AppStrings.get(_isSigningUp ? 'toggleToLogin' : 'toggleToSignUp', lang),
                        style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    const Spacer(),

                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("🌿 EN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Switch.adaptive(
                            value: !widget.isEnglish,
                            activeColor: theme.colorScheme.secondary,
                            onChanged: (val) => widget.onLanguageChange(!val),
                          ),
                          const Text("BEM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                    ),
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

// ==========================================
// CENTRAL NAVIGATION CONTROL ENGINE
// ==========================================
class MainNavigationController extends StatefulWidget {
  final String userName;
  final bool isEnglish;
  final ValueChanged<bool> onLanguageChange;

  const MainNavigationController({
    super.key,
    required this.userName,
    required this.isEnglish,
    required this.onLanguageChange
  });

  @override
  State<MainNavigationController> createState() => _MainNavigationControllerState();
}

class _MainNavigationControllerState extends State<MainNavigationController> {
  int _activeTab = 0;

  List<Map<String, dynamic>> activeCompostPiles = [
    {"name": "Backyard Food Scraps", "type": "Kitchen Greens", "weight": "45", "date": "Started 3 weeks ago", "isStarred": true}
  ];

  List<Map<String, dynamic>> readyCompostHistory = [
    {"name": "Front Lawn Grass Pile", "date": "Completed 2 days ago", "details": "Yielded 40kg Harvested Soil"}
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<Widget> viewports = [
      HomeScreen(
        userName: widget.userName,
        isEnglish: widget.isEnglish,
        activePiles: activeCompostPiles,
        onMarkAsReady: (index) {
          setState(() {
            var completedPile = activeCompostPiles.removeAt(index);
            readyCompostHistory.insert(0, {
              "name": completedPile["name"]!,
              "date": "Completed Just Now",
              "details": "Yielded ${completedPile["weight"]}kg Premium Cured Biomass"
            });
          });
        },
        onToggleStar: (index) {
          setState(() {
            activeCompostPiles[index]["isStarred"] = !(activeCompostPiles[index]["isStarred"] as bool);
          });
        },
      ),
      HistoryScreen(isEnglish: widget.isEnglish, historyPiles: readyCompostHistory),
      AlertsScreen(isEnglish: widget.isEnglish),
      SettingsScreen(userName: widget.userName, isEnglish: widget.isEnglish, onLanguageChange: widget.onLanguageChange),
    ];

    return Scaffold(
      body: viewports[_activeTab],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEnhancedAddCompostModal(context),
        backgroundColor: theme.colorScheme.primary,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        height: 76,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLabeledTabItem(index: 0, label: widget.isEnglish ? 'Home' : 'Pano', icon: Icons.home_rounded, theme: theme),
            _buildLabeledTabItem(index: 1, label: widget.isEnglish ? 'History' : 'Kale', icon: Icons.history_rounded, theme: theme),
            const SizedBox(width: 40),
            _buildLabeledTabItem(index: 2, label: widget.isEnglish ? 'Alerts' : 'Ifisoso', icon: Icons.notifications_rounded, theme: theme),
            _buildLabeledTabItem(index: 3, label: widget.isEnglish ? 'Settings' : 'Imisango', icon: Icons.settings_rounded, theme: theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledTabItem({required int index, required String label, required IconData icon, required ThemeData theme}) {
    final bool isSelected = _activeTab == index;
    final Color itemColor = isSelected ? theme.colorScheme.primary : Colors.grey.shade400;

    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: itemColor, size: 24),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: itemColor, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  void _showEnhancedAddCompostModal(BuildContext context) {
    final theme = Theme.of(context);
    final nameController = TextEditingController();
    final weightController = TextEditingController();
    String currentTypeSelection = 'Kitchen Greens (Nitrogen-Rich)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Map New Monitor Matrix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Pile Reference Designation', filled: true, fillColor: theme.colorScheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Initial Input Biomass Weight (kg)', filled: true, fillColor: theme.colorScheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(14)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentTypeSelection,
                        isExpanded: true,
                        items: ['Kitchen Greens (Nitrogen-Rich)', 'Brown Cardboard/Dry Leaves (Carbon-Rich)', 'Mixed Agricultural Biomass']
                            .map((String val) => DropdownMenuItem<String>(value: val, child: Text(val, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => currentTypeSelection = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty) {
                        setState(() {
                          activeCompostPiles.add({
                            "name": nameController.text,
                            "type": currentTypeSelection.split(' ')[0],
                            "weight": weightController.text.isEmpty ? "0" : weightController.text,
                            "date": "Just Now",
                            "isStarred": false
                          });
                        });
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text('Initialize Tracking', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }
}

// ==========================================
// SCREEN 2: HOME DASHBOARD
// ==========================================
class HomeScreen extends StatefulWidget {
  final String userName;
  final bool isEnglish;
  final List<Map<String, dynamic>> activePiles;
  final ValueChanged<int> onMarkAsReady;
  final ValueChanged<int> onToggleStar;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.isEnglish,
    required this.activePiles,
    required this.onMarkAsReady,
    required this.onToggleStar
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = widget.isEnglish;

    // Filtered Arrays processing sorting priorities (Starred items always absolute first layout priority)
    final filteredPiles = widget.activePiles.where((pile) {
      final name = pile["name"].toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    filteredPiles.sort((a, b) => (b["isStarred"] as bool ? 1 : 0).compareTo(a["isStarred"] as bool ? 1 : 0));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${lang ? "Hello" : "Mwapoleni"}, ${widget.userName}! 👋', style: theme.textTheme.displayLarge),
                        const SizedBox(height: 4),
                        Text(AppStrings.get('subGreeting', lang), style: const TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search Bar Layout Element Matrix
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search matrix reference designations...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero
                ),
              ),
              const SizedBox(height: 24),

              Text(AppStrings.get('activeTag', lang), style: theme.textTheme.displayLarge?.copyWith(fontSize: 18)),
              const SizedBox(height: 12),

              if (filteredPiles.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: const Text('No active matching piles monitored.', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredPiles.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final currentItem = filteredPiles[index];
                    final originalIndex = widget.activePiles.indexOf(currentItem);
                    final bool isStarred = currentItem["isStarred"] as bool;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: isStarred ? Border.all(color: theme.colorScheme.secondary.withOpacity(0.5), width: 1.5) : null),
                      child: Row(
                        children: [
                          Icon(Icons.layers_rounded, color: isStarred ? theme.colorScheme.secondary : theme.colorScheme.primary.withOpacity(0.5), size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(currentItem["name"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text("${currentItem["type"]} • ${currentItem["weight"]}kg • ${currentItem["date"]}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(isStarred ? Icons.star_rounded : Icons.star_border_rounded, color: isStarred ? theme.colorScheme.secondary : Colors.grey),
                            onPressed: () => widget.onToggleStar(originalIndex),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 26),
                            onPressed: () => widget.onMarkAsReady(originalIndex),
                          )
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppStrings.get('overallStatus', lang), style: const TextStyle(color: Colors.white60, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(AppStrings.get('healthyCooking', lang), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: theme.colorScheme.secondary, shape: BoxShape.circle),
                      child: const Text('82%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Text(AppStrings.get('liveConditions', lang), style: theme.textTheme.displayLarge?.copyWith(fontSize: 17)),
              const SizedBox(height: 12),

              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildSlidableCard(context, AppStrings.get('temp', lang), '54°C', Icons.thermostat_rounded, Colors.orange.shade700),
                    _buildSlidableCard(context, AppStrings.get('moisture', lang), '60%', Icons.water_drop_rounded, Colors.blue.shade700),
                    _buildSlidableCard(context, AppStrings.get('ph', lang), '6.8 pH', Icons.science_rounded, Colors.purple.shade700),
                    _buildSlidableCard(context, AppStrings.get('aeration', lang), AppStrings.get('optimal', lang), Icons.air_rounded, Colors.teal.shade700),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Text(AppStrings.get('tipsTitle', lang), style: theme.textTheme.displayLarge?.copyWith(fontSize: 17)),
              const SizedBox(height: 12),
              _buildPlainEnglishTip(context, title: AppStrings.get('tip1Title', lang), description: AppStrings.get('tip1Desc', lang), icon: Icons.waves_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlidableCard(BuildContext context, String title, String value, IconData icon, Color iconColor) {
    final theme = Theme.of(context);
    return Container(
      width: 145,
      margin: const EdgeInsets.only(right: 12, bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _buildPlainEnglishTip(BuildContext context, {required String title, required String description, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFC68B59), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 3: HISTORY ARCHIVE STORAGE
// ==========================================
class HistoryScreen extends StatelessWidget {
  final bool isEnglish;
  final List<Map<String, dynamic>> historyPiles;

  const HistoryScreen({super.key, required this.isEnglish, required this.historyPiles});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Text(AppStrings.get('historyTitle', isEnglish), style: theme.textTheme.displayLarge),
            const SizedBox(height: 4),
            Text(AppStrings.get('historySub', isEnglish), style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 24),

            if (historyPiles.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Text('No archived soil metrics historical reference profiles.', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: historyPiles.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildHistoryItem(
                    context,
                    date: historyPiles[index]["date"]!,
                    status: historyPiles[index]["name"]!,
                    details: historyPiles[index]["details"]!
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, {required String date, required String status, required String details}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.verified_rounded, color: Colors.green),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(details, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 4: ALERTS SCREEN
// ==========================================
class AlertsScreen extends StatelessWidget {
  final bool isEnglish;
  const AlertsScreen({super.key, required this.isEnglish});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Text(AppStrings.get('alertsTitle', isEnglish), style: theme.textTheme.displayLarge),
            const SizedBox(height: 4),
            Text(AppStrings.get('alertsSub', isEnglish), style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_drop_rounded, color: Colors.blue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(AppStrings.get('alert1Title', isEnglish), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(AppStrings.get('alert1Desc', isEnglish), style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 5: STRUCTURAL SETTINGS SCREEN
// ==========================================
class SettingsScreen extends StatelessWidget {
  final String userName;
  final bool isEnglish;
  final ValueChanged<bool> onLanguageChange;

  const SettingsScreen({super.key, required this.userName, required this.isEnglish, required this.onLanguageChange});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = isEnglish;
    final String initial = userName.isNotEmpty ? userName[0].toUpperCase() : "A";

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.get('settingsTitle', lang), style: theme.textTheme.displayLarge),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.2)),
                          const SizedBox(height: 4),
                          Text('${AppStrings.get('settingsSub', lang)} Ecosystem Node', style: const TextStyle(fontSize: 13, color: Colors.black45)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.translate_rounded, color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 16),
                        Text(AppStrings.get('langSection', lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      children: [
                        const Text("EN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Switch.adaptive(
                          value: !isEnglish,
                          activeColor: theme.colorScheme.secondary,
                          onChanged: (value) => onLanguageChange(!value),
                        ),
                        const Text("BEM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildSettingsOption(context, icon: Icons.manage_accounts_rounded, title: AppStrings.get('opt1', lang), descriptor: 'Update user profiles, update account tokens, and secure custom preferences.'),
              _buildSettingsOption(context, icon: Icons.gpp_good_rounded, title: AppStrings.get('opt2', lang), descriptor: 'Manage telemetry cryptographic signature certificates and hardware nodes authorization protocols.'),
              _buildSettingsOption(context, icon: Icons.help_center_rounded, title: AppStrings.get('opt3', lang), descriptor: 'Access agricultural engineering documentation matching optimal moisture balances.'),
              _buildSettingsOption(context, icon: Icons.info_outline_rounded, title: AppStrings.get('opt4', lang), descriptor: 'Smart Compost Monitor Systems Integration Engine v3.0.0 Stable Build.'),

              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen(isEnglish: isEnglish, onLanguageChange: onLanguageChange)));
                },
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: Text(AppStrings.get('logout', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA1A1A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsOption(BuildContext context, {required IconData icon, required String title, required String descriptor}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1C1A))),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: theme.scaffoldBackgroundColor,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (context) {
              return Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(descriptor, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5)),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
                      child: const Text('Dismiss Panel'),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}