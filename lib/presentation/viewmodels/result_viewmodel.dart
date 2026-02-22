// lib/presentation/viewmodels/result_viewmodel.dart
import 'package:flutter/foundation.dart';
import '../../domain/entities/minutiae_record.dart';
import '../../domain/entities/palm_session.dart';
import '../../domain/repositories/palm_repository.dart';

class ResultViewModel extends ChangeNotifier {
  final PalmRepository _repository;

  PalmSession? _session;
  PalmSession? get session => _session;

  List<MinutiaeRecord> _fingerRecords = [];
  List<MinutiaeRecord> get fingerRecords => List.unmodifiable(_fingerRecords);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ResultViewModel({required PalmRepository repository})
      : _repository = repository;

  Future<void> loadResults(String sessionId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _session = await _repository.getSession(sessionId);
      _fingerRecords = await _repository.getMinutiaeForSession(sessionId);
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double get avgBlurScore {
    if (_fingerRecords.isEmpty) return _session?.blurScore ?? 0;
    return _fingerRecords.map((r) => r.blurScore).reduce((a, b) => a + b) / _fingerRecords.length;
  }

  double get avgBrightnessScore {
    if (_fingerRecords.isEmpty) return _session?.brightnessScore ?? 0;
    return _fingerRecords.map((r) => r.brightnessScore).reduce((a, b) => a + b) / _fingerRecords.length;
  }

  double get avgFocusDistance {
    if (_fingerRecords.isEmpty) return _session?.focusDistance ?? 0;
    return _fingerRecords.map((r) => r.focusDistance).reduce((a, b) => a + b) / _fingerRecords.length;
  }
}
