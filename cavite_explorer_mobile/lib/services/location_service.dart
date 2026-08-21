import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  
  /// Checks if location is currently active (Both OS permission AND App Preference)
  static Future<bool> isLocationActive() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check our internal app switch (defaults to true)
    bool appWantsLocation = prefs.getBool('use_location') ?? true; 
    if (!appWantsLocation) return false;

    // Check actual OS permission
    LocationPermission permission = await Geolocator.checkPermission();
    return (permission == LocationPermission.always || permission == LocationPermission.whileInUse);
  }

  /// The method triggered by your Settings Switch
  static Future<bool> toggleLocation(bool enable) async {
    final prefs = await SharedPreferences.getInstance();

    if (enable) {
      // 1. User wants to turn it ON
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false; // GPS is physically off

      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.deniedForever) {
        // They permanently blocked us in the past. Send them to OS Settings!
        await Geolocator.openAppSettings();
        return false; // We return false because they have to change it outside the app
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        await prefs.setBool('use_location', true); // Save internal state
        return true;
      }
      
      return false; // Still denied

    } else {
      // 2. User wants to turn it OFF internally (Soft Off)
      await prefs.setBool('use_location', false);
      return false;
    }
  }

  /// The Smart Prompt for HomeScreen (Now respects the soft toggle!)
  static Future<Position?> promptLocationOnce() async {
    final prefs = await SharedPreferences.getInstance();

    // If user explicitly turned it off in settings, don't annoy them!
    if (prefs.getBool('use_location') == false) return null;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    final hasAsked = prefs.getBool('has_asked_location') ?? false;
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    }

    if (!hasAsked && permission == LocationPermission.denied) {
      await prefs.setBool('has_asked_location', true);
      permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        await prefs.setBool('use_location', true); // Sync internal state
        return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      }
    }

    return null; 
  }
}