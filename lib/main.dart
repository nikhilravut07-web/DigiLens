import 'package:flutter/material.dart';
import 'package:digilens/screens/home_screen.dart';
import 'package:digilens/screens/scan_history_screen.dart';
import 'package:digilens/screens/performance_screen.dart';
import 'package:digilens/screens/settings_screen.dart';
import 'package:digilens/screens/scan_result_screen.dart';
import 'package:digilens/services/scan_history_service.dart';
import 'package:digilens/services/pre_navigation_guard.dart';
import 'package:digilens/services/automatic_sms_guard_service.dart';
import 'package:digilens/services/parental_control_service.dart';
import 'package:digilens/services/url_analysis_service.dart';
import 'package:digilens/theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read backend URL from build-time --dart-define=BACKEND_BASE_URL=...
  const definedUrl = String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
  if (definedUrl.isNotEmpty) {
    UrlAnalysisService.backendBaseUrl = definedUrl;
    debugPrint('[DigiLens Config] Backend Base URL configured: $definedUrl');
  } else {
    debugPrint('[DigiLens Config] WARNING: BACKEND_BASE_URL is not set via --dart-define.');
  }

  await ParentalControlService.instance.init();
  await ScanHistoryService.instance.init();
  runApp(const DigiLensApp());
}

class DigiLensApp extends StatefulWidget {
  const DigiLensApp({super.key});

  @override
  State<DigiLensApp> createState() => _DigiLensAppState();
}

class _DigiLensAppState extends State<DigiLensApp> {
  @override
  void initState() {
    super.initState();
    PreNavigationGuard.initIntentHandler(navigatorKey);
    AutomaticSmsGuardService.instance.initialize();
    AutomaticSmsGuardService.onNotificationTapNavigation = (result, scannedInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navState = navigatorKey.currentState;
        if (navState != null && navState.mounted) {
          navState.push(
            MaterialPageRoute(
              builder: (context) => ScanResultScreen(
                result: result,
                scannedInput: scannedInput,
              ),
            ),
          );
        }
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiLens',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = [
    const HomeScreen(),
    const ScanHistoryScreen(),
    const PerformanceScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 24),
            selectedIcon: Icon(Icons.home, size: 24),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined, size: 24),
            selectedIcon: Icon(Icons.history, size: 24),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined, size: 24),
            selectedIcon: Icon(Icons.analytics, size: 24),
            label: 'Performance',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, size: 24),
            selectedIcon: Icon(Icons.settings, size: 24),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
