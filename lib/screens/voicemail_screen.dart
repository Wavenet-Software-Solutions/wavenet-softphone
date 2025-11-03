import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class VoicemailScreen extends StatefulWidget {
  const VoicemailScreen({super.key});

  @override
  State<VoicemailScreen> createState() => _VoicemailScreenState();
}

class _VoicemailScreenState extends State<VoicemailScreen> {
  List<Map<String, dynamic>> _voicemails = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlaying;

  @override
  void initState() {
    super.initState();
    _loadVoicemails();
  }

  Future<void> _loadVoicemails() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('voicemails') ?? [];
    setState(() {
      _voicemails = saved.map((v) {
        final parts = v.split('|');
        return {
          'caller': parts[0],
          'timestamp': parts.length > 1 ? parts[1] : '',
          'path': parts.length > 2 ? parts[2] : '',
        };
      }).toList();
    });
  }

  Future<void> _deleteVoicemail(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _voicemails.removeAt(index);
    final encoded = _voicemails.map((v) => "${v['caller']}|${v['timestamp']}|${v['path']}").toList();
    await prefs.setStringList('voicemails', encoded);
    setState(() {});
  }

  Future<void> _playVoicemail(String path) async {
    try {
      if (_currentlyPlaying == path) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlaying = null);
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() => _currentlyPlaying = path);
      }
    } catch (e) {
      debugPrint("🎧 Error playing voicemail: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to play voicemail")),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0f2027),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("📩 Voicemail"),
        centerTitle: true,
        elevation: 0,
      ),
      body: _voicemails.isEmpty
          ? const Center(
        child: Text(
          "No voicemails yet 🎶",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      )
          : ListView.builder(
        itemCount: _voicemails.length,
        itemBuilder: (context, index) {
          final v = _voicemails[index];
          final isPlaying = _currentlyPlaying == v['path'];
          return Card(
            color: Colors.white.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isPlaying ? Colors.tealAccent : Colors.white24,
                child: Icon(
                  isPlaying ? Icons.play_arrow : Icons.record_voice_over,
                  color: Colors.black87,
                ),
              ),
              title: Text(
                v['caller'] ?? 'Unknown Caller',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                v['timestamp'] ?? '',
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.stop : Icons.play_circle,
                      color: Colors.tealAccent,
                    ),
                    onPressed: () => _playVoicemail(v['path']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteVoicemail(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
