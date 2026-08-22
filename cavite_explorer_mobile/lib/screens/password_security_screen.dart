import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class PasswordSecurityScreen extends StatefulWidget {
  final String email;

  const PasswordSecurityScreen({super.key, required this.email});

  @override
  State<PasswordSecurityScreen> createState() => _PasswordSecurityScreenState();
}

class _PasswordSecurityScreenState extends State<PasswordSecurityScreen> {
  bool _isLoading = false;
  bool _emailSent = false;

  Future<void> _sendPasswordReset() async {
    setState(() => _isLoading = true);

    try {
      // Calling the endpoint you already built in your NestJS AuthController!
      final response = await http.post(
        ApiService.uri('/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _emailSent = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Reset link sent! Check your inbox.", style: GoogleFonts.poppins()), 
              backgroundColor: Colors.green
            ),
          );
        }
      } else {
        _showError("Failed to send reset link. Please try again.");
      }
    } catch (e) {
      _showError("Network error. Please check your connection.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins()), backgroundColor: Colors.redAccent)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Password & Security", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline, size: 80, color: Colors.blueAccent),
            ),
            const SizedBox(height: 32),
            Text("Update Your Password", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
            const SizedBox(height: 12),
            Text(
              "Because your security is our top priority, your password is encrypted and securely managed by Neon Auth.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 24),
            
            // Display the email that will receive the link
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Reset link will be sent to:", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text(widget.email, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // --- SEND LINK BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_isLoading || _emailSent) ? null : _sendPasswordReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emailSent ? Colors.green : Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _emailSent ? "Link Sent" : "Send Password Reset Link", 
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)
                      ),
              ),
            ),

            if (_emailSent) ...[
              const SizedBox(height: 16),
              Text(
                "You can safely close this screen and check your email.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.green),
              )
            ]
          ],
        ),
      ),
    );
  }
}
