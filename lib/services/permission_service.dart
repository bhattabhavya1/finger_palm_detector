// lib/services/permission_service.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

class PermissionService {
  final Logger _logger = Logger();

  /// Request all permissions needed for the app
  Future<PermissionStatus> requestAll() async {
    final statuses = await [
      Permission.camera,
      if (Platform.isAndroid) _storagePermission,
    ].request();

    _logger.d('Permission statuses: $statuses');

    final camera = statuses[Permission.camera];
    if (camera != PermissionStatus.granted) {
      return camera ?? PermissionStatus.denied;
    }

    final storage = statuses[_storagePermission];
    if (storage != PermissionStatus.granted) {
      return storage ?? PermissionStatus.denied;
    }

    return PermissionStatus.granted;
  }

  Permission get _storagePermission {
    if (Platform.isAndroid) {
      // Android 13+: READ_MEDIA_IMAGES; below: READ_EXTERNAL_STORAGE
      if (_isAndroid13OrAbove) {
        return Permission.photos;
      }
      return Permission.storage;
    }
    return Permission.storage;
  }

  bool get _isAndroid13OrAbove {
    // We default to true to be safe
    return true;
  }

  Future<bool> isCameraGranted() async {
    return await Permission.camera.isGranted;
  }

  Future<bool> isStorageGranted() async {
    if (Platform.isAndroid) {
      if (_isAndroid13OrAbove) {
        return await Permission.photos.isGranted || await Permission.manageExternalStorage.isGranted;
      }
      return await Permission.storage.isGranted;
    }
    return true;
  }

  Future<bool> areAllGranted() async {
    return await isCameraGranted() && await isStorageGranted();
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
