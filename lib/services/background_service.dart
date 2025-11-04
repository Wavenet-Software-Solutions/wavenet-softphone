import 'dart:async';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pjsip_bridge.dart'; // your SipProvider import

class WavenetForegroundHandler extends TaskHandler {
  Timer? _timer;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    FlutterForegroundTask.updateService(
      notificationTitle: 'Wavenet Softphone Running',
      notificationText: 'Listening for incoming calls…',
    );

    // every 2 min, re-register if needed 💫
    _timer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      final user = prefs.getString('username');
      final pass = prefs.getString('password');
      final host = prefs.getString('host');

      if (user != null && pass != null && host != null) {
        final sip = SipProvider();
        if (!sip.registered) {
          print("🔁 Re-registering SIP from background…");
          await sip.register(user, pass, host);
        }
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    _timer?.cancel();
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {}
}
