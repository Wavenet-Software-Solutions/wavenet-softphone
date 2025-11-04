import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f2027),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("About Wavenet"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),

            // 🌊 App Logo
            Hero(
              tag: "app_logo",
              child: Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.tealAccent.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  image: const DecorationImage(
                    image: AssetImage("assets/icons/app_icon.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Wavenet Softphone",
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 6),
            const Text(
              "Version 1.0.0",
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),

            const SizedBox(height: 32),

            // 🧠 About Description
            const Text(
              "Wavenet Softphone brings a seamless VoIP experience to mobile with PJSIP integration. "
                  "Built with Flutter 💙 for fast, reliable, and cross-platform communication.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 40),

            // 🪄 Divider line
            Container(
              height: 1,
              color: Colors.white12,
              margin: const EdgeInsets.symmetric(vertical: 12),
            ),

            // ⚙️ Info Cards
            _infoCard(
              icon: Icons.policy_rounded,
              title: "Privacy Policy",
              subtitle: "Read how we protect your data and privacy.",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              ),
            ),
            _infoCard(
              icon: Icons.description_rounded,
              title: "Terms & Conditions",
              subtitle: "Understand the terms of using our app.",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsPage()),
              ),
            ),
            _infoCard(
              icon: Icons.history_rounded,
              title: "Legacy",
              subtitle: "Learn about our mission and journey.",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegacyPage()),
              ),
            ),

            const SizedBox(height: 20),

            // 👋 Footer
            const Text(
              "© 2025 Wavenet Technologies",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: Colors.tealAccent, size: 30),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        trailing:
        const Icon(Icons.chevron_right_rounded, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f2027),
      appBar: AppBar(
        title: const Text("Privacy Policy"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          "Your privacy is important to us. We ensure that your communication "
              "data is never stored on our servers and is transmitted securely over encrypted channels. "
              "No personal data is shared with third parties without explicit consent.\n\n"
              "By using Wavenet Softphone, you agree to our terms and policies "
              "to provide the best call experience while keeping your information safe.",
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
        ),
      ),
    );
  }
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f2027),
      appBar: AppBar(
        title: const Text("Terms & Conditions"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          "By using Wavenet Softphone, you agree to the following terms:\n\n"
              "1. This app is provided as-is without any warranty of any kind.\n"
              "2. You are responsible for ensuring the legality of VoIP usage in your region.\n"
              "3. We do not store or intercept call data, logs, or credentials.\n"
              "4. You agree not to misuse or distribute the application for unlawful purposes.\n"
              "5. Wavenet Technologies is not liable for data loss, call disruptions, or damages resulting from app use.\n\n"
              "These terms may be updated periodically without prior notice. "
              "Continued use of the app indicates acceptance of the updated terms.",
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
        ),
      ),
    );
  }
}

class LegacyPage extends StatelessWidget {
  const LegacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f2027),
      appBar: AppBar(
        title: const Text("Our Legacy"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          "Wavenet Softphone was built to make communication simple, beautiful, "
              "and secure for everyone. From our early days in VoIP research to building "
              "modern SIP and WebRTC-based communication solutions — our mission remains the same: "
              "to connect people effortlessly across the world.\n\n"
              "Powered by open technologies and the creativity of passionate developers, "
              "we continue to innovate with love 💙.",
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
        ),
      ),
    );
  }
}
