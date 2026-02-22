// lib/domain/repositories/palm_repository.dart
import '../entities/minutiae_record.dart';
import '../entities/palm_session.dart';
import '../entities/luminosity_record.dart';

abstract class PalmRepository {
  // Sessions
  Future<void> saveSession(PalmSession session);
  Future<PalmSession?> getSession(String sessionId);
  Future<List<PalmSession>> getSessionsForDevice(String deviceId);

  // Minutiae
  Future<void> saveMinutiaeRecord(MinutiaeRecord record);
  Future<List<MinutiaeRecord>> getMinutiaeForSession(String sessionId);

  // Luminosity
  Future<void> saveLuminosityRecord(LuminosityRecord record);
  Future<List<LuminosityRecord>> getLuminosityForDevice(String deviceId);
}
