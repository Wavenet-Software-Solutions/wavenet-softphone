import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_pjsua2_platform_interface.dart';

/// An implementation of [FlutterPjsua2Platform] that uses method channels.
class MethodChannelFlutterPjsua2 extends FlutterPjsua2Platform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_pjsua2');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
