import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

class CallKitService {
  static final _uuid = Uuid();

  /// Show incoming call for BOTH iOS + Android
  static Future<String> showIncoming(String caller) async {
    final id = _uuid.v4();

    final params = CallKitParams(
      id: id,
      nameCaller: caller,
      handle: caller,
      type: 0, // 0 = audio

      // 🌸 Works on iOS & Android
      appName: 'Wavenet Softphone',
      avatar: '',
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: {'caller': caller},
      // 🍎 iOS-specific CallKit settings
      ios: IOSParams(
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        iconName: 'AppIcon',  // must match your iOS icon asset set
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);

    return id;
  }

  /// End call (Android + iOS)
  static Future<void> endCall(String uuid) async {
    await FlutterCallkitIncoming.endCall(uuid);
  }

  /// End ALL ongoing calls (useful on hangup)
  static Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
  }
}
