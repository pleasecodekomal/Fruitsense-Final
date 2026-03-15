import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/results_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/history_screen.dart';

void main() {
  runApp(const FruitSenseApp());
}

class FruitSenseApp extends StatelessWidget {
  const FruitSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FruitSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),

      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/history': (context) => const HistoryScreen(),
        '/results': (context) => const ResultsScreen(),
        '/upload': (context) => const UploadScreen(),
      },
    );
  }
}
