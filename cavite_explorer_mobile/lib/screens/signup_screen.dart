import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'email_verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController(); // <-- New Controller

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true; // <-- Separate toggle for confirm field

  // --- PASSWORD VALIDATION LOGIC ---
  bool _isPasswordStrong(String password) {
    // Requires: 8+ chars, 1 uppercase, 1 number, 1 special character
    final regex = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~.]).{8,}$');
    return regex.hasMatch(password);
  }

  Future<void> _handleSignUp() async {
    // 1. Check for empty fields
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showErrorSnackBar("Please fill in all fields.");
      return;
    }

    // 2. Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar("Passwords do not match.");
      return;
    }

    // 3. Check password strength
    if (!_isPasswordStrong(_passwordController.text)) {
      _showErrorSnackBar(
          "Please ensure your password meets all security requirements.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        ApiService.uri('/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'password': _passwordController.text,
          'client': 'mobile',
        }),
      );

      final data = _decodeResponse(response.body);
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          data['accountCreated'] == true) {
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: _emailController.text.trim().toLowerCase(),
            ),
          ));
        }
      } else {
        _showErrorSnackBar(
            data['message']?.toString() ?? 'Registration failed');
      }
    } catch (e) {
      _showErrorSnackBar('Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _decodeResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Create Account",
                style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                    letterSpacing: -1.0),
              ),
              const SizedBox(height: 8),
              Text(
                "Join Cavite Explorer today.",
                style:
                    GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // --- INPUT FIELDS ---
              _buildTextField(
                  controller: _nameController,
                  label: "Full Name",
                  icon: Icons.person_outline),
              const SizedBox(height: 20),
              _buildTextField(
                  controller: _emailController,
                  label: "Email Address",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 20),

              // --- PASSWORD WITH HELPER TEXT ---
              _buildTextField(
                controller: _passwordController,
                label: "Password",
                icon: Icons.lock_outline,
                isPassword: true,
                isPrimaryPassword:
                    true, // Tells the builder to use the first obscure toggle
              ),
              Padding(
                padding:
                    const EdgeInsets.only(top: 8.0, left: 12.0, bottom: 12.0),
                child: Text(
                  "Must be 8+ characters with 1 uppercase, 1 number, and 1 special character.",
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[500]),
                ),
              ),

              // --- CONFIRM PASSWORD ---
              _buildTextField(
                controller: _confirmPasswordController,
                label: "Confirm Password",
                icon: Icons.lock_reset,
                isPassword: true,
                isPrimaryPassword:
                    false, // Tells the builder to use the second obscure toggle
              ),

              const SizedBox(height: 40),

              // --- SIGN UP BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Sign Up",
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      bool isPassword = false,
      bool isPrimaryPassword = true,
      TextInputType keyboardType = TextInputType.text}) {
    // Determine which obscure variable to use based on the field
    bool obscureCurrent =
        isPrimaryPassword ? _obscurePassword : _obscureConfirmPassword;

    return TextField(
      controller: controller,
      obscureText: isPassword && obscureCurrent,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: Colors.grey[400]),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    obscureCurrent ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[400]),
                onPressed: () {
                  setState(() {
                    if (isPrimaryPassword) {
                      _obscurePassword = !_obscurePassword;
                    } else {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    }
                  });
                },
              )
            : null,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
