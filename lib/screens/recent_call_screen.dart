import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentCallsScreen extends StatefulWidget {
  const RecentCallsScreen({super.key});

  @override
  State<RecentCallsScreen> createState() => _RecentCallsScreenState();
}

class _RecentCallsScreenState extends State<RecentCallsScreen> {
  List<Map<String, dynamic>> _recentCalls = [];

  @override
  void initState() {
    super.initState();
    _loadRecentCalls();
  }

  Future<void> _loadRecentCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final calls = prefs.getStringList('recent_calls') ?? [];
    setState(() {
      _recentCalls = calls.map((e) {
        final parts = e.split('|');
        return {
          'name': parts[0],
          'type': parts[1],
          'time': parts[2],
        };
      }).toList();
    });
  }

  IconData _getIcon(String type) {
    switch (type) {
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
    switch (type) {
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
            margin: const EdgeInsets.symmetric(
                vertical: 8, horizontal: 16),
            child: ListTile(
              leading: Icon(_getIcon(call['type']),
                  color: _getColor(call['type']), size: 28),
              title: Text(
                call['name'],
                style: const TextStyle(
                    color: Colors.white, fontSize: 16),
              ),
              subtitle: Text(
                call['time'],
                style: const TextStyle(color: Colors.white38),
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
