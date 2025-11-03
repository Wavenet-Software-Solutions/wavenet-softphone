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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: TextField(
                    controller: _controller,
                    readOnly: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter Number',
                      hintStyle: const TextStyle(color: Colors.white38),

                      // prefixIcon: const Icon(Icons.phone_outlined,
                      //     color: Colors.tealAccent, size: 22),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.backspace_outlined, color: Colors.white70),
                        onPressed: () {
                          setState(() {
                            _callState.backspace();
                            _controller.text = _callState.dialed;
                          });
                        },
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white38, width: 1),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.tealAccent, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
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
