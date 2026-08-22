import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'partner_dashboard_screen.dart';

class PartnerInviteScreen extends StatefulWidget {
  final String token;
  const PartnerInviteScreen({super.key, required this.token});

  @override
  State<PartnerInviteScreen> createState() => _PartnerInviteScreenState();
}

class _PartnerInviteScreenState extends State<PartnerInviteScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, dynamic>? _invite;
  String? _error;
  bool _loading = true;
  bool _submitting = false;
  bool _showPassword = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final response = await http.get(ApiService.uri('/auth/invitations/${Uri.encodeComponent(widget.token)}'));
      final body = json.decode(response.body);
      if (response.statusCode != 200 || body['role'] != 'partner') throw Exception(body['message'] ?? 'This is not a valid partner invitation.');
      _invite = Map<String, dynamic>.from(body);
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _submit() async {
    if (_password.text.length < 8) return _message('Use at least 8 characters.');
    if (_password.text != _confirm.text) return _message('Passwords do not match.');
    setState(() => _submitting = true);
    try {
      final accepted = await http.post(ApiService.uri('/auth/invitations/accept'), headers: {'Content-Type': 'application/json'}, body: json.encode({'token': widget.token, 'password': _password.text}));
      final acceptedBody = json.decode(accepted.body);
      if (accepted.statusCode < 200 || accepted.statusCode >= 300) throw Exception(acceptedBody['message'] ?? 'Could not create the account.');
      if (acceptedBody['token'] != null && acceptedBody['user'] is Map) {
        final user = Map<String, dynamic>.from(acceptedBody['user']);
        await AuthService.saveUser(user['name']?.toString() ?? 'Partner', user['email']?.toString() ?? '', acceptedBody['token'].toString(), role: user['role']?.toString() ?? 'partner');
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PartnerDashboardScreen()), (_) => false);
        return;
      }
      final login = await http.post(ApiService.uri('/auth/login'), headers: {'Content-Type': 'application/json'}, body: json.encode({'email': _invite?['email'], 'password': _password.text}));
      final loginBody = json.decode(login.body);
      if (login.statusCode != 200) throw Exception('Account created. Verify your email if requested, then sign in in the app.');
      final user = Map<String, dynamic>.from(loginBody['user']);
      await AuthService.saveUser(user['name']?.toString() ?? 'Partner', user['email']?.toString() ?? '', loginBody['token'], role: user['role']?.toString() ?? 'partner');
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PartnerDashboardScreen()), (_) => false);
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() { _password.dispose(); _confirm.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F7F4),
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: _loading
      ? const Center(child: CircularProgressIndicator())
      : _error != null ? _card(children: [const Icon(Icons.link_off_rounded, size: 48, color: Colors.redAccent), const SizedBox(height: 14), Text(_error!, textAlign: TextAlign.center)])
      : _card(children: [
          const CircleAvatar(radius: 31, backgroundColor: Color(0xFFE4F2E8), child: Icon(Icons.storefront_rounded, color: Color(0xFF176A50), size: 32)),
          const SizedBox(height: 18),
          Text('Join as a partner', style: GoogleFonts.poppins(fontSize: 27, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Create your password, then submit your business and location for administrator approval.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 22),
          TextFormField(initialValue: _invite?['email']?.toString(), enabled: false, decoration: _decoration('Invited email', Icons.email_outlined)),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: !_showPassword, decoration: _decoration('Create password', Icons.lock_outline).copyWith(suffixIcon: IconButton(onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
          const SizedBox(height: 12),
          TextField(controller: _confirm, obscureText: !_showPassword, decoration: _decoration('Confirm password', Icons.lock_outline)),
          const SizedBox(height: 20),
          SizedBox(height: 54, width: double.infinity, child: FilledButton(onPressed: _submitting ? null : _submit, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF176A50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _submitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create partner account'))),
        ]))))),
  );

  Widget _card({required List<Widget> children}) => Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(27), border: Border.all(color: const Color(0xFFDDE5E0))), child: Column(mainAxisSize: MainAxisSize.min, children: children));
  InputDecoration _decoration(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon), filled: true, fillColor: const Color(0xFFF8FAF8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));
}
