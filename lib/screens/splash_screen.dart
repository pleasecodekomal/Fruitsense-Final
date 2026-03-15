import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Navigate to Dashboard after 3 seconds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const DashboardScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F6), // soft green background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedTextKit(
              animatedTexts: [
                ColorizeAnimatedText(
                  'FruitSense',
                  textStyle: const TextStyle(
                    fontSize: 46.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                  // Green base with orange shimmer
                  colors: [
                    Color(0xFF2E7D32), // deep green
                    Color(0xFFFF9800), // orange shimmer
                    Color(0xFF43A047), // medium green
                    Color(0xFFFFB74D), // light orange
                  ],
                  speed: const Duration(milliseconds: 500), // shimmer speed
                ),
              ],
              isRepeatingAnimation: true,
              totalRepeatCount: 3,
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              color: Color(0xFF43A047), // green spinner
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
