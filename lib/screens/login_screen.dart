import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pjsip_bridge.dart';
import '../state/call_state.dart' as app_state;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    implements SipUaHelperListener {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _host = TextEditingController();

  String _transport = 'WSS';
  bool _loading = false;
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    final sip = SipProvider();
    sip.addSipListener(this);
    _username.addListener(_onInputChanged);
    _password.addListener(_onInputChanged);
    _host.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    SipProvider().removeSipListener(this);
    _username.dispose();
    _password.dispose();
    _host.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (!_loading) {
      setState(() {
        _hasInput = _username.text.isNotEmpty &&
            _password.text.isNotEmpty &&
            _host.text.isNotEmpty;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_loading) return;
    setState(() => _loading = true);

    final user = _username.text.trim();
    final pass = _password.text.trim();
    final host = _host.text.trim();

    try {
      await SipProvider().register(user, pass, host);
      debugPrint("🔧 Registering SIP user $user@$host ...");
    } catch (e, s) {
      debugPrint("❌ SIP login failed: $e\n$s");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login failed: $e')));
      setState(() => _loading = false);
    }
  }

  // 🌸 SIPUAHelper callbacks
  @override
  void registrationStateChanged(RegistrationState state) async {
    debugPrint("📡 Registration: ${state.state}");
    if (state.state == RegistrationStateEnum.REGISTERED) {
      setState(() => _loading = false);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', _username.text);
      await prefs.setString('password', _password.text);
      await prefs.setString('host', _host.text);
      await prefs.setString('transport', _transport);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
            (route) => false,
        arguments: app_state.CallState()
          ..setAccount(
            u: _username.text,
            p: _password.text,
            h: _host.text,
            t: _transport,
          ),
      );
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Registration failed: ${state.cause ?? 'unknown'}')),
      );
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {}
  @override
  void transportStateChanged(TransportState state) {}
  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0f2027), Color(0xff203a43), Color(0xff2c5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: Colors.white.withOpacity(0.1),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        const Icon(Icons.phone_in_talk,
                            size: 64, color: Colors.white70),
                        const SizedBox(height: 8),
                        Text(
                          'Wavenet Softphone',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to your SIP account',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 24),

                        // Username
                        _buildTextField(
                          controller: _username,
                          label: 'SIP Username',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),

                        // Password
                        _buildTextField(
                          controller: _password,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscure: true,
                        ),
                        const SizedBox(height: 16),

                        // Host
                        _buildTextField(
                          controller: _host,
                          label: 'PBX Host (e.g. 192.168.1.110)',
                          icon: Icons.dns_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Transport Dropdown
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _transport,
                            dropdownColor: Colors.black87,
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Transport',
                              labelStyle: TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                              contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'WSS',
                                  child: Text('WSS (Secure WebSocket)')),
                              DropdownMenuItem(
                                  value: 'WS',
                                  child: Text('WS (WebSocket)')),
                            ],
                            onChanged: (v) =>
                                setState(() => _transport = v ?? 'WSS'),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: _loading
                                  ? [Colors.grey, Colors.grey.shade700]
                                  : [Colors.tealAccent.shade400, Colors.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: (_loading || !_hasInput) ? null : _submit,
                            icon: _loading
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.login, color: Colors.white),
                            label: Text(
                              _loading ? "Connecting…" : "Sign In",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Powered by Wavenet 💙',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.tealAccent),
        ),
      ),
    );
  }
}
