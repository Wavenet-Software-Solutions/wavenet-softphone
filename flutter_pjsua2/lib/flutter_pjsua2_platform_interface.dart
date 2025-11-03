import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_pjsua2_method_channel.dart';

abstract class FlutterPjsua2Platform extends PlatformInterface {
  /// Constructs a FlutterPjsua2Platform.
  FlutterPjsua2Platform() : super(token: _token);

  static final Object _token = Object();

  static FlutterPjsua2Platform _instance = MethodChannelFlutterPjsua2();

  /// The default instance of [FlutterPjsua2Platform] to use.
  ///
  /// Defaults to [MethodChannelFlutterPjsua2].
  static FlutterPjsua2Platform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterPjsua2Platform] when
  /// they register themselves.
  static set instance(FlutterPjsua2Platform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
