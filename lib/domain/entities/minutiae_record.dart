// lib/domain/entities/minutiae_record.dart
import 'package:equatable/equatable.dart';

/// Represents the extracted minutiae points of a single finger
class MinutiaeRecord extends Equatable {
  final String id;
  final String sessionId;
  final String handSide; // 'Left_Hand' | 'Right_Hand'
  final String fingerName; // 'Thumb' | 'Index' | etc.
  final String imagePath;

  /// Flattened list of (x, y, type) points extracted from the fingerprint image
  final List<double> minutiaePoints;

  /// Perceptual hash for quick similarity comparison
  final String perceptualHash;

  /// Histogram signature (128-dim) for robust matching
  final List<double> histogramSignature;

  final double blurScore;
  final double brightnessScore;
  final double focusDistance;
  final DateTime capturedAt;

  const MinutiaeRecord({
    required this.id,
    required this.sessionId,
    required this.handSide,
    required this.fingerName,
    required this.imagePath,
    required this.minutiaePoints,
    required this.perceptualHash,
    required this.histogramSignature,
    required this.blurScore,
    required this.brightnessScore,
    required this.focusDistance,
    required this.capturedAt,
  });

  String get fullLabel => '${handSide}_${fingerName}_Finger';

  @override
  List<Object?> get props => [id, sessionId, handSide, fingerName, imagePath];

  MinutiaeRecord copyWith({
    String? id,
    String? sessionId,
    String? handSide,
    String? fingerName,
    String? imagePath,
    List<double>? minutiaePoints,
    String? perceptualHash,
    List<double>? histogramSignature,
    double? blurScore,
    double? brightnessScore,
    double? focusDistance,
    DateTime? capturedAt,
  }) {
    return MinutiaeRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      handSide: handSide ?? this.handSide,
      fingerName: fingerName ?? this.fingerName,
      imagePath: imagePath ?? this.imagePath,
      minutiaePoints: minutiaePoints ?? this.minutiaePoints,
      perceptualHash: perceptualHash ?? this.perceptualHash,
      histogramSignature: histogramSignature ?? this.histogramSignature,
      blurScore: blurScore ?? this.blurScore,
      brightnessScore: brightnessScore ?? this.brightnessScore,
      focusDistance: focusDistance ?? this.focusDistance,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }
}
