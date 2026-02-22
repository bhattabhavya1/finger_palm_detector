// lib/services/camera_service.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../core/constants/app_constants.dart';
import '../domain/entities/luminosity_record.dart';

enum CameraType { rear, front }

class LuminosityData {
  final double brightnessScore;
  final LightCondition lightCondition;
  final double exposureOffset;
  final CameraType cameraType;
  // Camera sensor metadata
  final double focalLength;
  final double apertureScore;
  final double focusDistance;

  const LuminosityData({
    required this.brightnessScore,
    required this.lightCondition,
    required this.exposureOffset,
    required this.cameraType,
    required this.focalLength,
    required this.apertureScore,
    required this.focusDistance,
  });
}

class CameraService {
  final Logger _logger = Logger();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  CameraController? _controller;
  List<CameraDescription>? _cameras;
  CameraDescription? _selectedCamera;

  CameraService();

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Initialize cameras
  Future<List<CameraDescription>> getAvailableCameras() async {
    _cameras = await availableCameras();
    return _cameras ?? [];
  }

  /// Initialize a specific camera
  Future<void> initializeCamera({
    CameraType type = CameraType.rear,
    ResolutionPreset resolution = ResolutionPreset.high,
  }) async {
    final cameras = await getAvailableCameras();
    if (cameras.isEmpty) throw Exception('No cameras available');

    _selectedCamera = cameras.firstWhere(
      (c) =>
          c.lensDirection ==
          (type == CameraType.rear
              ? CameraLensDirection.back
              : CameraLensDirection.front),
      orElse: () => cameras.first,
    );

    await _disposeController();

    _controller = CameraController(
      _selectedCamera!,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();

    // Enable auto-focus
    await _controller!.setFocusMode(FocusMode.auto);
    await _controller!.setExposureMode(ExposureMode.auto);
    await _controller!.setFlashMode(FlashMode.off);
  }

  /// Analyze luminosity from a camera image stream frame
  LuminosityData analyzeLuminosityFromImage({
    required CameraImage image,
    CameraType cameraType = CameraType.rear,
  }) {
    // Calculate average Y (brightness) from YUV420 format
    double avgBrightness = 0;
    final yPlane = image.planes[0];
    final bytes = yPlane.bytes;
    int total = 0;

    for (int i = 0; i < bytes.length; i += 4) {
      avgBrightness += bytes[i];
      total++;
    }
    if (total > 0) avgBrightness /= total;

    final condition = _getLightCondition(avgBrightness);
    final exposureOffset = _calculateExposureOffset(avgBrightness);

    return LuminosityData(
      brightnessScore: avgBrightness,
      lightCondition: condition,
      exposureOffset: exposureOffset,
      cameraType: cameraType,
      focalLength: _selectedCamera?.sensorOrientation.toDouble() ?? 0.0,
      apertureScore: 1.8, // Typical smartphone aperture f/1.8
      focusDistance: 0.0, // Will be updated post-capture
    );
  }

  /// Apply brightness correction to camera
  Future<void> adjustCameraForLuminosity(LuminosityData data) async {
    if (_controller == null || !isInitialized) return;
    try {
      final minExposure = await _controller!.getMinExposureOffset();
      final maxExposure = await _controller!.getMaxExposureOffset();
      final clampedOffset = data.exposureOffset.clamp(minExposure, maxExposure);
      await _controller!.setExposureOffset(clampedOffset);
      _logger.d(
          'Exposure adjusted to $clampedOffset for brightness ${data.brightnessScore}');
    } catch (e) {
      _logger.w('Could not adjust exposure: $e');
    }
  }

  LightCondition _getLightCondition(double brightness) {
    if (brightness < AppConstants.lowLightThreshold) return LightCondition.low;
    if (brightness > AppConstants.brightLightThreshold)
      return LightCondition.bright;
    return LightCondition.normal;
  }

  double _calculateExposureOffset(double brightness) {
    if (brightness < AppConstants.lowLightThreshold) {
      // Increase exposure for dark scenes
      return ((AppConstants.lowLightThreshold - brightness) /
              AppConstants.lowLightThreshold) *
          2.0;
    } else if (brightness > AppConstants.brightLightThreshold) {
      // Decrease exposure for bright scenes
      return -((brightness - AppConstants.brightLightThreshold) /
              (255.0 - AppConstants.brightLightThreshold)) *
          2.0;
    }
    return 0.0;
  }

  /// Take a picture and save to a temp path
  Future<File?> takePicture() async {
    if (_controller == null || !isInitialized) return null;
    if (_controller!.value.isTakingPicture) return null;

    try {
      await _controller!.setFocusMode(FocusMode.auto);
      await Future.delayed(const Duration(milliseconds: 300));
      final xFile = await _controller!.takePicture();
      return File(xFile.path);
    } catch (e) {
      _logger.e('Take picture error: $e');
      return null;
    }
  }

  /// Save image to "Finger Data" folder with proper naming
  Future<String?> saveImage({
    required File sourceFile,
    required String handSide,
    String? fingerName,
    bool isPalm = false,
  }) async {
    try {
      final dir = await _getFingerDataDir();
      final timestamp = _getTimestamp();
      String fileName;

      if (isPalm) {
        final ext = handSide.contains('Left') ? 'png' : 'jpg';
        fileName = '${handSide}_$timestamp.$ext';
      } else {
        fileName = '${handSide}_${fingerName}_Finger_$timestamp.jpg';
      }

      final destPath = path.join(dir.path, fileName);
      await sourceFile.copy(destPath);
      return destPath;
    } catch (e) {
      _logger.e('Save image error: $e');
      return null;
    }
  }

  Future<Directory> _getFingerDataDir() async {
    Directory base;
    if (Platform.isAndroid) {
      // Use app-scoped external storage on Android (works with scoped storage).
      final external = await getExternalStorageDirectory();
      if (external != null) {
        base =
            Directory(path.join(external.path, AppConstants.fingerDataFolder));
      } else {
        final docs = await getApplicationDocumentsDirectory();
        base = Directory(path.join(docs.path, AppConstants.fingerDataFolder));
      }
    } else {
      final docs = await getApplicationDocumentsDirectory();
      base = Directory(path.join(docs.path, AppConstants.fingerDataFolder));
    }
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    return base;
  }

  String _getTimestamp() {
    final now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}'
        '_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<String> getDeviceId() async {
    try {
      final info = await _deviceInfo.androidInfo;
      return info.id;
    } catch (e) {
      return 'unknown_device';
    }
  }

  Future<void> _disposeController() async {
    final c = _controller;
    if (c != null) {
      await c.dispose();
      _controller = null;
    }
  }

  Future<void> dispose() async {
    await _disposeController();
  }

  CameraType get currentCameraType {
    if (_selectedCamera == null) return CameraType.rear;
    return _selectedCamera!.lensDirection == CameraLensDirection.back
        ? CameraType.rear
        : CameraType.front;
  }

  /// Get camera metadata for luminosity record
  Map<String, dynamic> getCameraMetadata() {
    return {
      'focal_length': _selectedCamera?.sensorOrientation.toDouble() ?? 26.0,
      'aperture_score': 1.8,
      'camera_type': currentCameraType == CameraType.rear ? 'rear' : 'front',
    };
  }
}
