import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pjsip_bridge.dart';
import 'screens/login_screen.dart';
import 'screens/keypad_screen.dart';
import 'screens/call_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'global_keys.dart';
import 'screens/incoming_callscreen.dart';
import 'package:sip_ua/sip_ua.dart';
import 'screens/recent_call_screen.dart';
import 'screens/voicemail_screen.dart';


Future<void> _requestAppPermissions() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // 🔹 Request Notification permission (Android 13+ / iOS)
  if (await Permission.notification.isDenied ||
      await Permission.notification.isPermanentlyDenied) {
    final result = await Permission.notification.request();
    if (result.isDenied) {
      debugPrint("🚫 Notification permission denied on Android.");
    }
  }

  final iosPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin>();
  await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

  // 🎙️ Request Microphone permission
  if (await Permission.microphone.isDenied) {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (_) => AlertDialog(
        title: const Text("Microphone Permission"),
        content: const Text(
            "Please enable microphone access to make or receive calls 🥺"),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }
else {
    debugPrint("🎧 Microphone permission already granted!");
  }

  debugPrint("✅ All essential permissions handled!");
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sipProvider = SipProvider()..init();
  await _requestAppPermissions();
  runApp(
    ChangeNotifierProvider.value(
      value: sipProvider,
      child: const SoftphoneApp(),
    ),
  );
}

class SoftphoneApp extends StatelessWidget {
  const SoftphoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wavenet Softphone',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3D5AFE),
        scaffoldBackgroundColor: const Color(0xFF0f2027),
      ),
      home: const _AppShell(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const KeypadScreen(),
        '/call': (_) => const CallScreen(),
        '/incoming': (context) {
          final call = ModalRoute.of(context)!.settings.arguments as Call;
          return IncomingCallScreen(call: call);
        },
        '/recent': (_) => const RecentCallsScreen(),
      },
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({super.key});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell>
    with SingleTickerProviderStateMixin {
  bool _checkingLogin = true;
  bool _loggedIn = false;
  int _selectedIndex = 0;

  late AnimationController _controller;
  late Animation<double> _animation;

  final List<Widget> _pages = const [
    KeypadScreen(key: ValueKey('keypad')),
    RecentCallsScreen(key: ValueKey('recent')),
    VoicemailScreen(key: ValueKey('voicemail')),
    SettingsScreen(key: ValueKey('settings')),
    AboutScreen(key: ValueKey('about')),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('username');
    final pass = prefs.getString('password');
    final host = prefs.getString('host');

    if (user != null && pass != null && host != null && user.isNotEmpty) {
      debugPrint("🔁 Auto-reconnecting as $user@$host ...");
      final sip = Provider.of<SipProvider>(context, listen: false);
      await sip.register(user, pass, host);

      // Delay update until the first frame is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _checkingLogin = false;
          _loggedIn = true;
          _selectedIndex = 0;
        });
        _controller.forward(from: 0);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _checkingLogin = false;
          _loggedIn = false;
        });
      });
    }
  }

  void _onTabSelected(int index) {
    if (index == _selectedIndex) return;
    _controller.forward(from: 0);
    setState(() => _selectedIndex = index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sip = context.watch<SipProvider>();

    // ⏳ Show loading spinner until auto-login check is done
    if (_checkingLogin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🔐 Not logged in? → Go to login screen
    if (!_loggedIn) return const LoginScreen();

    // ✅ Logged in → show KeypadScreen immediately
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return ClipPath(
            clipper: _BlackHoleClipper(_animation.value),
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          );
        },
      ),
      bottomNavigationBar: AnimatedBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}

class _BlackHoleClipper extends CustomClipper<Path> {
  final double progress;
  _BlackHoleClipper(this.progress);

  @override
  Path getClip(Size size) {
    final radius = size.longestSide * progress;
    final center = Offset(size.width / 2, size.height / 2);
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _BlackHoleClipper oldClipper) =>
      oldClipper.progress != progress;
}


// // 🌌 Custom clipper for circular "black hole" transition
// class _BlackHoleClipper extends CustomClipper<Path> {
//   final double progress;
//   _BlackHoleClipper(this.progress);
//
//   @override
//   Path getClip(Size size) {
//     final radius = size.longestSide * progress;
//     final center = Offset(size.width / 2, size.height / 2);
//     return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
//   }
//
//   @override
//   bool shouldReclip(covariant _BlackHoleClipper oldClipper) =>
//       oldClipper.progress != progress;
// }

class AnimatedBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AnimatedBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AnimatedBottomNavBar> createState() => _AnimatedBottomNavBarState();
}

class _AnimatedBottomNavBarState extends State<AnimatedBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _tappedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _tappedIndex = index;
    });
    _controller.forward(from: 0);
    widget.onTap(index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = const [
      {'icon': Icons.dialpad_outlined, 'active': Icons.dialpad, 'label': 'Keypad'},
      {'icon': Icons.history, 'active': Icons.history_toggle_off, 'label': 'Recent'},
      {'icon': Icons.voicemail_outlined, 'active': Icons.voicemail, 'label': 'Voicemail'},
      {'icon': Icons.settings_outlined, 'active': Icons.settings, 'label': 'Settings'},
      {'icon': Icons.info_outline, 'active': Icons.info, 'label': 'About'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (index) {
          final active = widget.currentIndex == index;
          final item = items[index];

          return Expanded(
            child: GestureDetector(
              onTap: () => _onItemTapped(index),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final isTapped = _tappedIndex == index;
                  final circleSize = isTapped ? 80 * _animation.value : 0.0;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // 🌈 Circular color animation on the pressed button
                      if (isTapped)
                        Container(
                          width: circleSize,
                          height: circleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
                            ),
                          ),
                        ),
                      // 🧭 Icon + label
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            active ? item['active'] as IconData : item['icon'] as IconData,
                            color: active ? Colors.tealAccent : Colors.white54,
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              color: active ? Colors.tealAccent : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}
