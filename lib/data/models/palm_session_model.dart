// lib/data/models/palm_session_model.dart
import 'dart:convert';
import '../../domain/entities/palm_session.dart';

class PalmSessionModel extends PalmSession {
  const PalmSessionModel({
    required super.id,
    required super.deviceId,
    required super.handSide,
    required super.palmImagePath,
    required super.palmMinutiaePoints,
    required super.palmPerceptualHash,
    required super.palmHistogramSignature,
    required super.blurScore,
    required super.brightnessScore,
    required super.focusDistance,
    required super.capturedAt,
    super.isDorsalSide,
  });

  factory PalmSessionModel.fromMap(Map<String, dynamic> map) {
    return PalmSessionModel(
      id: map['id'] as String,
      deviceId: map['device_id'] as String,
      handSide: HandSideExtension.fromLabel(map['hand_side'] as String),
      palmImagePath: map['palm_image_path'] as String,
      palmMinutiaePoints: (jsonDecode(map['palm_minutiae_points'] as String) as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      palmPerceptualHash: map['palm_perceptual_hash'] as String,
      palmHistogramSignature: (jsonDecode(map['palm_histogram_signature'] as String) as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      blurScore: (map['blur_score'] as num).toDouble(),
      brightnessScore: (map['brightness_score'] as num).toDouble(),
      focusDistance: (map['focus_distance'] as num).toDouble(),
      capturedAt: DateTime.fromMillisecondsSinceEpoch(map['captured_at'] as int),
      isDorsalSide: (map['is_dorsal_side'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'hand_side': handSide.label,
      'palm_image_path': palmImagePath,
      'palm_minutiae_points': jsonEncode(palmMinutiaePoints),
      'palm_perceptual_hash': palmPerceptualHash,
      'palm_histogram_signature': jsonEncode(palmHistogramSignature),
      'blur_score': blurScore,
      'brightness_score': brightnessScore,
      'focus_distance': focusDistance,
      'captured_at': capturedAt.millisecondsSinceEpoch,
      'is_dorsal_side': isDorsalSide ? 1 : 0,
    };
  }

  factory PalmSessionModel.fromEntity(PalmSession entity) {
    return PalmSessionModel(
      id: entity.id,
      deviceId: entity.deviceId,
      handSide: entity.handSide,
      palmImagePath: entity.palmImagePath,
      palmMinutiaePoints: entity.palmMinutiaePoints,
      palmPerceptualHash: entity.palmPerceptualHash,
      palmHistogramSignature: entity.palmHistogramSignature,
      blurScore: entity.blurScore,
      brightnessScore: entity.brightnessScore,
      focusDistance: entity.focusDistance,
      capturedAt: entity.capturedAt,
      isDorsalSide: entity.isDorsalSide,
    );
  }
}
