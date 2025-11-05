import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';
import '../pjsip_bridge.dart';
import 'package:flutter/services.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> implements SipUaHelperListener {
  late SIPUAHelper _ua;
  Call? _call;
  bool _speakerOn = false;
  bool _hasPopped = false;
  bool _showDialpad = false; // 🌸 toggle state

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
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _attachMedia() async {
    if (_call == null) {
      debugPrint("⚠️ No call yet, skipping attachMedia");
      return;
    }

    final pc = _call!.peerConnection;
    if (pc == null) {
      debugPrint("⚠️ No PeerConnection yet");
      return;
    }

    // 💫 Attach remote streams
    final remoteStreams = pc.getRemoteStreams();
    if (remoteStreams.isNotEmpty) {
      final stream = remoteStreams.first;

      final hasVideo = (stream?.getVideoTracks()?.isNotEmpty ?? false);

      if (hasVideo) {
        debugPrint("🎥 Attaching remote video stream...");
        _remoteRenderer.srcObject = stream;
      } else {
        debugPrint("🔈 Remote audio-only call — skipping video attach.");
      }
    }

    // 💫 Attach local streams
    final localStreams = pc.getLocalStreams();
    if (localStreams.isNotEmpty) {
      final stream = localStreams.first;

      final hasVideo = (stream?.getVideoTracks().isNotEmpty ?? false);

      if (hasVideo) {
        debugPrint("📹 Attaching local video stream...");
        _localRenderer.srcObject = stream;
      } else {
        debugPrint("🎤 Local audio-only call — skipping local video attach.");
      }
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
      if (!_stopwatch.isRunning) _startTimer();
    }

    if (state.state == CallStateEnum.ENDED ||
        state.state == CallStateEnum.FAILED) {
      _stopwatch.stop();
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
          if (_showDialpad) _buildDialpadOverlay(),
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
            ValueListenableBuilder<String>(
              valueListenable: SipProvider().callConnectionInfo,
              builder: (context, status, _) {
                return Text(
                  status,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                );
              },
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: SipProvider().elapsedSeconds,
              builder: (context, seconds, _) {
                final mm = (seconds ~/ 60).toString().padLeft(2, '0');
                final ss = (seconds % 60).toString().padLeft(2, '0');
                return Text(
                  "$mm:$ss",
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                );
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
  Widget _buildDialpadOverlay() {
    const dialKeys = [
      ['1', ''],
      ['2', 'ABC'],
      ['3', 'DEF'],
      ['4', 'GHI'],
      ['5', 'JKL'],
      ['6', 'MNO'],
      ['7', 'PQRS'],
      ['8', 'TUV'],
      ['9', 'WXYZ'],
      ['*', ''],
      ['0', '+'],
      ['#', ''],
    ];

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0f2027).withOpacity(0.95),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🌸 Dial buttons in grid
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 22,
                  crossAxisSpacing: 22,
                ),
                itemCount: dialKeys.length,
                itemBuilder: (context, index) {
                  final key = dialKeys[index][0];
                  final letters = dialKeys[index][1];

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 1.0),
                    duration: const Duration(milliseconds: 150),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            splashColor: Colors.tealAccent.withOpacity(0.2),
                            highlightColor: Colors.tealAccent.withOpacity(0.05),
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              _sendDtmf(key);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.08),
                                border: Border.all(color: Colors.white24),
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    key,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (letters.isNotEmpty)
                                    Text(
                                      letters,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        height: 0.9,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // 🔙 Hide keypad button
            IconButton(
              icon: const Icon(Icons.keyboard_hide,
                  color: Colors.white70, size: 36),
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
