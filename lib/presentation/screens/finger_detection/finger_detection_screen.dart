// lib/presentation/screens/finger_detection/finger_detection_screen.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/di/injection.dart';
import '../../../domain/entities/palm_session.dart';
import '../../viewmodels/finger_detection_viewmodel.dart';
import '../../widgets/camera_overlays.dart';
import '../../widgets/capture_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/luminosity_indicator.dart';

class FingerDetectionScreen extends StatelessWidget {
  const FingerDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = ModalRoute.of(context)?.settings.arguments as PalmSession?;
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('Session not found', style: TextStyle(color: Colors.white))),
        backgroundColor: Colors.black,
      );
    }

    return ChangeNotifierProvider<FingerDetectionViewModel>(
      create: (_) => getIt<FingerDetectionViewModel>()..initialize(session),
      child: const _FingerDetectionBody(),
    );
  }
}

class _FingerDetectionBody extends StatefulWidget {
  const _FingerDetectionBody();

  @override
  State<_FingerDetectionBody> createState() => _FingerDetectionBodyState();
}

class _FingerDetectionBodyState extends State<_FingerDetectionBody> {
  String? _lastToastMessage;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FingerDetectionViewModel>();

    // Show toast for finger identity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vm.fingerIdentityMessage != null &&
          vm.fingerIdentityMessage != _lastToastMessage) {
        _lastToastMessage = vm.fingerIdentityMessage;
        _showToast(context, vm.fingerIdentityMessage!);
      }

      if (vm.state == FingerDetectionState.allFingersCaptured) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.result,
          arguments: vm.capturedFingers.isNotEmpty
              ? vm.capturedFingers.first.sessionId
              : null,
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

            // Finger oval overlay
            if (_isCameraReady(vm))
              FingerOvalOverlay(
                isActive: vm.state == FingerDetectionState.fingerCaptured,
                isError: vm.state == FingerDetectionState.dorsalDetected ||
                    vm.state == FingerDetectionState.fingerMismatch ||
                    vm.state == FingerDetectionState.wrongPerson ||
                    vm.state == FingerDetectionState.wrongHand,
              ),

            // Top bar
            _buildTopBar(context, vm),

            // Bottom controls
            _buildBottomControls(vm),

            // Error banners
            if (vm.isDorsalDetected)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ErrorBanner(
                  message: 'Finger dorsal side detected, please show palm side finger which contains finger record or minutiae points',
                  onDismiss: vm.dismissError,
                ),
              ),

            if (vm.state == FingerDetectionState.wrongPerson)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ErrorBanner(
                  message: 'Finger does not match',
                  backgroundColor: AppColors.errorRed.withOpacity(0.9),
                  onDismiss: vm.dismissError,
                ),
              ),

            if (vm.state == FingerDetectionState.wrongHand)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ErrorBanner(
                  message: 'Incorrect Finger - Please use the correct hand',
                  backgroundColor: AppColors.errorRed.withOpacity(0.9),
                  onDismiss: vm.dismissError,
                ),
              ),

            // Loading
            if (vm.state == FingerDetectionState.initial)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              ),
          ],
        ),
      ),
    );
  }

  bool _isCameraReady(FingerDetectionViewModel vm) {
    return vm.state != FingerDetectionState.initial &&
        vm.state != FingerDetectionState.error &&
        vm.cameraController?.value.isInitialized == true;
  }

  Widget _buildCameraPreview(FingerDetectionViewModel vm) {
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
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, FingerDetectionViewModel vm) {
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
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Finger Detection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (vm.state != FingerDetectionState.initial)
                    Text(
                      vm.currentFingerName.isNotEmpty
                          ? 'Current: ${vm.currentFingerName} Finger'
                          : '',
                      style: const TextStyle(color: AppColors.accent, fontSize: 12),
                    ),
                ],
              ),
            ),
            // Finger progress indicator
            _buildProgressChip(vm),
            const SizedBox(width: 8),
            LuminosityIndicator(data: vm.luminosityData),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressChip(FingerDetectionViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.5)),
      ),
      child: Text(
        vm.fingerProgress,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildBottomControls(FingerDetectionViewModel vm) {
    final isCapturing = vm.state == FingerDetectionState.capturing;
    final isError = vm.state == FingerDetectionState.wrongPerson ||
        vm.state == FingerDetectionState.wrongHand ||
        vm.state == FingerDetectionState.dorsalDetected;

    return Positioned(
      bottom: isError ? 64 : 20,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Finger progress dots
          _buildFingerDots(vm),
          const SizedBox(height: 16),

          // Instruction
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              vm.message.isEmpty ? 'Place finger in the oval' : vm.message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          // Capture button
          CaptureButton(
            isCapturing: isCapturing,
            onPressed: isCapturing ? null : vm.captureCurrentFinger,
          ),
          const SizedBox(height: 8),
          Text(
            vm.currentFingerIndex < vm.totalFingers
                ? 'Scan ${vm.currentFingerName} Finger'
                : 'Complete',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFingerDots(FingerDetectionViewModel vm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(vm.totalFingers, (i) {
        final captured = i < vm.currentFingerIndex;
        final current = i == vm.currentFingerIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: captured
                ? AppColors.successGreen
                : current
                    ? AppColors.accent
                    : Colors.white24,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: AppColors.successGreen.withOpacity(0.9),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
