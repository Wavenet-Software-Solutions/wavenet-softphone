import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pjsua2/flutter_pjsua2.dart';
import 'package:flutter_pjsua2/flutter_pjsua2_platform_interface.dart';
import 'package:flutter_pjsua2/flutter_pjsua2_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterPjsua2Platform
    with MockPlatformInterfaceMixin
    implements FlutterPjsua2Platform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterPjsua2Platform initialPlatform = FlutterPjsua2Platform.instance;

  test('$MethodChannelFlutterPjsua2 is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterPjsua2>());
  });

  test('getPlatformVersion', () async {
    FlutterPjsua2 flutterPjsua2Plugin = FlutterPjsua2();
    MockFlutterPjsua2Platform fakePlatform = MockFlutterPjsua2Platform();
    FlutterPjsua2Platform.instance = fakePlatform;

    expect(await flutterPjsua2Plugin.getPlatformVersion(), '42');
  });
}
