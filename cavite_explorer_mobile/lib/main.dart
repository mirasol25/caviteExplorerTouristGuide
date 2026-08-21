import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter framework error: ${details.exceptionAsString()}');
  };
  debugPrint('Cavite Explorer: Flutter application starting');
  runApp(const CaviteExplorerApp());
}

class CaviteExplorerApp extends StatelessWidget {
  const CaviteExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cavite Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F8F4),
      ),
      // We use initialRoute instead of the 'home:' property
      initialRoute: '/',
      routes: {
        '/': (context) => const _AppStartupScreen(),
        '/login': (context) => const LoginScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

/// Draws a native Flutter surface before HomeScreen begins location and API work.
/// This prevents a blank window while startup services initialize.
class _AppStartupScreen extends StatefulWidget {
  const _AppStartupScreen();

  @override
  State<_AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<_AppStartupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('Cavite Explorer: first Flutter frame rendered');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
