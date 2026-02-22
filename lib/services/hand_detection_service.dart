// lib/services/hand_detection_service.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import '../domain/entities/palm_session.dart';

enum DetectionResult {
  handDetected,
  noHandDetected,
  dorsalSideDetected,
  wrongHand,
  lowConfidence,
}

class HandDetectionData {
  final DetectionResult result;
  final HandSide handSide;
  final bool isDorsalSide;
  final int fingersDetected;
  final List<String> fingerOrder; // ordered list of detected finger names
  final double confidence;
  final String message;

  const HandDetectionData({
    required this.result,
    required this.handSide,
    required this.isDorsalSide,
    required this.fingersDetected,
    required this.fingerOrder,
    required this.confidence,
    required this.message,
  });

  factory HandDetectionData.noHand() => const HandDetectionData(
        result: DetectionResult.noHandDetected,
        handSide: HandSide.unknown,
        isDorsalSide: false,
        fingersDetected: 0,
        fingerOrder: [],
        confidence: 0.0,
        message: 'No hand detected. Please place your palm in the frame.',
      );
}

class HandDetectionService {
  final Logger _logger = Logger();
  PoseDetector? _poseDetector;
  bool _isDisposed = false;

  HandDetectionService() {
    _initDetector();
  }

  void _initDetector() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );
  }

  /// Detect hand from an image file
  /// Uses pose detection landmarks for wrist/hand estimation + heuristic analysis
  Future<HandDetectionData> detectHand(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final poses = await _poseDetector?.processImage(inputImage) ?? [];

      if (poses.isEmpty) {
        // Fallback: image-based heuristic detection
        return await _heuristicHandDetection(imageFile);
      }

      // Use pose landmarks to determine hand presence and side
      final pose = poses.first;
      return _analyzePoseLandmarks(pose, imageFile);
    } catch (e) {
      _logger.e('Hand detection error: $e');
      return await _heuristicHandDetection(imageFile);
    }
  }

  HandDetectionData _analyzePoseLandmarks(Pose pose, File imageFile) {
    final landmarks = pose.landmarks;

    // Wrist landmarks
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];

    // Determine which hand is more visible
    bool leftHandVisible = (leftWrist?.likelihood ?? 0) > 0.5;
    bool rightHandVisible = (rightWrist?.likelihood ?? 0) > 0.5;

    HandSide side = HandSide.unknown;
    double confidence = 0.0;

    if (leftHandVisible && !rightHandVisible) {
      side = HandSide.left;
      confidence = leftWrist?.likelihood ?? 0;
    } else if (rightHandVisible && !leftHandVisible) {
      side = HandSide.right;
      confidence = rightWrist?.likelihood ?? 0;
    } else if (leftHandVisible && rightHandVisible) {
      // Both visible - pick dominant one
      final lConf = leftWrist?.likelihood ?? 0;
      final rConf = rightWrist?.likelihood ?? 0;
      side = lConf > rConf ? HandSide.left : HandSide.right;
      confidence = math.max(lConf, rConf);
    }

    if (side == HandSide.unknown || confidence < 0.3) {
      return HandDetectionData.noHand();
    }

    // Count extended fingers (rough estimation)
    final fingersUp = _estimateFingersUp(landmarks, side);

    return HandDetectionData(
      result: DetectionResult.handDetected,
      handSide: side,
      isDorsalSide: false, // Determined separately by image analysis
      fingersDetected: fingersUp,
      fingerOrder: _getFingerOrder(side),
      confidence: confidence,
      message: '${side.label.replaceAll('_', ' ')} detected',
    );
  }

  int _estimateFingersUp(
      Map<PoseLandmarkType, PoseLandmark> landmarks, HandSide side) {
    int count = 0;
    if (side == HandSide.left) {
      if ((landmarks[PoseLandmarkType.leftThumb]?.likelihood ?? 0) > 0.5)
        count++;
      if ((landmarks[PoseLandmarkType.leftIndex]?.likelihood ?? 0) > 0.5)
        count++;
      if ((landmarks[PoseLandmarkType.leftPinky]?.likelihood ?? 0) > 0.5)
        count++;
    } else {
      if ((landmarks[PoseLandmarkType.rightThumb]?.likelihood ?? 0) > 0.5)
        count++;
      if ((landmarks[PoseLandmarkType.rightIndex]?.likelihood ?? 0) > 0.5)
        count++;
      if ((landmarks[PoseLandmarkType.rightPinky]?.likelihood ?? 0) > 0.5)
        count++;
    }
    return math.min(count * 2, 5); // approximate scaling
  }

  List<String> _getFingerOrder(HandSide side) {
    return ['Thumb', 'Index', 'Middle', 'Ring', 'Little'];
  }

  /// Fallback: heuristic detection based on skin color and shape
  Future<HandDetectionData> _heuristicHandDetection(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return HandDetectionData.noHand();

      final resized = img.copyResize(image, width: 200, height: 200);
      int skinPixels = 0;
      final total = resized.width * resized.height;

      for (int y = 0; y < resized.height; y++) {
        for (int x = 0; x < resized.width; x++) {
          final pixel = resized.getPixel(x, y);
          if (_isSkinColor(pixel)) skinPixels++;
        }
      }

      final skinRatio = skinPixels / total;

      if (skinRatio < 0.15) return HandDetectionData.noHand();

      // Determine hand side by analyzing asymmetry
      final side = _estimateHandSideFromImage(resized);

      return HandDetectionData(
        result: DetectionResult.handDetected,
        handSide: side,
        isDorsalSide: false,
        fingersDetected: 5,
        fingerOrder: _getFingerOrder(side),
        confidence: skinRatio.clamp(0.0, 1.0),
        message: 'Hand detected',
      );
    } catch (e) {
      _logger.e('Heuristic detection error: $e');
      return HandDetectionData.noHand();
    }
  }

  bool _isSkinColor(img.Pixel pixel) {
    final r = pixel.r.toDouble();
    final g = pixel.g.toDouble();
    final b = pixel.b.toDouble();

    // YCrCb skin color model
    if (r == 0 && g == 0 && b == 0) return false;

    final y = 0.299 * r + 0.587 * g + 0.114 * b;
    final cr = (r - y) * 0.713 + 128;
    final cb = (b - y) * 0.564 + 128;

    return (y > 80) && (cr >= 133 && cr <= 173) && (cb >= 77 && cb <= 127);
  }

  HandSide _estimateHandSideFromImage(img.Image image) {
    // Simple heuristic: analyze pixel mass distribution
    // Thumb is typically on opposite side from pinky
    double leftMass = 0;
    double rightMass = 0;
    final midX = image.width / 2;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (_isSkinColor(image.getPixel(x, y))) {
          if (x < midX)
            leftMass++;
          else
            rightMass++;
        }
      }
    }

    // If more skin on left half of image, could be right hand's thumb side
    return leftMass > rightMass ? HandSide.right : HandSide.left;
  }

  Future<void> dispose() async {
    if (!_isDisposed) {
      _isDisposed = true;
      await _poseDetector?.close();
    }
  }
}
