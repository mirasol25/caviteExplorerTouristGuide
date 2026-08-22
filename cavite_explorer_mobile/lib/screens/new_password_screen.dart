import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class NewPasswordScreen extends StatefulWidget {
  final String token; // We receive the token from the deep link!

  const NewPasswordScreen({super.key, required this.token});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isPasswordStrong(String password) {
    final regex = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~.]).{8,}$');
    return regex.hasMatch(password);
  }

  Future<void> _handleSavePassword() async {
    if (_passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      _showErrorSnackBar("Please fill in all fields.");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar("Passwords do not match.");
      return;
    }

    if (!_isPasswordStrong(_passwordController.text)) {
      _showErrorSnackBar("Please ensure your password meets all security requirements.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        ApiService.uri('/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.token, // Pass the token to NestJS
          'newPassword': _passwordController.text, // Pass the new password
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Password updated successfully! Please log in.", style: GoogleFonts.poppins()), backgroundColor: Colors.green),
          );
          // Kick them back to the login screen so they can use their new password!
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorSnackBar(errorData['message'] ?? 'Failed to update password.');
      }
    } catch (e) {
      _showErrorSnackBar('Network error. Is the backend running?');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins()), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Force them to finish or close app
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Set New Password", style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A), letterSpacing: -1.0)),
              const SizedBox(height: 8),
              Text("Please enter your new secure password below.", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
              const SizedBox(height: 40),
              
              _buildTextField(
                controller: _passwordController, 
                label: "New Password", 
                icon: Icons.lock_outline, 
                isPrimaryPassword: true,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 12.0, bottom: 12.0),
                child: Text(
                  "Must be 8+ characters with 1 uppercase, 1 number, and 1 special character.",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
              
              _buildTextField(
                controller: _confirmPasswordController, 
                label: "Confirm Password", 
                icon: Icons.lock_reset, 
                isPrimaryPassword: false,
              ),
              
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSavePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Save Password", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    bool isPrimaryPassword = true,
  }) {
    bool obscureCurrent = isPrimaryPassword ? _obscurePassword : _obscureConfirmPassword;

    return TextField(
      controller: controller,
      obscureText: obscureCurrent,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: Colors.grey[400]),
        suffixIcon: IconButton(
          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400]),
          onPressed: () {
            setState(() {
              if (isPrimaryPassword) _obscurePassword = !_obscurePassword;
              else _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
