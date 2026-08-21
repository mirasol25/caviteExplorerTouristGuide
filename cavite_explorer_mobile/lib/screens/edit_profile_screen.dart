import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- Needed for input formatters
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  
  const EditProfileScreen({super.key, required this.currentData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // 1. Add a GlobalKey to control our Form validation
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _birthdayController;
  
  String? _selectedSex;
  bool _isLoading = false;

  final List<String> _sexOptions = ['Male', 'Female', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentData['name'] ?? '');
    _mobileController = TextEditingController(text: widget.currentData['mobile'] ?? '');
    _birthdayController = TextEditingController(text: widget.currentData['birthday'] ?? '');
    
    if (widget.currentData['sex'] != null && widget.currentData['sex'].isNotEmpty) {
      _selectedSex = widget.currentData['sex'];
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)), 
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blueAccent),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _handleSave() async {
    // 2. ONLY proceed if all validators pass!
    if (!_formKey.currentState!.validate()) {
      return; 
    }

    setState(() => _isLoading = true);

    try {
      final userData = await AuthService.getUser();
      final token = userData?['token'];

      if (token == null) return;

      final response = await http.post(
        Uri.parse('http://10.0.2.2:3000/auth/update-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'mobile': _mobileController.text.trim(),
          'birthday': _birthdayController.text.trim(),
          'sex': _selectedSex ?? '',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await AuthService.saveUser(_nameController.text.trim(), widget.currentData['email'], token);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Profile updated!", style: GoogleFonts.poppins()), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true); 
        }
      } else {
        _showErrorSnackBar("Failed to update profile.");
      }
    } catch (e) {
      _showErrorSnackBar("Network error.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: GoogleFonts.poppins()), backgroundColor: Colors.redAccent));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _birthdayController.dispose();
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Edit Profile", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        // 3. Wrap everything in a Form widget
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                controller: _nameController, 
                label: "Full Name", 
                icon: Icons.person_outline,
                validator: (value) => value == null || value.isEmpty ? "Name cannot be empty" : null,
              ),
              const SizedBox(height: 20),
              
              // --- UPGRADED MOBILE FIELD ---
              _buildTextField(
                controller: _mobileController, 
                label: "Mobile Number", 
                icon: Icons.phone_outlined, 
                keyboardType: TextInputType.phone,
                // Restrict input to digits only, max 11 characters
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                // The PH Regex Validation!
                validator: (value) {
                  // It's optional, so if it's empty, we let it pass. 
                  // If you want it to be required, change this logic.
                  if (value != null && value.isNotEmpty) {
                    final RegExp phPhoneRegex = RegExp(r'^09\d{9}$');
                    if (!phPhoneRegex.hasMatch(value)) {
                      return "Enter a valid PH number (e.g., 09123456789)";
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Birthday
              TextFormField(
                controller: _birthdayController,
                readOnly: true,
                onTap: () => _selectDate(context),
                style: GoogleFonts.poppins(),
                decoration: _inputDecoration("Birthday", Icons.cake_outlined),
              ),
              const SizedBox(height: 20),

              // Sex Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSex,
                items: _sexOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: GoogleFonts.poppins()),
                  );
                }).toList(),
                onChanged: (newValue) => setState(() => _selectedSex = newValue),
                decoration: _inputDecoration("Sex", Icons.wc_outlined),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              ),
              
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Save Changes", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. Upgraded this to a TextFormField to support validators and formatters
  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.poppins(),
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey[500]),
      prefixIcon: Icon(icon, color: Colors.grey[400]),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}