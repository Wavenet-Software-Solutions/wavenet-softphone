import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pjsip_bridge.dart';

class RecentCallsScreen extends StatefulWidget {
  const RecentCallsScreen({super.key});

  @override
  State<RecentCallsScreen> createState() => _RecentCallsScreenState();
}

class _RecentCallsScreenState extends State<RecentCallsScreen> {
  List<Map<String, dynamic>> _recentCalls = [];
  late SipProvider sip;
  bool _disposed = false; // 🛡️ extra safety

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ Attach listener only once
    sip = Provider.of<SipProvider>(context, listen: false);
    sip.removeListener(_loadRecentCalls); // remove old to prevent duplicates
    sip.addListener(_loadRecentCalls);
  }

  @override
  void initState() {
    super.initState();
    _loadRecentCalls();
  }

  @override
  void dispose() {
    _disposed = true;
    sip.removeListener(_loadRecentCalls);
    super.dispose();
  }

  Future<void> _loadRecentCalls() async {
    // prevent updates after dispose or during logout
    if (_disposed) return;

    final prefs = await SharedPreferences.getInstance();
    final calls = prefs.getStringList('recent_calls') ?? [];

    if (!mounted || _disposed) return;

    setState(() {
      _recentCalls = calls.map((e) {
        final parts = e.split('|');
        return {
          'name': parts[0],
          'type': parts[1],
          'time': parts.length > 2 ? parts[2] : '',
          'duration': parts.length > 3 ? parts[3] : '',
        };
      }).toList();
    });
  }

  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'outgoing':
        return Icons.call_made;
      case 'incoming':
        return Icons.call_received;
      case 'missed':
        return Icons.call_missed;
      default:
        return Icons.phone;
    }
  }

  Color _getColor(String type) {
    switch (type.toLowerCase()) {
      case 'outgoing':
        return Colors.tealAccent;
      case 'incoming':
        return Colors.greenAccent;
      case 'missed':
        return Colors.redAccent;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f2027),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("🕘 Recent Calls"),
        centerTitle: true,
        elevation: 0,
      ),
      body: _recentCalls.isEmpty
          ? const Center(
        child: Text(
          "No recent calls yet 💭",
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      )
          : ListView.builder(
        itemCount: _recentCalls.length,
        itemBuilder: (context, i) {
          final call = _recentCalls[i];
          return Card(
            color: Colors.white.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              leading: Icon(
                _getIcon(call['type']),
                color: _getColor(call['type']),
                size: 28,
              ),
              title: Text(
                call['name'],
                style:
                const TextStyle(color: Colors.white, fontSize: 16),
              ),
              subtitle: Text(
                "Duration: ${call['duration'] ?? '—'}",
                style: const TextStyle(
                    color: Colors.white38, fontSize: 13),
              ),
              trailing: const Icon(Icons.phone_forwarded,
                  color: Colors.white24, size: 18),
            ),
          );
        },
      ),
    );
  }
}
