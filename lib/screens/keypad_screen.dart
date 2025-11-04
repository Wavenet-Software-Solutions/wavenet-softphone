import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../widgets/numpad.dart';
import '../state/call_state.dart' as app_state;
import '../pjsip_bridge.dart';
import 'package:permission_handler/permission_handler.dart';

class KeypadScreen extends StatefulWidget {
  const KeypadScreen({super.key});

  @override
  State<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<KeypadScreen> {
  app_state.CallState _callState = app_state.CallState();
  final TextEditingController _controller = TextEditingController();
  late final SIPUAHelper _ua;

  @override
  void initState() {
    super.initState();
    _ua = SipProvider().helper;
    _controller.text = _callState.dialed;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is app_state.CallState) {
        setState(() {
          _callState = args;
          _controller.text = _callState.dialed;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 📞 Make a SIP call
  Future<void> _call() async {
    final number = _callState.dialed.trim();
    final mic = await Permission.microphone.request();
    final cam = await Permission.camera.request();

    if (mic.isPermanentlyDenied || cam.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }

    if (!mic.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Microphone permission denied')),
      );
      return;
    }

    if (!cam.isGranted) {
      debugPrint("⚠️ Camera denied, continuing audio-only mode");
    }

    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a number first')),
      );
      return;
    }

    final host = _callState.host.isNotEmpty
        ? _callState.host
        : '192.168.1.110';

    final target = 'sip:$number@$host';
    debugPrint('📞 Dialing $target ...');

    try {
      await SipProvider().makeCall(target);
      _callState.dialed = number;
      _callState.setInCall(true);
      if (!mounted) return;

      final result = await Navigator.of(context).pushNamed('/call', arguments: _callState);

      if (result is Map) {
        final Duration d = result['duration'] ?? Duration.zero;
        final status = result['status'] ?? 'Unknown';
        final hh = d.inHours.toString().padLeft(2, '0');
        final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
        final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.black.withOpacity(0.9),
              title: const Text('📞 Call Summary', style: TextStyle(color: Colors.white)),
              content: Text(
                'Duration: $hh:$mm:$ss\nStatus: $status',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(color: Colors.tealAccent)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to make call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start call: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // 🌌 Beautiful dark gradient background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0f2027), Color(0xff203a43), Color(0xff2c5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                // 💫 Title
                const Text(
                  'Dial Pad',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // 🔢 Number display
              // 🔢 Number display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✨ Borderless text field
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        readOnly: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.2,
                          decoration: TextDecoration.none,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter number',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 20),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),

                    // 🔙 Backspace icon beside number field
            AnimatedBackspaceButton(
              onTap: () {
                setState(() {
                  _callState.backspace();
                  _controller.text = _callState.dialed;
                });
              },
              onHoldClear: () {
                setState(() {
                  _callState.clear();
                  _controller.clear();
                });
              },
              isActive: _controller.text.isNotEmpty,
            ),
                  ],
                ),
              ),


                const SizedBox(height: 30),

                // 🔢 Numpad
                Expanded(
                  child: Numpad(
                    onDigit: (d) {
                      setState(() {
                        _callState.appendDigit(d);
                        _controller.text = _callState.dialed;
                      });
                    },
                    onBackspace: () {
                      setState(() {
                        _callState.backspace();
                        _controller.text = _callState.dialed;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // 🌿 Call button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(60),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(60),
                      ),
                    ),
                    onPressed: _call,
                    icon: const Icon(Icons.call, color: Colors.white, size: 28),
                    label: const Text(
                      'Call',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class AnimatedBackspaceButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onHoldClear;
  final bool isActive;

  const AnimatedBackspaceButton({
    super.key,
    required this.onTap,
    required this.onHoldClear,
    required this.isActive,
  });

  @override
  State<AnimatedBackspaceButton> createState() => _AnimatedBackspaceButtonState();
}

class _AnimatedBackspaceButtonState extends State<AnimatedBackspaceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<Color?> _color;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _scale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _color = ColorTween(
      begin: Colors.white54,
      end: Colors.tealAccent,
    ).animate(_controller);
  }

  void _startHold() {
    _controller.forward();
    _holdTimer = Timer(const Duration(seconds: 1), () {
      HapticFeedback.mediumImpact();
      widget.onHoldClear();
    });
  }

  void _endHold() {
    _controller.reverse();
    _holdTimer?.cancel();
  }

  @override
  void dispose() {
    _controller.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _endHold(),
      onTapCancel: _endHold,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Transform.scale(
          scale: _scale.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _color.value!.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.backspace_rounded,
              color: widget.isActive ? _color.value : Colors.white24,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
