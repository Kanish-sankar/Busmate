import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_url_launcher/easy_url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateDecision {
  final bool hardUpdateRequired;
  final bool softUpdateAvailable;
  final String currentVersion;
  final String latestVersion;
  final String minVersion;
  final String updateUrl;
  final String message;
  final int graceDays;

  const AppUpdateDecision({
    required this.hardUpdateRequired,
    required this.softUpdateAvailable,
    required this.currentVersion,
    required this.latestVersion,
    required this.minVersion,
    required this.updateUrl,
    required this.message,
    required this.graceDays,
  });

  static AppUpdateDecision noUpdate({required String currentVersion}) {
    return AppUpdateDecision(
      hardUpdateRequired: false,
      softUpdateAvailable: false,
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      minVersion: currentVersion,
      updateUrl: '',
      message: 'A new update is available.',
      graceDays: 5,
    );
  }
}

class AppUpdateService {
  static const String _collection = 'app_config';
  static const String _document = 'version_control';
  static const String _softPromptStorageKey = 'lastSoftUpdatePromptAt';
  static const String _adoptionTrackKeyPrefix = 'lastAdoptionTrackDate';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AppUpdateService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<AppUpdateDecision> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      final snapshot = await _firestore.collection(_collection).doc(_document).get();
      if (!snapshot.exists || snapshot.data() == null) {
        return AppUpdateDecision.noUpdate(currentVersion: currentVersion);
      }

      final data = snapshot.data()!;
      final latestVersion = (data['latest_version'] as String?)?.trim() ?? currentVersion;
      final minVersion = _getMinVersionForPlatform(data) ?? currentVersion;
      final forceUpdate = data['force_update'] == true;
      final message = (data['force_update_message'] as String?)?.trim().isNotEmpty == true
          ? (data['force_update_message'] as String)
          : 'A new update is available for better performance and reliability.';
      final updateUrl = _getUpdateUrlForPlatform(data) ?? '';
      final graceDays = (data['grace_days'] as num?)?.toInt() ?? 5;

      final belowMin = _compareVersions(currentVersion, minVersion) < 0;
      final belowLatest = _compareVersions(currentVersion, latestVersion) < 0;
      final hardUpdateRequired = belowMin || (forceUpdate && belowLatest);

      return AppUpdateDecision(
        hardUpdateRequired: hardUpdateRequired,
        softUpdateAvailable: belowLatest && !hardUpdateRequired,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        minVersion: minVersion,
        updateUrl: updateUrl,
        message: message,
        graceDays: graceDays,
      );
    } catch (_) {
      return AppUpdateDecision.noUpdate(currentVersion: currentVersion);
    }
  }

  Future<void> trackVersionAdoption() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final storage = GetStorage();
      final now = DateTime.now();
      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final trackStorageKey = '$_adoptionTrackKeyPrefix:${user.uid}';
      final lastTrackedDate = storage.read(trackStorageKey);

      if (lastTrackedDate is String && lastTrackedDate == todayKey) {
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final platform = _platformName();

      await _firestore.collection('adminusers').doc(user.uid).set({
        'appVersion': packageInfo.version,
        'appBuildNumber': packageInfo.buildNumber,
        'appPlatform': platform,
        'lastAppSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      storage.write(trackStorageKey, todayKey);
    } catch (_) {}
  }

  bool shouldShowSoftPromptNow({required bool isSoftUpdateAvailable}) {
    if (!isSoftUpdateAvailable) {
      return false;
    }

    final storage = GetStorage();
    final now = DateTime.now();
    final lastPromptMs = storage.read(_softPromptStorageKey);

    if (lastPromptMs is int) {
      final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptMs);
      final elapsed = now.difference(lastPrompt);
      if (elapsed.inHours < 24) {
        return false;
      }
    }

    storage.write(_softPromptStorageKey, now.millisecondsSinceEpoch);
    return true;
  }

  Future<void> openStore(AppUpdateDecision decision) async {
    if (decision.updateUrl.isEmpty) {
      return;
    }
    await EasyLauncher.url(url: decision.updateUrl);
  }

  String? _getMinVersionForPlatform(Map<String, dynamic> data) {
    if (kIsWeb) {
      return (data['min_version_web'] as String?)?.trim();
    }
    if (Platform.isAndroid) {
      return (data['min_version_android'] as String?)?.trim();
    }
    if (Platform.isIOS) {
      return (data['min_version_ios'] as String?)?.trim();
    }
    return (data['min_version'] as String?)?.trim();
  }

  String? _getUpdateUrlForPlatform(Map<String, dynamic> data) {
    if (kIsWeb) {
      return (data['update_url_web'] as String?)?.trim();
    }
    if (Platform.isAndroid) {
      return (data['update_url_android'] as String?)?.trim();
    }
    if (Platform.isIOS) {
      return (data['update_url_ios'] as String?)?.trim();
    }
    return (data['update_url'] as String?)?.trim();
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'other';
  }

  int _compareVersions(String a, String b) {
    final aParts = _normalizeVersion(a);
    final bParts = _normalizeVersion(b);
    final length = aParts.length > bParts.length ? aParts.length : bParts.length;

    for (int index = 0; index < length; index++) {
      final aValue = index < aParts.length ? aParts[index] : 0;
      final bValue = index < bParts.length ? bParts[index] : 0;
      if (aValue > bValue) {
        return 1;
      }
      if (aValue < bValue) {
        return -1;
      }
    }

    return 0;
  }

  List<int> _normalizeVersion(String version) {
    final clean = version.split('+').first;
    return clean
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
