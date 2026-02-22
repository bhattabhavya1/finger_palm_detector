// lib/presentation/screens/palm_detection/palm_detection_screen.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/di/injection.dart';
import '../../../domain/entities/palm_session.dart';
import '../../../services/hand_detection_service.dart';
import '../../viewmodels/palm_detection_viewmodel.dart';
import '../../widgets/camera_overlays.dart';
import '../../widgets/capture_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/luminosity_indicator.dart';
import '../../../services/permission_service.dart';

class PalmDetectionScreen extends StatelessWidget {
  const PalmDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PalmDetectionViewModel>(
      create: (_) => getIt<PalmDetectionViewModel>()..initialize(),
      child: const _PalmDetectionBody(),
    );
  }
}

class _PalmDetectionBody extends StatefulWidget {
  const _PalmDetectionBody();

  @override
  State<_PalmDetectionBody> createState() => _PalmDetectionBodyState();
}

class _PalmDetectionBodyState extends State<_PalmDetectionBody> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PalmDetectionViewModel>();

    // Navigate to finger detection after palm captured
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vm.state == PalmDetectionState.captured &&
          vm.capturedSession != null) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.fingerDetection,
          arguments: vm.capturedSession,
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            _buildCameraPreview(vm),

            // Palm overlay
            if (vm.state != PalmDetectionState.initial &&
                vm.state != PalmDetectionState.requestingPermissions &&
                vm.state != PalmDetectionState.permissionDenied &&
                vm.state != PalmDetectionState.error)
              PalmOverlay(
                isActive: vm.state == PalmDetectionState.palmDetected,
                isError: vm.state == PalmDetectionState.dorsalDetected,
              ),

            // Top bar
            _buildTopBar(context, vm),

            // Bottom controls
            _buildBottomControls(vm),

            // Dorsal / error banner at bottom
            if (vm.isDorsalDetected ||
                vm.state == PalmDetectionState.dorsalDetected)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ErrorBanner(
                  message:
                      'Palm dorsal side detected, minutiae points won\'t be extracted.',
                  onDismiss: vm.resetToCapture,
                ),
              ),

            // Camera error
            if (vm.state == PalmDetectionState.error) _buildErrorOverlay(vm),

            // Permission denied
            if (vm.state == PalmDetectionState.permissionDenied)
              _buildPermissionOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(PalmDetectionViewModel vm) {
    final controller = vm.cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1,
          height: controller.value.previewSize?.width ?? 1,
          child: CameraPreview(
            controller,
            child: Container(), // needed for stream callback
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, PalmDetectionViewModel vm) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Text(
                'Palm Detection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            LuminosityIndicator(data: vm.luminosityData),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(PalmDetectionViewModel vm) {
    return Positioned(
      bottom: vm.isDorsalDetected ? 60 : 20,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Instruction text
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              vm.message.isEmpty ? 'Show your palm in the frame' : vm.message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          // Hand side indicator
          if (vm.lastDetection != null &&
              vm.lastDetection!.result == DetectionResult.handDetected)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.successGreen),
              ),
              child: Text(
                vm.lastDetection!.handSide.label.replaceAll('_', ' '),
                style: const TextStyle(
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),

          // Capture button
          CaptureButton(
            isCapturing: vm.state == PalmDetectionState.capturing,
            onPressed: vm.state == PalmDetectionState.capturing
                ? null
                : vm.captureAndDetect,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap to capture palm',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay(PalmDetectionViewModel vm) {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.errorRed, size: 64),
            const SizedBox(height: 16),
            Text(
              vm.errorMessage ?? 'An error occurred',
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: vm.resetToCapture,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography,
                color: AppColors.errorRed, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Camera and storage permissions are required to proceed.',
              style: TextStyle(color: Colors.white, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await getIt<PermissionService>().openSettings();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
