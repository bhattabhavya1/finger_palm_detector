# 🖐 Palm & Finger Detection App

A Flutter Android application for biometric palm and finger detection using computer vision and ML Kit.

---

## 📱 Features


---

## 🏗️ Architecture

**MVVM** (Model-View-ViewModel)

```
lib/
├── core/
│   ├── constants/       # AppColors, AppTheme, AppRoutes, AppConstants
│   ├── di/              # GetIt dependency injection
│   └── router/          # AppRouter (named routes with transitions)
│
├── data/
│   ├── models/          # DB-serializable model classes
│   └── repositories/    # PalmRepositoryImpl
│
├── domain/
│   ├── entities/        # PalmSession, MinutiaeRecord, LuminosityRecord
│   ├── repositories/    # PalmRepository (abstract)
│   └── usecases/        # (extendable)
│
├── presentation/
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── home_screen.dart
│   │   ├── permission_screen.dart
│   │   ├── palm_detection/      # Palm camera screen
│   │   ├── finger_detection/    # Finger camera screen
│   │   └── result/              # Final results screen
│   ├── viewmodels/              # PalmDetectionViewModel, FingerDetectionViewModel, ResultViewModel
│   └── widgets/                 # CameraOverlays, CaptureButton, ErrorBanner, LuminosityIndicator
│
└── services/
    ├── camera_service.dart          # CameraX wrapper, luminosity, image saving
    ├── database_service.dart        # SQLite helper
    ├── hand_detection_service.dart  # ML Kit Pose Detection + heuristic fallback
    ├── image_analysis_service.dart  # Blur, brightness, minutiae, pHash, histogram
    └── permission_service.dart      # Runtime permissions
```

---

## 🛠️ Setup & Build

### Prerequisites

- Flutter SDK `>=3.10.0`
- Android Studio / VS Code
- Android device or emulator with API 21+
- Physical device recommended (camera features)

### Steps

```bash
# 1. Clone / unzip the project
cd palm_finger_detection

# 2. Get dependencies
flutter pub get

# 3. Run on connected Android device
flutter run

# 4. Build release APK
flutter build apk --release
```

### Permissions Required

The app will request at runtime:
- `CAMERA`
- `READ_MEDIA_IMAGES` (Android 13+) / `READ_EXTERNAL_STORAGE` (Android 12 and below)
- `WRITE_EXTERNAL_STORAGE` (Android 9 and below)

---

## 📁 File Storage Format

All captured images are saved to: `/storage/emulated/0/Finger Data/`


---

## 🧠 ML & Computer Vision Approach

### Hand Detection
- **Primary:** Google ML Kit Pose Detection (MediaPipe-based) — uses wrist/thumb/pinky landmarks to detect hand side and finger count
- **Fallback:** YCbCr skin color heuristic — estimates hand presence and side from pixel mass distribution

---

---

## 📦 Key Dependencies

| Package | Purpose |
|---|---|
| `camera` | CameraX-based camera preview & capture |
| `google_mlkit_pose_detection` | Hand/pose landmark detection |
| `image` | Pure-Dart image processing (blur, brightness, minutiae) |
| `provider` | ViewModel state management |
| `sqflite` | Local SQLite database |
| `permission_handler` | Runtime permissions |
| `device_info_plus` | Device ID for per-device data storage |
| `flutter_screenutil` | Responsive UI scaling |
| `uuid` | Unique session/record IDs |

---
