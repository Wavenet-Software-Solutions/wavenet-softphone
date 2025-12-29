import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

class VoipPushManager {
  static const _channel = MethodChannel('voip_push_channel');
  static String? _lastToken;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onVoipToken') {
        final token = call.arguments as String;
        _lastToken = token;
        print('📞 Received VoIP Token: $token');
        await _sendVoipTokenToBackend(token);
      }
    });
  }

  // 💫 Allow manual call from main() if token + credentials exist
  static Future<void> sendSavedTokenToBackend() async {
    if (_lastToken != null) {
      await _sendVoipTokenToBackend(_lastToken!);
    } else {
      print("⚠️ No VoIP token cached yet — waiting for iOS to provide one.");
    }
  }

  static Future<void> _sendVoipTokenToBackend(String token) async {
    try {
      final backendUrl = dotenv.env['BACKEND_URL'];
      if (backendUrl == null || backendUrl.isEmpty) {
        print("⚠️ Missing BACKEND_URL in env — skipping token registration.");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      String? uuid = prefs.getString('agent_uuid');

      if (uuid == null) {
        uuid = const Uuid().v4();
        await prefs.setString('agent_uuid', uuid);
      }

      if (username == null || username.isEmpty) {
        print("⚠️ No username in prefs — cannot send token.");
        return;
      }

      final body = jsonEncode({
        'uuid': uuid,
        'agent': username,
        'voip_token': token,
      });

      final endpoint = '$backendUrl/api/voip/register-token';
      print("🚀 Sending VoIP token to $endpoint");

      final res = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (res.statusCode == 200) {
        print("✅ VoIP token registered for agent $username");
      } else {
        print("❌ Failed to register VoIP token (${res.statusCode}): ${res.body}");
      }
    } catch (e) {
      print("⚠️ Error sending VoIP token: $e");
    }
  }
}
