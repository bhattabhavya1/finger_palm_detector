// lib/presentation/screens/permission_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/permission_service.dart';
import '../../core/di/injection.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography_outlined,
                  size: 80, color: AppColors.errorRed),
              const SizedBox(height: 24),
              Text('Permissions Required',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                'This app requires camera and storage permissions to function. '
                'Please grant the required permissions to continue.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () async {
                  await getIt<PermissionService>().openSettings();
                },
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open Settings'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
