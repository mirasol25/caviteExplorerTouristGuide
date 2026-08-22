import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendSeconds = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

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

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showMessage('Enter the 6-digit code from your email.', error: true);
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final response = await http.post(
        ApiService.uri('/auth/verify-email-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'code': code}),
      );
      final data = _decode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Email verified. You can now sign in.',
              style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFF176A50),
        ));
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      } else {
        _showMessage(
            data['message']?.toString() ?? 'The code is invalid or expired.',
            error: true);
      }
    } catch (_) {
      if (mounted)
        _showMessage('Network error. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      final response = await http.post(
        ApiService.uri('/auth/resend-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'client': 'mobile'}),
      );
      final data = _decode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200) {
        _codeController.clear();
        _startCooldown();
        _showMessage('A new verification code was sent.');
      } else {
        _showMessage(
            data['message']?.toString() ?? 'Could not resend the code.',
            error: true);
      }
    } catch (_) {
      if (mounted)
        _showMessage('Network error while resending the code.', error: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.poppins()),
      backgroundColor: error ? Colors.redAccent : const Color(0xFF176A50),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: Color(0xFFE4F3EC),
                child: Icon(Icons.mark_email_read_outlined,
                    size: 36, color: Color(0xFF176A50)),
              ),
              const SizedBox(height: 24),
              Text('Verify your email',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text('Enter the 6-digit code sent to\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 14, height: 1.5, color: Colors.grey[600])),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6)
                ],
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 10),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle:
                      TextStyle(color: Colors.grey[300], letterSpacing: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide:
                        const BorderSide(color: Color(0xFF176A50), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
                onSubmitted: (_) => _isVerifying ? null : _verify(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isVerifying ? null : _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF176A50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isVerifying
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Verify email',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed:
                    _resendSeconds == 0 && !_isResending ? _resend : null,
                child: Text(
                  _isResending
                      ? 'Sending…'
                      : _resendSeconds > 0
                          ? 'Resend code in ${_resendSeconds}s'
                          : 'Resend verification code',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (_) => false),
                child: Text('Back to sign in',
                    style: GoogleFonts.poppins(color: Colors.grey[700])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
