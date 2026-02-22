// lib/core/di/injection.dart
import 'package:get_it/get_it.dart';
import '../../services/camera_service.dart';
import '../../services/database_service.dart';
import '../../services/hand_detection_service.dart';
import '../../services/image_analysis_service.dart';
import '../../services/permission_service.dart';
import '../../data/repositories/palm_repository_impl.dart';
import '../../domain/repositories/palm_repository.dart';
import '../../presentation/viewmodels/palm_detection_viewmodel.dart';
import '../../presentation/viewmodels/finger_detection_viewmodel.dart';
import '../../presentation/viewmodels/result_viewmodel.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Services (singletons)
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService());
  getIt.registerLazySingleton<PermissionService>(() => PermissionService());
  getIt.registerLazySingleton<ImageAnalysisService>(
      () => ImageAnalysisService());
  getIt.registerLazySingleton<HandDetectionService>(
      () => HandDetectionService());
  getIt.registerLazySingleton<CameraService>(
    () => CameraService(),
  );

  // Repositories
  getIt.registerLazySingleton<PalmRepository>(
    () => PalmRepositoryImpl(
      db: getIt<DatabaseService>(),
      cameraService: getIt<CameraService>(),
      analysisService: getIt<ImageAnalysisService>(),
    ),
  );

  // ViewModels (factories - new instance per use)
  getIt.registerFactory<PalmDetectionViewModel>(
    () => PalmDetectionViewModel(
      repository: getIt<PalmRepository>(),
      cameraService: getIt<CameraService>(),
      analysisService: getIt<ImageAnalysisService>(),
      handDetectionService: getIt<HandDetectionService>(),
      permissionService: getIt<PermissionService>(),
    ),
  );

  getIt.registerFactory<FingerDetectionViewModel>(
    () => FingerDetectionViewModel(
      repository: getIt<PalmRepository>(),
      cameraService: getIt<CameraService>(),
      analysisService: getIt<ImageAnalysisService>(),
      handDetectionService: getIt<HandDetectionService>(),
    ),
  );

  getIt.registerFactory<ResultViewModel>(
    () => ResultViewModel(
      repository: getIt<PalmRepository>(),
    ),
  );
}
