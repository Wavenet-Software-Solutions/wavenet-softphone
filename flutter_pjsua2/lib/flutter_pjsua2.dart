
import 'flutter_pjsua2_platform_interface.dart';

class FlutterPjsua2 {
  Future<String?> getPlatformVersion() {
    return FlutterPjsua2Platform.instance.getPlatformVersion();
  }
}
