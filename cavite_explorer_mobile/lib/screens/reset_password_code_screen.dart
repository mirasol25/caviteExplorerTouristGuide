import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class ResetPasswordCodeScreen extends StatefulWidget {
  final String email;

  const ResetPasswordCodeScreen({super.key, required this.email});

  @override
  State<ResetPasswordCodeScreen> createState() =>
      _ResetPasswordCodeScreenState();
}

class _ResetPasswordCodeScreenState extends State<ResetPasswordCodeScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;
  int _resendSeconds = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  bool _strongPassword(String value) =>
      RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~.]).{8,}$').hasMatch(value);

  Map<String, dynamic> _decode(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendSeconds = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    if (code.length != 6)
      return _message('Enter the 6-digit reset code.', error: true);
    if (password != _confirmController.text)
      return _message('Passwords do not match.', error: true);
    if (!_strongPassword(password)) {
      return _message(
          'Use 8+ characters with an uppercase letter, number, and special character.',
          error: true);
    }
    setState(() => _loading = true);
    try {
      final response = await http.post(
        ApiService.uri('/auth/reset-password-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'email': widget.email, 'code': code, 'newPassword': password}),
      );
      final data = _decode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Password updated. Sign in with your new password.',
              style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFF176A50),
        ));
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      } else {
        _message(
            data['message']?.toString() ??
                'The reset code is invalid or expired.',
            error: true);
      }
    } catch (_) {
      if (mounted) _message('Network error. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      final response = await http.post(
        ApiService.uri('/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'client': 'mobile'}),
      );
      final data = _decode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200) {
        _codeController.clear();
        _startCooldown();
        _message('A new password reset code was sent.');
      } else {
        _message(
            data['message']?.toString() ?? 'Could not resend the reset code.',
            error: true);
      }
    } catch (_) {
      if (mounted)
        _message('Network error while resending the code.', error: true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value, style: GoogleFonts.poppins()),
      backgroundColor: error ? Colors.redAccent : const Color(0xFF176A50),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create a new password',
                  style: GoogleFonts.poppins(
                      fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  'Enter the 6-digit code sent to ${widget.email}, then choose a secure password.',
                  style: GoogleFonts.poppins(
                      fontSize: 14, height: 1.5, color: Colors.grey[600])),
              const SizedBox(height: 28),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6)
                ],
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration:
                    _decoration('6-digit reset code', Icons.password_outlined),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _passwordController,
                obscureText: _hidePassword,
                style: GoogleFonts.poppins(),
                decoration:
                    _decoration('New password', Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(_hidePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                  '8+ characters, uppercase letter, number, and special character.',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[600])),
              const SizedBox(height: 18),
              TextField(
                controller: _confirmController,
                obscureText: _hideConfirm,
                style: GoogleFonts.poppins(),
                decoration: _decoration(
                        'Confirm new password', Icons.lock_reset_outlined)
                    .copyWith(
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _hideConfirm = !_hideConfirm),
                    icon: Icon(
                        _hideConfirm ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
                onSubmitted: (_) => _loading ? null : _resetPassword(),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _loading ? null : _resetPassword,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF176A50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Update password',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _resendSeconds == 0 && !_resending ? _resend : null,
                child: Text(
                  _resending
                      ? 'Sending…'
                      : _resendSeconds > 0
                          ? 'Resend code in ${_resendSeconds}s'
                          : 'Resend reset code',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(),
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF176A50), width: 2),
        ),
      );
}
