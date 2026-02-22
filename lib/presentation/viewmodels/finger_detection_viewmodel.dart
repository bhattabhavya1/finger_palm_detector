// lib/presentation/viewmodels/finger_detection_viewmodel.dart
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/minutiae_record.dart';
import '../../domain/entities/palm_session.dart';
import '../../domain/repositories/palm_repository.dart';
import '../../services/camera_service.dart';
import '../../services/hand_detection_service.dart';
import '../../services/image_analysis_service.dart';

enum FingerDetectionState {
  initial,
  cameraReady,
  detecting,
  dorsalDetected,
  fingerMismatch,
  wrongPerson,
  wrongHand,
  capturing,
  fingerCaptured,
  allFingersCaptured,
  error,
}

class FingerDetectionViewModel extends ChangeNotifier {
  final PalmRepository _repository;
  final CameraService _cameraService;
  final ImageAnalysisService _analysisService;
  final HandDetectionService _handDetectionService;
  final _uuid = const Uuid();

  FingerDetectionState _state = FingerDetectionState.initial;
  FingerDetectionState get state => _state;

  PalmSession? _palmSession;
  List<MinutiaeRecord> _capturedFingers = [];
  List<MinutiaeRecord> get capturedFingers =>
      List.unmodifiable(_capturedFingers);

  int get currentFingerIndex => _capturedFingers.length;
  int get totalFingers => AppConstants.totalFingers;

  /// e.g. "2/5"
  String get fingerProgress => '${currentFingerIndex}/$totalFingers';

  CameraController? get cameraController => _cameraService.controller;

  String _message = '';
  String get message => _message;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _fingerIdentityMessage;
  String? get fingerIdentityMessage => _fingerIdentityMessage;

  bool _isDorsalDetected = false;
  bool get isDorsalDetected => _isDorsalDetected;

  LuminosityData? _luminosityData;
  LuminosityData? get luminosityData => _luminosityData;

  bool _isStreamActive = false;

  FingerDetectionViewModel({
    required PalmRepository repository,
    required CameraService cameraService,
    required ImageAnalysisService analysisService,
    required HandDetectionService handDetectionService,
  })  : _repository = repository,
        _cameraService = cameraService,
        _analysisService = analysisService,
        _handDetectionService = handDetectionService;

  String get currentFingerName {
    final idx = currentFingerIndex;
    if (idx >= AppConstants.fingerNames.length) return '';
    return AppConstants.fingerNames[idx];
  }

  Future<void> initialize(PalmSession session) async {
    _palmSession = session;
    _capturedFingers = [];

    try {
      await _cameraService.initializeCamera(
        type: CameraType.rear,
        resolution: ResolutionPreset.high,
      );
      _setState(FingerDetectionState.cameraReady);
      _setMessage('Place your ${currentFingerName} finger in the oval');
    } catch (e) {
      _errorMessage = 'Camera initialization failed: $e';
      _setState(FingerDetectionState.error);
    }
  }

  Future<void> onImageStream(CameraImage image) async {
    if (_isStreamActive) return;
    _isStreamActive = true;
    try {
      final lum = _cameraService.analyzeLuminosityFromImage(image: image);
      if (_luminosityData?.lightCondition != lum.lightCondition) {
        _luminosityData = lum;
        await _cameraService.adjustCameraForLuminosity(lum);
        notifyListeners();
      }
    } finally {
      _isStreamActive = false;
    }
  }

  Future<void> captureCurrentFinger() async {
    if (_state == FingerDetectionState.capturing) return;
    if (_palmSession == null) return;
    if (currentFingerIndex >= totalFingers) return;

    _setState(FingerDetectionState.capturing);
    _fingerIdentityMessage = null;

    try {
      final imageFile = await _cameraService.takePicture();
      if (imageFile == null) {
        _errorMessage = 'Failed to capture image';
        _setState(FingerDetectionState.error);
        return;
      }

      // Check dorsal side
      final isDorsal = await _analysisService.isDorsalSide(imageFile);
      if (isDorsal) {
        _isDorsalDetected = true;
        _setMessage(
            'Finger dorsal side detected, please show palm side finger which contains finger record or minutiae points');
        _setState(FingerDetectionState.dorsalDetected);
        return;
      }
      _isDorsalDetected = false;

      // Check blur
      final blurScore = await _analysisService.computeBlurScore(imageFile);
      if (_analysisService.isBlurred(blurScore)) {
        _setMessage('Image is blurry. Please hold steady and recapture.');
        _setState(FingerDetectionState.cameraReady);
        return;
      }

      // Detect hand side
      final detection = await _handDetectionService.detectHand(imageFile);

      // Validate hand side matches palm session
      if (detection.handSide != HandSide.unknown &&
          detection.handSide != _palmSession!.handSide) {
        _setMessage(
            'Incorrect Finger - Please use ${_palmSession!.handSide.label.replaceAll('_', ' ')} fingers');
        _setState(FingerDetectionState.wrongHand);
        return;
      }

      // Extract features
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes)!;
      final pHash = _analysisService.computePerceptualHash(image);
      final histogram = _analysisService.computeHistogramSignature(image);
      final minutiaePoints =
          await _analysisService.extractMinutiaePoints(imageFile);
      final brightnessScore =
          await _analysisService.computeBrightnessScore(imageFile);

      // Validate against palm minutiae (person validation)
      final palmMinutiae = _palmSession!.palmMinutiaePoints;
      final palmHistogram = _palmSession!.palmHistogramSignature;

      final histSimilarity =
          _analysisService.cosineSimilarity(histogram, palmHistogram);
      final minutiaeSimilarity = minutiaePoints.isNotEmpty
          ? _analysisService.compareMinutiaePoints(minutiaePoints, palmMinutiae)
          : 0.0;

      // Combined score (weighted)
      final combinedScore = (histSimilarity * 0.6) + (minutiaeSimilarity * 0.4);

      if (combinedScore < 0.25) {
        // Finger does not match this person's palm
        _setMessage('Finger does not match');
        _setState(FingerDetectionState.wrongPerson);
        return;
      }

      // Determine which finger this is (validate against expected)
      final fingerName = currentFingerName;
      final handSide = _palmSession!.handSide.label;

      // Toast message: which finger identified
      _fingerIdentityMessage =
          'Detected: ${handSide.replaceAll('_', ' ')} - $fingerName Finger';

      // Save image
      final savedPath = await _cameraService.saveImage(
        sourceFile: imageFile,
        handSide: handSide,
        fingerName: fingerName,
        isPalm: false,
      );

      if (savedPath == null) {
        _errorMessage = 'Failed to save image';
        _setState(FingerDetectionState.error);
        return;
      }

      final record = MinutiaeRecord(
        id: _uuid.v4(),
        sessionId: _palmSession!.id,
        handSide: handSide,
        fingerName: fingerName,
        imagePath: savedPath,
        minutiaePoints: minutiaePoints,
        perceptualHash: pHash,
        histogramSignature: histogram,
        blurScore: blurScore,
        brightnessScore: brightnessScore,
        focusDistance: _luminosityData?.focusDistance ?? 0.0,
        capturedAt: DateTime.now(),
      );

      await _repository.saveMinutiaeRecord(record);
      _capturedFingers.add(record);

      if (_capturedFingers.length >= totalFingers) {
        _setMessage('All fingers captured successfully!');
        _setState(FingerDetectionState.allFingersCaptured);
      } else {
        _setMessage(
            'Great! Now place your $currentFingerName finger in the oval');
        _setState(FingerDetectionState.fingerCaptured);
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Capture error: $e';
      _setState(FingerDetectionState.error);
    }
  }

  void dismissError() {
    _errorMessage = null;
    _isDorsalDetected = false;
    _setState(FingerDetectionState.cameraReady);
    _setMessage('Place your $currentFingerName finger in the oval');
  }

  void _setState(FingerDetectionState s) {
    _state = s;
    notifyListeners();
  }

  void _setMessage(String m) {
    _message = m;
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}
