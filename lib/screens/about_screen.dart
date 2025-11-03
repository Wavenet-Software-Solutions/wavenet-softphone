import 'package:flutter/material.dart';


class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text("📡 Wavenet Softphone v1.0\nPowered by Flutter 💙",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 18)),
    );
  }
}
