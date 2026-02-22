// lib/data/repositories/palm_repository_impl.dart
import 'package:uuid/uuid.dart';
import '../../domain/entities/luminosity_record.dart';
import '../../domain/entities/minutiae_record.dart';
import '../../domain/entities/palm_session.dart';
import '../../domain/repositories/palm_repository.dart';
import '../../services/camera_service.dart';
import '../../services/database_service.dart';
import '../../services/image_analysis_service.dart';

class PalmRepositoryImpl implements PalmRepository {
  final DatabaseService _db;
  final CameraService _cameraService;
  final ImageAnalysisService _analysisService;
  final _uuid = const Uuid();

  PalmRepositoryImpl({
    required DatabaseService db,
    required CameraService cameraService,
    required ImageAnalysisService analysisService,
  })  : _db = db,
        _cameraService = cameraService,
        _analysisService = analysisService;

  @override
  Future<void> saveSession(PalmSession session) => _db.insertSession(session);

  @override
  Future<PalmSession?> getSession(String sessionId) => _db.getSessionById(sessionId);

  @override
  Future<List<PalmSession>> getSessionsForDevice(String deviceId) =>
      _db.getSessionsByDeviceId(deviceId);

  @override
  Future<void> saveMinutiaeRecord(MinutiaeRecord record) => _db.insertMinutiae(record);

  @override
  Future<List<MinutiaeRecord>> getMinutiaeForSession(String sessionId) =>
      _db.getMinutiaeBySession(sessionId);

  @override
  Future<void> saveLuminosityRecord(LuminosityRecord record) async {
    await _db.insertLuminosity({
      'id': record.id,
      'device_id': record.deviceId,
      'brightness_score': record.brightnessScore,
      'light_condition': record.lightCondition.label,
      'camera_type': record.cameraType,
      'focal_length': record.focalLength,
      'aperture_score': record.apertureScore,
      'focus_distance': record.focusDistance,
      'blur_score': record.blurScore,
      'recorded_at': record.recordedAt.millisecondsSinceEpoch,
    });
  }

  @override
  Future<List<LuminosityRecord>> getLuminosityForDevice(String deviceId) async {
    final maps = await _db.getLuminosityByDevice(deviceId);
    return maps.map((m) {
      return LuminosityRecord(
        id: m['id'] as String,
        deviceId: m['device_id'] as String,
        brightnessScore: (m['brightness_score'] as num).toDouble(),
        lightCondition: _parseLightCondition(m['light_condition'] as String),
        cameraType: m['camera_type'] as String,
        focalLength: (m['focal_length'] as num).toDouble(),
        apertureScore: (m['aperture_score'] as num).toDouble(),
        focusDistance: (m['focus_distance'] as num).toDouble(),
        blurScore: (m['blur_score'] as num).toDouble(),
        recordedAt: DateTime.fromMillisecondsSinceEpoch(m['recorded_at'] as int),
      );
    }).toList();
  }

  LightCondition _parseLightCondition(String label) {
    switch (label) {
      case 'Low Light': return LightCondition.low;
      case 'Bright Light': return LightCondition.bright;
      default: return LightCondition.normal;
    }
  }
}
