import 'package:flutter/services.dart';

class VoipPushManager {
  static const _channel = MethodChannel('voip_push_channel');

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onVoipToken') {
        final token = call.arguments as String;
        print('📞 Received VoIP Token in Flutter: $token');

        // 💾 You can now send it to your backend:
        // await MyApiService.registerVoipToken(userId, token);
      }
    });
  }
}
