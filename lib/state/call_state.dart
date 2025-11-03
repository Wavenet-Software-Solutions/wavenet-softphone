import 'package:flutter/foundation.dart';


class CallState extends ChangeNotifier {
  String username = '';
  String password = '';
  String host = '';
  String transport = 'UDP';


  String dialed = '';
  bool inCall = false;
  bool muted = false;


  void setAccount({required String u, required String p, required String h, String t = 'UDP'}) {
    username = u; password = p; host = h; transport = t;
    notifyListeners();
  }


  void appendDigit(String d) {
    dialed += d; notifyListeners();
  }


  void backspace() {
    if (dialed.isNotEmpty) {
      dialed = dialed.substring(0, dialed.length - 1);
      notifyListeners();
    }
  }


  void clearDialed() { dialed = ''; notifyListeners(); }


  void setInCall(bool v) { inCall = v; notifyListeners(); }


  void setMuted(bool v) { muted = v; notifyListeners(); }
}