// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import '../constants/app_routes.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/palm_detection/palm_detection_screen.dart';
import '../../presentation/screens/finger_detection/finger_detection_screen.dart';
import '../../presentation/screens/result/result_screen.dart';
import '../../presentation/screens/permission_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _fadeRoute(const SplashScreen(), settings);
      case AppRoutes.home:
        return _fadeRoute(const HomeScreen(), settings);
      case AppRoutes.palmDetection:
        return _slideRoute(const PalmDetectionScreen(), settings);
      case AppRoutes.fingerDetection:
        return _slideRoute(const FingerDetectionScreen(), settings);
      case AppRoutes.result:
        return _slideRoute(const ResultScreen(), settings);
      case AppRoutes.permissions:
        return _fadeRoute(const PermissionScreen(), settings);
      default:
        return _fadeRoute(const HomeScreen(), settings);
    }
  }

  static PageRouteBuilder _fadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  static PageRouteBuilder _slideRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final tween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
