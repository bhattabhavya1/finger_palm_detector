// lib/presentation/viewmodels/palm_detection_viewmodel.dart
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/luminosity_record.dart';
import '../../domain/entities/palm_session.dart';
import '../../domain/repositories/palm_repository.dart';
import '../../services/camera_service.dart';
import '../../services/hand_detection_service.dart';
import '../../services/image_analysis_service.dart';
import '../../services/permission_service.dart';

enum PalmDetectionState {
  initial,
  requestingPermissions,
  permissionDenied,
  cameraReady,
  detecting,
  palmDetected,
  dorsalDetected,
  capturing,
  captured,
  error,
}

class PalmDetectionViewModel extends ChangeNotifier {
  final PalmRepository _repository;
  final CameraService _cameraService;
  final ImageAnalysisService _analysisService;
  final HandDetectionService _handDetectionService;
  final PermissionService _permissionService;
  final _uuid = const Uuid();

  PalmDetectionState _state = PalmDetectionState.initial;
  PalmDetectionState get state => _state;

  CameraController? get cameraController => _cameraService.controller;

  HandDetectionData? _lastDetection;
  HandDetectionData? get lastDetection => _lastDetection;

  LuminosityData? _luminosityData;
  LuminosityData? get luminosityData => _luminosityData;

  PalmSession? _capturedSession;
  PalmSession? get capturedSession => _capturedSession;

  String _message = '';
  String get message => _message;

  bool _isDorsalDetected = false;
  bool get isDorsalDetected => _isDorsalDetected;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isStreamActive = false;

  PalmDetectionViewModel({
    required PalmRepository repository,
    required CameraService cameraService,
    required ImageAnalysisService analysisService,
    required HandDetectionService handDetectionService,
    required PermissionService permissionService,
  })  : _repository = repository,
        _cameraService = cameraService,
        _analysisService = analysisService,
        _handDetectionService = handDetectionService,
        _permissionService = permissionService;

  Future<void> initialize() async {
    _setState(PalmDetectionState.requestingPermissions);

    final allGranted = await _permissionService.areAllGranted();
    if (!allGranted) {
      final status = await _permissionService.requestAll();
      if (status != PermissionStatus.granted) {
        _setState(PalmDetectionState.permissionDenied);
        return;
      }
    }

    try {
      await _cameraService.initializeCamera(
        type: CameraType.rear,
        resolution: ResolutionPreset.high,
      );
      _setState(PalmDetectionState.cameraReady);
      _setMessage('Show your palm in the frame');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Camera initialization failed: $e';
      _setState(PalmDetectionState.error);
    }
  }

  /// Called every frame from the camera stream
  Future<void> onImageStream(CameraImage image) async {
    if (_isStreamActive) return;
    if (_state != PalmDetectionState.cameraReady &&
        _state != PalmDetectionState.detecting) return;

    _isStreamActive = true;

    try {
      // Analyze luminosity
      final lum = _cameraService.analyzeLuminosityFromImage(image: image);
      if (_luminosityData?.lightCondition != lum.lightCondition) {
        _luminosityData = lum;
        await _cameraService.adjustCameraForLuminosity(lum);
        notifyListeners();
      }
    } catch (_) {
      // Ignore stream errors
    } finally {
      _isStreamActive = false;
    }
  }

  Future<void> captureAndDetect() async {
    if (_state == PalmDetectionState.capturing) return;
    _setState(PalmDetectionState.capturing);

    try {
      final imageFile = await _cameraService.takePicture();
      if (imageFile == null) {
        _errorMessage = 'Failed to capture image';
        _setState(PalmDetectionState.error);
        return;
      }

      // Check for dorsal side
      final isDorsal = await _analysisService.isDorsalSide(imageFile);
      if (isDorsal) {
        _isDorsalDetected = true;
        _setMessage(
            'Palm dorsal side detected, minutiae points won\'t be extracted.');
        _setState(PalmDetectionState.dorsalDetected);
        return;
      }
      _isDorsalDetected = false;

      // Detect hand
      final detection = await _handDetectionService.detectHand(imageFile);
      _lastDetection = detection;

      if (detection.result == DetectionResult.noHandDetected) {
        _setMessage('No hand detected. Please show your palm clearly.');
        _setState(PalmDetectionState.cameraReady);
        return;
      }

      // Analyze image quality
      final blurScore = await _analysisService.computeBlurScore(imageFile);
      final brightnessScore =
          await _analysisService.computeBrightnessScore(imageFile);

      if (_analysisService.isBlurred(blurScore)) {
        _setMessage('Image is blurry. Please hold steady and recapture.');
        _setState(PalmDetectionState.cameraReady);
        return;
      }

      // Extract features
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes)!;
      final pHash = _analysisService.computePerceptualHash(image);
      final histogram = _analysisService.computeHistogramSignature(image);
      final minutiaePoints =
          await _analysisService.extractMinutiaePoints(imageFile);

      // Save image to storage
      final savedPath = await _cameraService.saveImage(
        sourceFile: imageFile,
        handSide: detection.handSide.label,
        isPalm: true,
      );

      if (savedPath == null) {
        _errorMessage = 'Failed to save image';
        _setState(PalmDetectionState.error);
        return;
      }

      // Create session
      final deviceId = await _cameraService.getDeviceId();
      final session = PalmSession(
        id: _uuid.v4(),
        deviceId: deviceId,
        handSide: detection.handSide,
        palmImagePath: savedPath,
        palmMinutiaePoints: minutiaePoints,
        palmPerceptualHash: pHash,
        palmHistogramSignature: histogram,
        blurScore: blurScore,
        brightnessScore: brightnessScore,
        focusDistance: _luminosityData?.focusDistance ?? 0.0,
        capturedAt: DateTime.now(),
        isDorsalSide: false,
      );

      await _repository.saveSession(session);

      // Save luminosity record
      if (_luminosityData != null) {
        final lum = _luminosityData!;
        await _repository.saveLuminosityRecord(LuminosityRecord(
          id: _uuid.v4(),
          deviceId: deviceId,
          brightnessScore: lum.brightnessScore,
          lightCondition: lum.lightCondition,
          cameraType: lum.cameraType == CameraType.rear ? 'rear' : 'front',
          focalLength: lum.focalLength,
          apertureScore: lum.apertureScore,
          focusDistance: lum.focusDistance,
          blurScore: blurScore,
          recordedAt: DateTime.now(),
        ));
      }

      _capturedSession = session;
      _setMessage(
          '${detection.handSide.label.replaceAll('_', ' ')} captured successfully!');
      _setState(PalmDetectionState.captured);
    } catch (e) {
      _errorMessage = 'Detection error: $e';
      _setState(PalmDetectionState.error);
    }
  }

  void resetToCapture() {
    _isDorsalDetected = false;
    _errorMessage = null;
    _setState(PalmDetectionState.cameraReady);
    _setMessage('Show your palm in the frame');
  }

  void _setState(PalmDetectionState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setMessage(String msg) {
    _message = msg;
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}
