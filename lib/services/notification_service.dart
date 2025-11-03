import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wavenetsoftphone/pjsip_bridge.dart';
import '../global_keys.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    final iosInit = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'incoming_call',
          actions: [
            DarwinNotificationAction.plain('ACCEPT', '✅ Accept'),
            DarwinNotificationAction.plain('DECLINE', '❌ Decline',
                options: {DarwinNotificationActionOption.destructive}),
          ],
        ),
        DarwinNotificationCategory(
          'active_call',
          actions: [
            DarwinNotificationAction.plain('MUTE_ACTION', '🎙️ Mute / Unmute'),
            DarwinNotificationAction.plain('HANGUP_ACTION', '💔 Hang Up',
                options: {DarwinNotificationActionOption.destructive}),
          ],
        ),
      ],
    );

    final settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleAction,
    );

    debugPrint("🔔 Unified NotificationService initialized!");
  }

  // 🌼 Handles *all* actions here
  Future<void> _handleAction(NotificationResponse response) async {
    final action = response.actionId ?? '';
    final payload = response.payload ?? '';
    debugPrint("🔔 Notification tapped → Action: $action | Payload: $payload");

    final sip = SipProvider(); // singleton

    switch (payload) {
      case 'incoming_call':
        if (action == 'ACCEPT') {
          debugPrint("✅ Accept pressed — answering call");
          await sip.answer();
          navigatorKey.currentState?.pushNamed('/call');
        } else if (action == 'DECLINE') {
          debugPrint("🚫 Decline pressed — hanging up call");
          await sip.hangup();
          await plugin.cancel(0);
        }
        break;

      case 'active_call':
        if (action == 'MUTE_ACTION') {
          debugPrint("🎙️ Mute toggled");
          await sip.toggleMute();
          await sip.refreshActiveCallNotification();
        } else if (action == 'HANGUP_ACTION') {
          debugPrint("💔 Hang-up pressed");
          await sip.hangup();
          await plugin.cancel(1);
        }
        break;
    }
  }

  // 📞 Show incoming call
  Future<void> showIncomingCall(String caller) async {
    const android = AndroidNotificationDetails(
      'incoming_call_channel',
      'Incoming Calls',
      channelDescription: 'Incoming SIP calls',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      playSound: true,
      ticker: 'Incoming call...',
      actions: [
        AndroidNotificationAction('ACCEPT', '✅ Accept', showsUserInterface: true),
        AndroidNotificationAction('DECLINE', '❌ Deny',
            showsUserInterface: true, cancelNotification: true),
      ],
    );

    const ios = DarwinNotificationDetails(
      categoryIdentifier: 'incoming_call',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platform = NotificationDetails(android: android, iOS: ios);

    await plugin.show(
      0,
      '📞 Incoming Call',
      '$caller is calling...',
      platform,
      payload: 'incoming_call',
    );
  }

  // 📱 Show active call
  Future<void> showActiveCall(String target, {bool muted = false}) async {
    final android = AndroidNotificationDetails(
      'active_call_channel',
      'Active Call',
      channelDescription: 'Active call controls',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'MUTE_ACTION',
          muted ? 'Unmute 🎙️' : 'Mute 🎙️',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'HANGUP_ACTION',
          'Hang Up 💔',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );

    final ios = DarwinNotificationDetails(
      categoryIdentifier: 'active_call',
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    final platform = NotificationDetails(android: android, iOS: ios);

    await plugin.show(
      1,
      '📞 In Call',
      'Talking with $target',
      platform,
      payload: 'active_call',
    );
  }
}
