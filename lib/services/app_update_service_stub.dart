import 'package:flutter/foundation.dart';
import 'app_update_models.dart';

class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const currentBuildId = String.fromEnvironment(
    'APP_BUILD_ID',
    defaultValue: 'local-unknown',
  );

  bool get isUpdateAvailable => false;
  bool get isChecking => false;
  bool get isBusy => false;
  AppUpdateState get state => AppUpdateState.idle;
  AppBuildMetadata? get remoteBuild => null;
  String? get workerSummary => null;
  String? get latestBuildId => null;
  String? get latestDeployedAt => null;
  String? get lastError => null;

  void start() {}

  Future<void> checkNow({String reason = 'manual'}) async {}

  Future<void> reloadToUpdate() async {}
}
