import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavenetsoftphone/pjsip_bridge.dart';
import 'package:wavenetsoftphone/services/notification_service.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _autoLogin = true;
  bool _sound = true;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final player = FlutterRingtonePlayer();

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _initializeNotifications();
  }

  // 🪄 Request notification permission (Android 13+ & iOS)
  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied ||
        await Permission.notification.isPermanentlyDenied) {
      await Permission.notification.request();
    }

    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // 🧩 Initialize notification system
  Future<void> _initializeNotifications() async {
    NotificationService().init();

  }

  // 🔔 Handle notification actions (Accept/Deny)
  void _onNotificationAction(NotificationResponse response) {
    debugPrint("🔔 Notification action tapped: ${response.actionId}");
    if (response.actionId == 'ACCEPT') {
      debugPrint("✅ Call accepted!");
      // TODO: Navigate to call screen or trigger SIP accept
    } else if (response.actionId == 'DECLINE') {
      debugPrint("🚫 Call declined!");
      // TODO: Hang up SIP call
    }
  }

  // 📞 Show incoming call notification with buttons
  Future<void> _showIncomingCallNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'incoming_call_channel',
      'Incoming Calls',
      channelDescription: 'Notifies about incoming SIP calls',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true, // ✅ Default Android sound
      fullScreenIntent: true,
      ticker: 'Incoming call...',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'ACCEPT',
          '✅ Accept',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'DECLINE',
          '❌ Deny',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'incoming_call_category',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.show(
      0,
      '📞 Incoming Call',
      'John Doe is calling you...',
      platformDetails,
      payload: 'incoming_call',
    );
  }

  // 🎵 Test Android’s default ringtone
  Future<void> _playRingtone() async {
    player.play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.glass,
      looping: false,
      volume: 1.0,
      asAlarm: false,
    );
  }

  // 🚪 Logout and clear user data
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    SipProvider().unregister();
    await prefs.clear();

    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0f2027),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('⚙️ Settings'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Preferences",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: Colors.white.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: Colors.tealAccent,
                    title: const Text('Enable Notifications',
                        style: TextStyle(color: Colors.white)),
                    value: _notifications,
                    onChanged: (v) {
                      setState(() => _notifications = v);
                      if (v) {
                        _showIncomingCallNotification();
                      } else {
                        _notificationsPlugin.cancelAll();
                      }
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  SwitchListTile(
                    activeColor: Colors.tealAccent,
                    title: const Text('Auto Login',
                        style: TextStyle(color: Colors.white)),
                    value: _autoLogin,
                    onChanged: (v) => setState(() => _autoLogin = v),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  SwitchListTile(
                    activeColor: Colors.tealAccent,
                    title: const Text('Call Sound',
                        style: TextStyle(color: Colors.white)),
                    subtitle: const Text("Plays Android default ringtone",
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    value: _sound,
                    onChanged: (v) {
                      setState(() => _sound = v);
                      if (v) {
                        _playRingtone();
                      } else {
                        player.stop();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Account",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: Colors.white.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Logout',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                trailing: const Icon(Icons.arrow_forward_ios,
                    color: Colors.white38, size: 16),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1e2a38),
                      title: const Text('Logout',
                          style: TextStyle(color: Colors.white)),
                      content: const Text(
                        'Are you sure you want to log out?',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel',
                              style: TextStyle(color: Colors.white70)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Logout',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) await _logout(context);
                },
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                "Wavenet Softphone v1.0 💙",
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white38, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
