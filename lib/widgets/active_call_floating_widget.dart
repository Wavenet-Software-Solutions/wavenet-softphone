import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pjsip_bridge.dart';

class ActiveCallFloatingWidget extends StatefulWidget {
  const ActiveCallFloatingWidget({super.key});

  @override
  State<ActiveCallFloatingWidget> createState() => _ActiveCallFloatingWidgetState();
}

class _ActiveCallFloatingWidgetState extends State<ActiveCallFloatingWidget> {
  Offset position = const Offset(20, 400);
  Offset dragStartOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final sip = context.watch<SipProvider>();
    final call = sip.activeCall;
    if (call == null) return const SizedBox.shrink();

    // 🕐 Format elapsed time
    final elapsed = sip.callDuration.inSeconds;
    final mm = (elapsed ~/ 60).toString().padLeft(2, '0');
    final ss = (elapsed % 60).toString().padLeft(2, '0');

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanStart: (details) {
          dragStartOffset = details.globalPosition - position;
        },
        onPanUpdate: (details) {
          setState(() {
            position = details.globalPosition - dragStartOffset;
          });
        },
        onPanEnd: (_) {
          final size = MediaQuery.of(context).size;
          setState(() {
            position = Offset(
              position.dx.clamp(0, size.width - 120),
              position.dy.clamp(0, size.height - 160),
            );
          });
        },
        onTap: () {
          Navigator.of(context).pushNamed('/call');
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 120,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.tealAccent.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 44),
                  const SizedBox(height: 8),
                  // 🩵 Caller number (no underline or decoration)
                  Text(
                    call.remote_identity ?? "Unknown",
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      decoration: TextDecoration.none, // 🚫 remove underline
                    ),
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<int>(
                    valueListenable: sip.elapsedSeconds,
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

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
