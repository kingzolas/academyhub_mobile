enum AppUpdateState {
  idle,
  checking,
  upToDate,
  updateAvailable,
  waitingForSafeState,
  updating,
  reloading,
  offline,
  failed,
}

class AppBuildMetadata {
  const AppBuildMetadata({
    required this.app,
    required this.version,
    required this.buildNumber,
    required this.buildId,
    required this.commit,
    required this.deployedAt,
  });

  final String app;
  final String version;
  final String buildNumber;
  final String buildId;
  final String commit;
  final String deployedAt;

  static AppBuildMetadata? tryParse(Map<String, dynamic> json) {
    String value(String key) => (json[key] ?? '').toString().trim();

    final metadata = AppBuildMetadata(
      app: value('app'),
      version: value('version'),
      buildNumber: value('buildNumber'),
      buildId: value('buildId'),
      commit: value('commit'),
      deployedAt: value('deployedAt'),
    );

    if (metadata.app.isEmpty ||
        metadata.buildId.isEmpty ||
        metadata.deployedAt.isEmpty) {
      return null;
    }
    return metadata;
  }

  bool differsFrom(String currentBuildId) => buildId != currentBuildId;
}

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.state,
    required this.currentBuildId,
    this.remoteBuild,
    this.message,
    this.workerSummary,
  });

  final AppUpdateState state;
  final String currentBuildId;
  final AppBuildMetadata? remoteBuild;
  final String? message;
  final String? workerSummary;

  bool get isUpdateAvailable =>
      remoteBuild != null && remoteBuild!.differsFrom(currentBuildId);
  bool get isBusy =>
      state == AppUpdateState.checking ||
      state == AppUpdateState.updating ||
      state == AppUpdateState.reloading;
}
