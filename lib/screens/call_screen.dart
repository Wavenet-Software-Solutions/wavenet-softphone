import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';
import '../pjsip_bridge.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> implements SipUaHelperListener {
  late SIPUAHelper _ua;
  Call? _call;
  bool _muted = false;
  bool _speakerOn = false;
  bool _hasPopped = false;
  bool _showDialpad = false; // 🌸 toggle state
  String _networkStatus = "Connecting…";

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  final Stopwatch _stopwatch = Stopwatch();
  late final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ua = SipProvider().helper;
    _ua.addSipUaHelperListener(this);
    _call = SipProvider().activeCall;
    _initRenderers();
    _attachMedia();
    _observeNetworkState();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _attachMedia() async {
    if (_call == null) return;
    final pc = _call!.peerConnection;
    if (pc == null) return;

    final remoteStreams = pc.getRemoteStreams();
    if (remoteStreams.isNotEmpty) {
      _remoteRenderer.srcObject = remoteStreams.first;
    }

    final localStreams = pc.getLocalStreams();
    if (localStreams.isNotEmpty) {
      _localRenderer.srcObject = localStreams.first;
    }
  }

  // 🎵 Send DTMF tone
  Future<void> _sendDtmf(String tone) async {
    try {
      _call?.sendDTMF(tone);
      debugPrint("🎵 Sent DTMF tone: $tone");
    } catch (e) {
      debugPrint("❌ Failed to send DTMF: $e");
    }
  }

  void _toggleDialpad() {
    setState(() => _showDialpad = !_showDialpad);
  }

  void _observeNetworkState() {
    final pc = _call?.peerConnection;
    if (pc == null) return;
    pc.onIceConnectionState = (state) {
      debugPrint('🌐 ICE State: $state');
      setState(() {
        switch (state) {
          case RTCIceConnectionState.RTCIceConnectionStateConnected:
            _networkStatus = "RTC Connected ✅";
            break;
          case RTCIceConnectionState.RTCIceConnectionStateCompleted:
            _networkStatus = "Connection Stable 💚";
            break;
          case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
            _networkStatus = "Disconnected ⚠️";
            break;
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            _networkStatus = "Network Failed ❌";
            break;
          default:
            _networkStatus = "Connecting…";
        }
      });
    };
  }

  void _startTimer() {
    if (_timer != null) return;
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed.value = _stopwatch.elapsed.inSeconds;
    });
  }

  @override
  void dispose() {
    try {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    } catch (_) {}
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _timer?.cancel();
    _elapsed.dispose();
    _ua.removeSipUaHelperListener(this);
    super.dispose();
  }

  Future<void> _toggleMute() async {
    SipProvider().toggleMute();
    setState(() {});
  }

  Future<void> _toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await SipProvider().toggleSpeaker();
    setState(() {});
  }

  Future<void> _hangup() async {
    _stopwatch.stop();
    try {
      await SipProvider().hangup();
    } catch (e) {
      debugPrint("❌ Hangup failed: $e");
    }

    if (mounted && !_hasPopped) {
      _hasPopped = true;
      if (Navigator.canPop(context)) {
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  void callStateChanged(Call call, CallState state) async {
    debugPrint('📞 Call state: ${state.state}');
    if (state.state == CallStateEnum.STREAM ||
        state.state == CallStateEnum.CONFIRMED) {
      await _attachMedia();
      _observeNetworkState();
      if (!_stopwatch.isRunning) _startTimer();
      setState(() => _networkStatus = "Call Active ✅");
    }

    if (state.state == CallStateEnum.ENDED ||
        state.state == CallStateEnum.FAILED) {
      _stopwatch.stop();
      setState(() => _networkStatus = "Call Ended 💔");
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      if (mounted && !_hasPopped) {
        _hasPopped = true;
        Navigator.of(context).maybePop();
      }
    }
  }

  // 💫 UI Build
  @override
  Widget build(BuildContext context) {
    final target = SipProvider().activeCall?.remote_identity ?? "Unknown";

    return Scaffold(
      appBar: AppBar(title: Text('In Call with $target')),
      body: Stack(
        children: [
          _buildCallBody(context, target),
          if (_showDialpad) _buildDialpadOverlay(context),
        ],
      ),
    );
  }

  Widget _buildCallBody(BuildContext context, String target) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(target, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(_networkStatus, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: _elapsed,
              builder: (_, s, __) {
                final h = (s ~/ 3600).toString().padLeft(2, '0');
                final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
                final sec = (s % 60).toString().padLeft(2, '0');
                return Text('$h:$m:$sec',
                    style: Theme.of(context).textTheme.titleLarge);
              },
            ),
            const SizedBox(height: 24),
            Expanded(child: RTCVideoView(_remoteRenderer)),
            const Spacer(),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              children: [
                _RoundAction(
                  icon: SipProvider().muted ? Icons.mic_off : Icons.mic,
                  label: SipProvider().muted ? 'Unmute' : 'Mute',
                  onTap: _toggleMute,
                ),
                _RoundAction(
                  icon: _speakerOn ? Icons.volume_off : Icons.volume_up,
                  label: _speakerOn ? 'Speaker Off' : 'Speaker On',
                  onTap: _toggleSpeaker,
                ),
                _RoundAction(
                  icon: Icons.dialpad,
                  label: 'Dialpad',
                  onTap: _toggleDialpad,
                ),
              ],
            ),
            const SizedBox(height: 36),
            if (!_showDialpad)
              IconButton(
                onPressed: _hangup,
                iconSize: 64,
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(18),
                ),
                icon: const Icon(Icons.call_end),
              ),
          ],
        ),
      ),
    );
  }

  // 🌸 Dialpad overlay
  Widget _buildDialpadOverlay(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: keys.map((k) {
                return ElevatedButton(
                  onPressed: () => _sendDtmf(k),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[850],
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(24),
                  ),
                  child: Text(
                    k,
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            IconButton(
              icon: const Icon(Icons.keyboard_hide,
                  color: Colors.white, size: 36),
              onPressed: _toggleDialpad,
            ),
          ],
        ),
      ),
    );
  }

  // unused listener hooks
  @override
  void registrationStateChanged(RegistrationState state) {}
  @override
  void transportStateChanged(TransportState state) {}
  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}
}

// 🌼 cute reusable button widget
class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon),
          iconSize: 32,
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(18),
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
