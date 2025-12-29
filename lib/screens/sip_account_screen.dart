import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pjsip_bridge.dart';

class SipAccountScreen extends StatefulWidget {
  const SipAccountScreen({super.key});

  @override
  State<SipAccountScreen> createState() => _SipAccountScreenState();
}

class _SipAccountScreenState extends State<SipAccountScreen> {
  String _username = '-';
  String _host = '-';
  String _transport = '-';

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? '-';
      _host = prefs.getString('host') ?? '-';
      _transport = prefs.getString('transport') ?? '-';
    });
  }

  Color _statusColor(String status) {
    if (status.contains('REGISTERED')) return Colors.greenAccent;
    if (status.contains('CONNECTING')) return Colors.orangeAccent;
    if (status.contains('FAILED') || status.contains('ERROR')) {
      return Colors.redAccent;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final sip = context.watch<SipProvider>();
    final status = sip.status;

    return Scaffold(
      appBar: AppBar(title: const Text('SIP Account')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Account'),
            _infoTile('Username', _username),
            _infoTile('Host', _host),
            _infoTile('Transport', _transport),

            const SizedBox(height: 24),

            _sectionTitle('Connection Status'),
            Row(
              children: [
                Icon(Icons.circle, size: 14, color: _statusColor(status)),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 16,
                    color: _statusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const Spacer(),

            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Re-register SIP'),
              onPressed: () {
                sip.reRegister();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _infoTile(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(color: Colors.white70)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
