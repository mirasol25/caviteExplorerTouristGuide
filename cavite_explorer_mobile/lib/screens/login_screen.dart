import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'dart:convert'; 
import 'package:http/http.dart' as http; 


// Make sure these paths match your project structure!
import '../services/auth_service.dart';
import '../screens/signup_screen.dart'; 
import '../screens/forgot_password_screen.dart';
import '../screens/new_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // --- DEEP LINK VARIABLES ---
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks(); // Listen for Google OAuth redirect
  }

  // --- 1. GOOGLE LOGIN HANDLER (DEEP LINKS) ---
  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
      
      // --- 1. HANDLE GOOGLE LOGIN CALLBACK ---
      if (uri.scheme == 'caviteexplorer' && uri.host == 'login-callback') {
        
        final error = uri.queryParameters['error'];
        if (error != null) {
          print("Login canceled or failed: $error");
          return; 
        }

        final token = uri.queryParameters['token'];

        if (token != null && token.isNotEmpty) {
          try {
            // Trade token for profile data from NestJS
            final response = await http.get(
              Uri.parse('http://10.0.2.2:3000/auth/me'),
              headers: {
                'Authorization': 'Bearer $token', 
              },
            );

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final name = data['user']['name'] ?? 'Explorer';
              final email = data['user']['email'] ?? '';
              final role = data['user']['role'] ?? 'user';

              // Save session and navigate to Home
              await AuthService.saveUser(name, email, token, role: role);
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            } else {
              print("Failed to fetch profile: ${response.statusCode}");
            }
          } catch (e) {
            print("Network error fetching profile: $e");
          }
        }
      } 
      // --- 2. HANDLE PASSWORD RESET CALLBACK (NEW!) ---
      else if (uri.scheme == 'caviteexplorer' && uri.host == 'reset-password') {
        
        final error = uri.queryParameters['error'];
        if (error != null) {
          _showErrorSnackBar("Invalid or expired reset link.");
          return;
        }

        final token = uri.queryParameters['token'];
        
        if (token != null && token.isNotEmpty) {
          // Send the user to the New Password screen, carrying the token with them!
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewPasswordScreen(token: token),
            ),
          );
        }
      }
      
    });
  }

  Future<void> _handleGoogleLogin() async {
    final Uri backendUrl = Uri.parse('http://10.0.2.2:3000/auth/google?client=mobile');
    
    try {
      if (!await launchUrl(backendUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch backend auth url');
      }
    } catch (e) {
      print("Error launching URL: $e");
    }
  }

  // --- 2. MANUAL EMAIL LOGIN HANDLER ---
  Future<void> _handleEmailLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackBar("Please enter your email and password.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:3000/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final name = data['user']['name'] ?? 'Explorer';
        final email = data['user']['email'] ?? '';
        final role = data['user']['role'] ?? 'user';

        await AuthService.saveUser(name, email, token, role: role);

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorSnackBar(errorData['message'] ?? 'Login failed. Please check your credentials.');
      }
    } catch (e) {
      _showErrorSnackBar('Network error. Is the backend running?');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- UTILS ---
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins()), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel(); 
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- UI BUILDER ---
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  'assets/images/cavite-explorer-logo.png',
                  width: 112,
                  height: 112,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              // --- HEADER ---
              Text(
                "Welcome Back",
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Sign in to continue exploring Cavite.",
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
              ),
              
              const SizedBox(height: 50),

              // --- INPUT FIELDS ---
              _buildTextField(
                controller: _emailController,
                label: "Email Address",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _passwordController,
                label: "Password",
                icon: Icons.lock_outline,
                isPassword: true,
              ),

              // --- FORGOT PASSWORD ---
              // --- FORGOT PASSWORD ---
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Slide the Forgot Password screen into view!
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                    );
                  },
                  child: Text(
                    "Forgot Password?",
                    style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // --- MANUAL SIGN IN BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailLogin, // Wired up!
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Sign In",
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 40),
              
              // --- DIVIDER ---
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text("OR", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 24),

              // --- GOOGLE OAUTH BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                  icon: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                    height: 24,
                  ),
                  label: Text(
                    "Continue with Google",
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // --- SIGN UP LINK ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: GoogleFonts.poppins(color: Colors.grey[600])),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: Text(
                      "Sign Up",
                      style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: Colors.grey[400]),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[400],
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    ); 
  }
}
