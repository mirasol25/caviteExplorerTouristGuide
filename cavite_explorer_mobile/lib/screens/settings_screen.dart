import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/password_security_screen.dart';
import '../services/location_service.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const SettingsScreen({super.key, required this.profileData});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLocationOn = false;

  @override
  void initState() {
    super.initState();
    _loadLocationStatus();
  }

  // Find out the current status when the screen opens
  Future<void> _loadLocationStatus() async {
    bool active = await LocationService.isLocationActive();
    if (mounted) {
      setState(() {
        _isLocationOn = active;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Settings", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Text(
            "Account", 
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 1.2)
          ),
          const SizedBox(height: 16),
          
          // --- PERSONAL DETAILS ---
          _buildSettingsTile(
            context,
            icon: Icons.person_outline,
            title: "Personal Details",
            subtitle: "Update your name, mobile, birthday, and sex",
            onTap: () async {
              final didUpdate = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditProfileScreen(currentData: widget.profileData)),
              );
              if (didUpdate == true && mounted) Navigator.pop(context, true); 
            },
          ),
          const SizedBox(height: 16),

          // --- PASSWORD & SECURITY ---
          _buildSettingsTile(
            context,
            icon: Icons.lock_outline,
            title: "Password & Security",
            subtitle: "Update your password to keep your account safe",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PasswordSecurityScreen(email: widget.profileData['email'] ?? '')),
              );
            },
          ),

          const SizedBox(height: 32),
          Text(
            "App Preferences", 
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 1.2)
          ),
          const SizedBox(height: 16),

          // --- THE NEW LOCATION TOGGLE ---
          _buildSwitchTile(
            icon: Icons.location_on_outlined,
            title: "Location Access",
            subtitle: "Use my location to find nearby historical sites",
            value: _isLocationOn,
            onChanged: (newValue) async {
              // 1. Optimistically change the UI instantly
              setState(() => _isLocationOn = newValue);
              
              // 2. Do the heavy lifting in the background
              bool result = await LocationService.toggleLocation(newValue);
              
              // 3. If they tried to turn it on, but OS denied it (or opened settings), revert/update UI
              if (newValue == true && result == false) {
                setState(() => _isLocationOn = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Please allow location access in your device settings.", style: GoogleFonts.poppins()),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            }
          ),
        ],
      ),
    );
  }

  // Existing helper widget
  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      decoration: _cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: _iconBox(icon),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87)),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }

  // New helper widget for the Toggle Switch
  Widget _buildSwitchTile({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      decoration: _cardDecoration(),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        secondary: _iconBox(icon),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87)),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
        activeColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  // Shared visual styles
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade100, width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 5, offset: const Offset(0, 2))],
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.blueAccent),
    );
  }
}