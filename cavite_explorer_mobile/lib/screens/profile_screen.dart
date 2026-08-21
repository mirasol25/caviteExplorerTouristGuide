import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/saved_trips_screen.dart'; // Adjust the path if your folder structure is slightly different

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _name;
  String? _email;
  bool _isLoading = true;
  
  // Map to hold all the extra data from the database
  Map<String, dynamic> _fullProfileData = {};

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // --- CHECK IF USER IS LOGGED IN & FETCH LIVE DATA ---
  Future<void> _checkLoginStatus() async {
    final userData = await AuthService.getUser();
    
    if (userData != null && userData['token'] != null) {
      try {
        // Fetch fresh data from NestJS (Using 10.0.2.2 for Android Emulator)
        final response = await http.get(
          Uri.parse('http://10.0.2.2:3000/auth/me'),
          headers: {'Authorization': 'Bearer ${userData['token']}'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _fullProfileData = data['user'];
            _name = _fullProfileData['name'];
            _email = _fullProfileData['email'];
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint("Error fetching live profile: $e");
      }
    }
    
    // Fallback if logged out or network fails
    setState(() {
      _name = userData?['name'];
      _email = userData?['email'];
      _isLoading = false;
    });
  }

  // --- LOGOUT LOGIC ---
  Future<void> _handleLogout() async {
    // 1. Clear the secure storage
    await AuthService.logout();
    
    // 2. Safely check if the widget is still on screen before navigating
    if (mounted) {
      // Show the success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logged out successfully.", style: GoogleFonts.poppins()), 
          backgroundColor: Colors.green
        ),
      );

      // 3. Redirect to LoginScreen and clear the entire navigation stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false, // This prevents them from hitting "Back" to return
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Soft grey background so the white cards pop!
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _name == null 
              ? _buildGuestView() 
              : _buildLoggedInView(),
      ),
    );
  }

  // ==========================================
  // VIEW 1: THE GUEST VIEW (NOT LOGGED IN)
  // ==========================================
  Widget _buildGuestView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.travel_explore, size: 80, color: Colors.blueAccent),
          ),
          const SizedBox(height: 32),
          Text("Ready to Explore?", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
          const SizedBox(height: 12),
          Text(
            "Sign in to save your progress, track your adventures, and unlock exclusive local historical facts.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 48),

          // --- BIG SIGN IN BUTTON ---
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((_) => _checkLoginStatus());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text("Sign In", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 2: THE LOGGED IN VIEW
  // ==========================================
  Widget _buildLoggedInView() {
    String initial = _name != null && _name!.isNotEmpty ? _name![0].toUpperCase() : "?";

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        children: [
          // --- TOP PROFILE CARD ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    initial, 
                    style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ),
                const SizedBox(height: 16),
                Text(_name ?? "Loading...", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(_email ?? "Loading...", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          ),
          
          const SizedBox(height: 32),

          // --- MENU OPTIONS ---
          _buildMenuCard(
            icon: Icons.bookmark_border, 
            title: "My Saved Places", 
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedTripsScreen(),
                ),
              );
            },
          ),
          _buildMenuCard(icon: Icons.map_outlined, title: "Trip History", onTap: () {}),
          
          // --- SETTINGS HUB ---
          _buildMenuCard(
            icon: Icons.settings_outlined, 
            title: "Settings", 
            onTap: () async {
              final didUpdate = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen(profileData: _fullProfileData)),
              );
              // Refresh profile if user edited data
              if (didUpdate == true) {
                setState(() => _isLoading = true);
                _checkLoginStatus();
              }
            }
          ),
          
          _buildMenuCard(icon: Icons.help_outline, title: "Help & Support", onTap: () {}),

          const SizedBox(height: 32),

          // --- OUTLINED LOGOUT BUTTON ---
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text("Log Out", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    content: Text("Are you sure you want to log out of Cavite Explorer?", style: GoogleFonts.poppins()),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey[600]))),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); 
                          _handleLogout(); 
                        }, 
                        child: Text("Log Out", style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold))
                      ),
                    ],
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: Colors.transparent,
              ),
              child: Text("Log Out", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.redAccent)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Helper Widget for the Menu Cards
  Widget _buildMenuCard({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: Icon(icon, color: Colors.black87),
          title: Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: onTap,
        ),
      ),
    );
  }
}
