// lib/data/models/minutiae_record_model.dart
import 'dart:convert';
import '../../domain/entities/minutiae_record.dart';

class MinutiaeRecordModel extends MinutiaeRecord {
  const MinutiaeRecordModel({
    required super.id,
    required super.sessionId,
    required super.handSide,
    required super.fingerName,
    required super.imagePath,
    required super.minutiaePoints,
    required super.perceptualHash,
    required super.histogramSignature,
    required super.blurScore,
    required super.brightnessScore,
    required super.focusDistance,
    required super.capturedAt,
  });

  factory MinutiaeRecordModel.fromMap(Map<String, dynamic> map) {
    return MinutiaeRecordModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      handSide: map['hand_side'] as String,
      fingerName: map['finger_name'] as String,
      imagePath: map['image_path'] as String,
      minutiaePoints: (jsonDecode(map['minutiae_points'] as String) as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      perceptualHash: map['perceptual_hash'] as String,
      histogramSignature: (jsonDecode(map['histogram_signature'] as String) as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      blurScore: (map['blur_score'] as num).toDouble(),
      brightnessScore: (map['brightness_score'] as num).toDouble(),
      focusDistance: (map['focus_distance'] as num).toDouble(),
      capturedAt: DateTime.fromMillisecondsSinceEpoch(map['captured_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'hand_side': handSide,
      'finger_name': fingerName,
      'image_path': imagePath,
      'minutiae_points': jsonEncode(minutiaePoints),
      'perceptual_hash': perceptualHash,
      'histogram_signature': jsonEncode(histogramSignature),
      'blur_score': blurScore,
      'brightness_score': brightnessScore,
      'focus_distance': focusDistance,
      'captured_at': capturedAt.millisecondsSinceEpoch,
    };
  }

  factory MinutiaeRecordModel.fromEntity(MinutiaeRecord entity) {
    return MinutiaeRecordModel(
      id: entity.id,
      sessionId: entity.sessionId,
      handSide: entity.handSide,
      fingerName: entity.fingerName,
      imagePath: entity.imagePath,
      minutiaePoints: entity.minutiaePoints,
      perceptualHash: entity.perceptualHash,
      histogramSignature: entity.histogramSignature,
      blurScore: entity.blurScore,
      brightnessScore: entity.brightnessScore,
      focusDistance: entity.focusDistance,
      capturedAt: entity.capturedAt,
    );
  }
}
