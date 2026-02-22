// lib/domain/entities/luminosity_record.dart
import 'package:equatable/equatable.dart';

/// Light condition categorization
enum LightCondition {
  low,
  normal,
  bright,
}

/// Extension to add label support to LightCondition
extension LightConditionExtension on LightCondition {
  String get label {
    switch (this) {
      case LightCondition.low:
        return 'Low Light';
      case LightCondition.normal:
        return 'Normal Light';
      case LightCondition.bright:
        return 'Bright Light';
    }
  }
}

/// Represents a luminosity/light measurement record
class LuminosityRecord extends Equatable {
  final String id;
  final String deviceId;
  final double brightnessScore;
  final LightCondition lightCondition;
  final String cameraType;
  final double focalLength;
  final double apertureScore;
  final double focusDistance;
  final double blurScore;
  final DateTime recordedAt;

  const LuminosityRecord({
    required this.id,
    required this.deviceId,
    required this.brightnessScore,
    required this.lightCondition,
    required this.cameraType,
    required this.focalLength,
    required this.apertureScore,
    required this.focusDistance,
    required this.blurScore,
    required this.recordedAt,
  });

  @override
  List<Object?> get props => [id, deviceId, recordedAt];

  LuminosityRecord copyWith({
    String? id,
    String? deviceId,
    double? brightnessScore,
    LightCondition? lightCondition,
    String? cameraType,
    double? focalLength,
    double? apertureScore,
    double? focusDistance,
    double? blurScore,
    DateTime? recordedAt,
  }) {
    return LuminosityRecord(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      brightnessScore: brightnessScore ?? this.brightnessScore,
      lightCondition: lightCondition ?? this.lightCondition,
      cameraType: cameraType ?? this.cameraType,
      focalLength: focalLength ?? this.focalLength,
      apertureScore: apertureScore ?? this.apertureScore,
      focusDistance: focusDistance ?? this.focusDistance,
      blurScore: blurScore ?? this.blurScore,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}
