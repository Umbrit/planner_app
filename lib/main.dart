// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';

import 'screens/planner_screen.dart';
import 'screens/routine_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const PlannerApp());
}

class PlannerApp extends StatefulWidget {
  const PlannerApp({super.key});

  @override
  State<PlannerApp> createState() => _PlannerAppState();
}

class _PlannerAppState extends State<PlannerApp> {
  int _selectedIndex = 0;
  bool _isAuthenticated = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _darkMode = false;

  final List<Widget> _screens = [
    const PlannerScreen(),
    const RoutineScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _authenticateUser();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool('dark_mode') ?? false;
    setState(() {});
  }

  Future<void> _authenticateUser() async {
    try {
      bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to use the Planner App',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        setState(() {
          _isAuthenticated = true;
        });
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
    }
  }

  Future<void> _handleTabSwitch(int index) async {
    bool didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'Authenticate to switch tabs',
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
      ),
    );

    if (didAuthenticate) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planner App',
      theme: _darkMode ? ThemeData.dark() : ThemeData.light(),
      home: _isAuthenticated
          ? Scaffold(
              body: _screens[_selectedIndex],
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _handleTabSwitch,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.schedule),
                    label: 'Planner',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.check_circle_outline),
                    label: 'Routines',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            )
          : const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _biometricsEnabled = true;
  bool _darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _biometricsEnabled = prefs.getBool('biometrics') ?? true;
      _darkModeEnabled = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable Notifications'),
            value: _notificationsEnabled,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
              _updateSetting('notifications', val);
            },
          ),
          SwitchListTile(
            title: const Text('Enable Biometric Authentication'),
            value: _biometricsEnabled,
            onChanged: (val) {
              setState(() => _biometricsEnabled = val);
              _updateSetting('biometrics', val);
            },
          ),
          SwitchListTile(
            title: const Text('Enable Dark Mode'),
            value: _darkModeEnabled,
            onChanged: (val) {
              setState(() => _darkModeEnabled = val);
              _updateSetting('dark_mode', val);
              // Restart the app UI
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const PlannerApp()),
              );
            },
          ),
        ],
      ),
    );
  }
}
