// lib/domain/entities/palm_session.dart
import 'package:equatable/equatable.dart';

/// Represents which hand side is detected
enum HandSide {
  left,
  right,
  unknown,
}

/// Extension to add label and parsing support to HandSide
extension HandSideExtension on HandSide {
  String get label {
    switch (this) {
      case HandSide.left:
        return 'Left_Hand';
      case HandSide.right:
        return 'Right_Hand';
      case HandSide.unknown:
        return 'Unknown';
    }
  }

  static HandSide fromLabel(String label) {
    switch (label) {
      case 'Left_Hand':
        return HandSide.left;
      case 'Right_Hand':
        return HandSide.right;
      default:
        return HandSide.unknown;
    }
  }
}

/// Represents a palm capture session with all extracted features
class PalmSession extends Equatable {
  final String id;
  final String deviceId;
  final HandSide handSide;
  final String palmImagePath;

  /// Flattened list of minutiae points extracted from the palm image
  final List<double> palmMinutiaePoints;

  /// Perceptual hash for quick similarity comparison
  final String palmPerceptualHash;

  /// Histogram signature (128-dim) for robust matching
  final List<double> palmHistogramSignature;

  final double blurScore;
  final double brightnessScore;
  final double focusDistance;
  final DateTime capturedAt;
  final bool isDorsalSide;

  const PalmSession({
    required this.id,
    required this.deviceId,
    required this.handSide,
    required this.palmImagePath,
    required this.palmMinutiaePoints,
    required this.palmPerceptualHash,
    required this.palmHistogramSignature,
    required this.blurScore,
    required this.brightnessScore,
    required this.focusDistance,
    required this.capturedAt,
    this.isDorsalSide = false,
  });

  @override
  List<Object?> get props => [id, deviceId, handSide, palmImagePath];

  PalmSession copyWith({
    String? id,
    String? deviceId,
    HandSide? handSide,
    String? palmImagePath,
    List<double>? palmMinutiaePoints,
    String? palmPerceptualHash,
    List<double>? palmHistogramSignature,
    double? blurScore,
    double? brightnessScore,
    double? focusDistance,
    DateTime? capturedAt,
    bool? isDorsalSide,
  }) {
    return PalmSession(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      handSide: handSide ?? this.handSide,
      palmImagePath: palmImagePath ?? this.palmImagePath,
      palmMinutiaePoints: palmMinutiaePoints ?? this.palmMinutiaePoints,
      palmPerceptualHash: palmPerceptualHash ?? this.palmPerceptualHash,
      palmHistogramSignature:
          palmHistogramSignature ?? this.palmHistogramSignature,
      blurScore: blurScore ?? this.blurScore,
      brightnessScore: brightnessScore ?? this.brightnessScore,
      focusDistance: focusDistance ?? this.focusDistance,
      capturedAt: capturedAt ?? this.capturedAt,
      isDorsalSide: isDorsalSide ?? this.isDorsalSide,
    );
  }
}
