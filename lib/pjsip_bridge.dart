import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'global_keys.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wavenetsoftphone/main.dart';
import 'package:wavenetsoftphone/services/notification_service.dart';



class SipProvider extends ChangeNotifier with WidgetsBindingObserver  implements SipUaHelperListener {
  // 💫 Singleton pattern
  static final SipProvider _instance = SipProvider._internal();
  factory SipProvider() => _instance;
  SipProvider._internal();

  final SIPUAHelper _helper = SIPUAHelper();
  final List<SipUaHelperListener> _extraListeners = [];

  Call? activeCall;
  bool registered = false;
  bool muted = false;
  bool speakerOn = false;
  bool connecting = false;
  String status = 'disconnected';
  String networkState = 'idle';
  String? error;
  Duration callDuration = Duration.zero;
  Duration lastCallDuration = Duration.zero;


  final Stopwatch _stopwatch = Stopwatch();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  SIPUAHelper get helper => _helper;

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();
  final player = FlutterRingtonePlayer();


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("📶 App resumed — checking SIP connection...");
      if (!registered) {
        _helper.register();
        debugPrint("🔄 Reconnecting SIP WebSocket...");
      }
    } else if (state == AppLifecycleState.paused) {
      debugPrint("🌙 App paused — optionally keep connection or save state");
    }
  }


  void init() {
    _helper.addSipUaHelperListener(this);
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {

  }
  Future<void> _startRingtone() async {
    try {
      debugPrint("🔔 Playing ringtone...");
      await player.play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.alarm,
        looping: true, // 🔁 keep playing until answered or ended
        volume: 1.0,
        asAlarm: false,
      );
    } catch (e) {
      debugPrint("⚠️ Failed to play ringtone: $e");
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await player.stop();
      debugPrint("🔕 Ringtone stopped");
    } catch (e) {
      debugPrint("⚠️ Failed to stop ringtone: $e");
    }
  }


  Future<void> _showActiveCallNotification(String target, {bool muted = false}) async {
    await NotificationService().showActiveCall(activeCall?.remote_identity ?? 'Unknown');

    debugPrint("🔔 Active call notification shown for $target");
  }


// 💫 Refresh the active call notification UI (Mute/Unmute label)
  Future<void> refreshActiveCallNotification() async {
    final callTarget = activeCall?.remote_identity ?? 'Unknown';
    await NotificationService().showActiveCall(callTarget, muted: muted);
    debugPrint("🔁 Active call notification refreshed for $callTarget");
  }


  // 🧠 Initialize SIP
  Future<void> _showIncomingCallNotification(String caller) async {
    await NotificationService().showIncomingCall(activeCall?.remote_identity ?? "Unknown");
  }


  void addSipListener(SipUaHelperListener listener) {
    if (!_extraListeners.contains(listener)) {
      _extraListeners.add(listener);
      debugPrint("💌 Added SIP listener: ${listener.runtimeType}");
    }
  }

  void removeSipListener(SipUaHelperListener listener) {
    _extraListeners.remove(listener);
    debugPrint("🧹 Removed SIP listener: ${listener.runtimeType}");
  }

  @override
  void dispose() {
    debugPrint("💔 SipProvider.dispose() called — singleton persists");
    super.dispose();
  }

  // 🚀 Register user
  Future<void> register(String username, String password, String domain) async {
    if (connecting || registered) {
      debugPrint("⚠️ Already connecting or registered — skipping.");
      return;
    }

    if (domain.isEmpty || username.isEmpty || password.isEmpty) {
      _setError("⚠️ Missing credentials or host — cannot register");
      return;
    }

    connecting = true; // prevent retry
    notifyListeners();

    try {
      // 🧩 Build WebSocket URL directly from user input
      String wsUrl = domain;
      if (!domain.startsWith('ws://') && !domain.startsWith('wss://')) {
        // Default to ws:// if user didn’t include scheme
        wsUrl = 'ws://$domain/ws';
      }

      final uri = 'sip:$username@$domain';

      final settings = UaSettings()
        ..webSocketUrl = wsUrl
        ..uri = uri
        ..authorizationUser = username
        ..password = password
        ..displayName = username
        ..realm = domain
        ..userAgent = 'WavenetWebRTC/1.0'
        ..transportType = TransportType.WS
        ..webSocketSettings.allowBadCertificate = true
        ..iceServers = [
          {'urls': 'stun:stun.l.google.com:19302'}
        ];

      debugPrint("🔧 SIP Config:\n - WS: ${settings.webSocketUrl}\n - URI: ${settings.uri}");

      _helper.start(settings);
      status = 'registering';

      if (Platform.isAndroid) {
        await FlutterForegroundTask.startService(
          notificationTitle: 'Wavenet Softphone Running',
          notificationText: 'Listening for incoming calls…',
          callback: startCallback, // 💫 background handler
        );
      }

      debugPrint("🚀 Foreground service started to keep WebSocket alive.");
      error = null;
    } catch (e, s) {
      _setError("❌ Registration failed: $e");
      debugPrint("SIPUAHelper.start failed: $e\n$s");
      connecting = false;
      notifyListeners();
    }

  }


  // 📴 Unregister SIP
  Future<void> unregister() async {
    try {
      debugPrint("👋 Unregistering SIP session...");
      _helper.stop(); // no await (returns void)
      registered = false;
      status = 'disconnected';
      notifyListeners();
    } catch (e) {
      _setError("❌ Unregister failed: $e");
    }
  }

  // 📞 Outbound call
  Future<void> makeCall(String target) async {
    if (!registered) {
      _setError("📡 Not connected! Please register first.");
      return;
    }

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _setError("🎙️ Microphone permission denied.");
      status = 'mic_denied';
      return;
    }

    try {
      debugPrint("📞 Calling $target ...");
      _helper.call(target, voiceOnly: true);
      status = 'calling';
      error = null;
      notifyListeners();
    } catch (e, s) {
      _setError("❌ Failed to start call: $e");
      debugPrint("Call error: $e\n$s");
    }
  }

  // 📲 Answer call
  Future<void> answer() async {
    if (activeCall == null) {
      _setError("⚠️ No active call to answer.");
      return;
    }

    try {
      activeCall!.answer({
        'mediaConstraints': {'audio': true, 'video': false},
        'rtcOfferConstraints': {'offerToReceiveAudio': true, 'offerToReceiveVideo': false},
      });
      status = 'oncall';
      _startGlobalTimer();
      notifyListeners();
    } catch (e, s) {
      _setError("❌ Answer failed: $e");
      debugPrint("Answer error: $e\n$s");
    }
  }


  // 🚫 Hang up
  Future<void> hangup() async {
    try {
      activeCall?.hangup();
      _stopGlobalTimer();
      await saveCallHistory(
        activeCall?.remote_identity ?? 'Unknown',
        activeCall?.direction ?? 'Unknown',
        duration: lastCallDuration,
      );


      activeCall = null;
      status = 'ended';
      error = null;
      notifyListeners();
    } catch (e, s) {
      _setError("❌ Hangup failed: $e");
      debugPrint("Hangup error: $e\n$s");
    }
  }

  // 🔇 Toggle mute
  Future<void> toggleMute() async {
    if (activeCall == null) {
      _setError("⚠️ No active call to mute/unmute!");
      return;
    }

    muted = !muted;
    try {
      muted ? activeCall!.mute(true) : activeCall!.unmute();
      debugPrint(muted ? "🔇 Muted" : "🎙️ Unmuted");
      notifyListeners();
    } catch (e, s) {
      _setError("❌ Mute toggle failed: $e");
      debugPrint("Mute error: $e\n$s");
    }
  }

  // 🔊 Toggle speaker
  Future<void> toggleSpeaker() async {
    try {
      speakerOn = !speakerOn;
      await Helper.setSpeakerphoneOn(speakerOn);
      debugPrint(speakerOn ? "🔊 Speaker ON" : "🔈 Speaker OFF");
      notifyListeners();
    } catch (e, s) {
      _setError("❌ Speaker toggle failed: $e");
      debugPrint("Speaker error: $e\n$s");
    }
  }

  // ⏱️ Timer

  Timer? _timer;
  final ValueNotifier<int> elapsedSeconds = ValueNotifier(0);
  final ValueNotifier<String> callConnectionInfo = ValueNotifier<String>("Connecting…");
  Timer? _elapsedTimer;

  void _startGlobalTimer() {
    _elapsedTimer?.cancel();
    int seconds = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      seconds++;
      elapsedSeconds.value = seconds;
    });
  }

  void _stopGlobalTimer() {
    _elapsedTimer?.cancel();
    if (_elapsedTimer != null) {
      lastCallDuration = Duration(seconds: elapsedSeconds.value); // 💾 Save before reset
    }
    elapsedSeconds.value = 0;
  }

  // void _startTimer() {
  //   if (_timer != null) return; // avoid duplicates
  //   _stopwatch.start();
  //   _timer = Timer.periodic(const Duration(seconds: 1), (_) {
  //     elapsedSeconds.value = _stopwatch.elapsed.inSeconds;
  //   });
  // }
  //
  // void _stopTimer() {
  //   _timer?.cancel();
  //   _timer = null;
  //   _stopwatch.stop();
  //   callDuration = _stopwatch.elapsed;
  //   _stopwatch.reset();
  //   elapsedSeconds.value = 0;
  // }

  void _setError(String message) {
    error = message;
    debugPrint("🚨 SIP Error: $message");
    notifyListeners();
  }

  // 🧠 SIP Events
  @override
  void registrationStateChanged(RegistrationState state) {
    registered = state.state == RegistrationStateEnum.REGISTERED;

    if (state.state == RegistrationStateEnum.REGISTERED) {
      connecting = false;
      status = 'connected';
      error = null;
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      connecting = false;
      status = 'failed';
      _setError("❌ Registration failed (check credentials)");
    } else if (state.state == RegistrationStateEnum.UNREGISTERED) {
      connecting = false;
      status = 'disconnected';
    }

    notifyListeners();

    for (var listener in _extraListeners) {
      listener.registrationStateChanged(state);
    }
  }

  Future<void> _onIncomingCall(Call call) async {
    debugPrint("🔔 Incoming SIP call detected.");

    // Optional: Ask for mic permission
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      debugPrint("🎙️ Microphone permission denied for incoming call.");
    }

    // 🧭 Show incoming call screen
    navigatorKey.currentState?.pushNamed(
      '/incoming',
      arguments: call,
    );
  }

  Future<void> saveCallHistory(String name, String type, {Duration? duration}) async {
    final prefs = await SharedPreferences.getInstance();
    final calls = prefs.getStringList('recent_calls') ?? [];

    final now = DateTime.now();
    final callDuration = duration ?? Duration.zero;
    final formattedDuration =
        "${callDuration.inHours.toString().padLeft(2, '0')}:"
        "${(callDuration.inMinutes % 60).toString().padLeft(2, '0')}:"
        "${(callDuration.inSeconds % 60).toString().padLeft(2, '0')}";

    final formatted = "${now.toIso8601String()}|${name.trim()}|${type.trim()}|$formattedDuration";

    // Prevent duplicate same-number logs in a short time window
    if (calls.isNotEmpty && calls.first.contains(name)) {
      calls.removeAt(0);
    }

    calls.insert(0, formatted);

    // Keep latest 50 entries
    if (calls.length > 50) calls.removeRange(50, calls.length);

    await prefs.setStringList('recent_calls', calls);
    debugPrint("💾 Saved call: $formatted");
  }


  Future<void> _hideIncomingCallNotification() async {
    try {
      await _notifications.cancel(0); // 0 = notification ID used earlier
      debugPrint("🔕 Incoming call notification cleared.");
    } catch (e) {
      debugPrint("⚠️ Failed to hide notification: $e");
    }
  }
  // 🧠 Holds live connection info from ICE / WebRTC

  void updateConnectionStatus(String status) {
    callConnectionInfo.value = status;
    debugPrint("🌐 Connection updated: $status");
  }

  void observeNetworkState(Call? call) {
    final pc = call?.peerConnection;
    if (pc == null) {
      debugPrint("⚠️ No PeerConnection available for network observation.");
      return;
    }

    pc.onIceConnectionState = (state) {
      debugPrint('🌐 ICE State: $state');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          callConnectionInfo.value = "RTC Connected ✅";
          break;
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          callConnectionInfo.value = "Connection Stable 💚";
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          callConnectionInfo.value = "Disconnected ⚠️";
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          callConnectionInfo.value = "Network Failed ❌";
          break;
        default:
          callConnectionInfo.value = "Connecting…";
          break;
      }

      notifyListeners(); // 💫 Notify all UIs (floating + call screen)
    };
  }


  @override
  void callStateChanged(Call call, CallState callState) async {
    activeCall = call;
    final direction = call.direction.toUpperCase() ?? "UNKNOWN";
    final state = callState.state;

    debugPrint("📞 Call state: $state ($direction)");

    // Shared connection status for all UIs 💫
    String connectionInfo = "Connecting…";

    // 📲 Incoming call
    if (state == CallStateEnum.CALL_INITIATION && direction == 'INCOMING') {
      final caller = call.remote_identity ?? "Unknown Caller";
      debugPrint("📲 Incoming call from $caller");
      observeNetworkState(activeCall);
      connectionInfo = "Ringing 📳";
      await _startRingtone();
      callConnectionInfo.value = connectionInfo;
      await _showIncomingCallNotification(caller);

      navigatorKey.currentState?.pushNamed(
        '/incoming',
        arguments: call,
      );
      notifyListeners();
      return;
    }

    // 🚀 Outgoing call in progress
    if (state == CallStateEnum.PROGRESS && direction == 'OUTGOING') {
      debugPrint("📤 Outgoing call to ${call.remote_identity}");
      status = 'calling';
      observeNetworkState(activeCall);
      connectionInfo = "Dialing…";
      callConnectionInfo.value = connectionInfo;
      notifyListeners();
      return;
    }

    // 🎧 Media stream (when audio/video established)
    if (state == CallStateEnum.STREAM) {
      debugPrint("✅ Call media stream active — starting timer");
      await _hideIncomingCallNotification();
      status = 'oncall';
      connectionInfo = "Call Connected ✅";
      callConnectionInfo.value = connectionInfo;

      _startGlobalTimer();
      await _showActiveCallNotification(call.remote_identity ?? 'Unknown');
      notifyListeners();
      return;
    }

    // ☎️ Call confirmed (answered)
    if (state == CallStateEnum.CONFIRMED) {
      debugPrint("💚 Call confirmed — connected");
      await _hideIncomingCallNotification();
      await _stopRingtone();
      status = 'oncall';
      connectionInfo = "Call Confirmed 💚";
      callConnectionInfo.value = connectionInfo;

      _startGlobalTimer();
      notifyListeners();
      return;
    }

    // 💔 Call ended or failed
    if (state == CallStateEnum.ENDED || state == CallStateEnum.FAILED) {
      debugPrint("❌ Call ended: ${callState.cause}");
      await _hideIncomingCallNotification();
      await _stopRingtone();
      _stopGlobalTimer();

      activeCall = null;
      status = 'ended';
      connectionInfo = state == CallStateEnum.FAILED
          ? "Connection Failed ❌"
          : "Call Ended 💔";
      callConnectionInfo.value = connectionInfo;
      notifyListeners();

      // 💾 Save in call history
      final callType = direction == 'INCOMING'
          ? (state == CallStateEnum.FAILED ? 'Missed' : 'Incoming')
          : 'Outgoing';
      await saveCallHistory(
        call.remote_identity ?? 'Unknown',
        callType,
        duration: lastCallDuration,
      );

      return;
    }

    // Default fallback
    callConnectionInfo.value = connectionInfo;
    status = state.toString();
    notifyListeners();
  }


  @override
  void transportStateChanged(TransportState state) {
    networkState = state.state.toString();
    if (state.state == TransportStateEnum.DISCONNECTED) {
      _setError("🔌 SIP transport closed");
    } else if (state.state == TransportStateEnum.CONNECTING) {
      _setError("📴 Transport connecting");
    } else if (state.state == TransportStateEnum.NONE) {
      _setError("💔 Transport error");
    } else {
      error = null;
    }
    notifyListeners();
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}
}
