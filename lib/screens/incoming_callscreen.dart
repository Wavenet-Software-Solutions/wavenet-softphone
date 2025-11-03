import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../pjsip_bridge.dart';

class IncomingCallScreen extends StatefulWidget {
  final Call call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _accepted = false;
  bool _declined = false;

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _arrowOpacity;

  @override
  void initState() {
    super.initState();

    // 💫 Button pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 🌈 Arrows fading animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _arrowOpacity = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    await SipProvider().answer();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/call');
  }

  Future<void> _declineCall() async {
    await SipProvider().hangup();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset < -100) {
      setState(() => _accepted = true);
      _acceptCall();
    } else if (_dragOffset > 100) {
      setState(() => _declined = true);
      _declineCall();
    } else {
      setState(() => _dragOffset = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remote = widget.call.remote_identity ?? 'Unknown Caller';
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0f2027),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🌈 Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // 🌫️ Blur overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
            ),

            // 💫 Caller info
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_in_talk, size: 80, color: Colors.tealAccent),
                const SizedBox(height: 16),
                const Text(
                  "Incoming Call",
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  remote,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // 🌸 Floating swipe button with arrows
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final scale = _pulseAnimation.value;
                  final yOffset =
                  _dragOffset.clamp(-height * 0.15, height * 0.15);

                  return GestureDetector(
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    onVerticalDragEnd: _onVerticalDragEnd,
                    child: Transform.translate(
                      offset: Offset(0, yOffset),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ↑ Up Arrow
                          FadeTransition(
                            opacity: _arrowOpacity,
                            child: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Colors.greenAccent,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 🌟 Phone Button
                          Transform.scale(
                            scale: scale,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _dragOffset < -60
                                      ? [Colors.greenAccent, Colors.teal]
                                      : _dragOffset > 60
                                      ? [Colors.redAccent, Colors.red]
                                      : [Colors.white24, Colors.white10],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _dragOffset < -60
                                        ? Colors.greenAccent.withOpacity(0.5)
                                        : _dragOffset > 60
                                        ? Colors.redAccent.withOpacity(0.5)
                                        : Colors.black45,
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.phone,
                                  color: Colors.white, size: 38),
                            ),
                          ),

                          const SizedBox(height: 10),
                          // ↓ Down Arrow
                          FadeTransition(
                            opacity: _arrowOpacity,
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.redAccent,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 💚 Overlay when accepted or declined
            if (_accepted)
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: 1,
                  child: Container(
                    color: Colors.green.withOpacity(0.5),
                    child: const Center(
                      child: Icon(Icons.call, color: Colors.white, size: 120),
                    ),
                  ),
                ),
              ),
            if (_declined)
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: 1,
                  child: Container(
                    color: Colors.red.withOpacity(0.5),
                    child: const Center(
                      child: Icon(Icons.call_end, color: Colors.white, size: 120),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
