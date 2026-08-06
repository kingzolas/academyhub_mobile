import 'dart:async';
import 'dart:convert';

import 'package:academyhub_mobile/services/app_update_models.dart';
import 'package:academyhub_mobile/services/app_update_safety.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const currentBuildId = String.fromEnvironment(
    'APP_BUILD_ID',
    defaultValue: 'local-unknown',
  );
  static const _enableLogs = bool.fromEnvironment(
    'APP_UPDATE_LOGS',
    defaultValue: kDebugMode,
  );
  static const _checkIntervalSeconds = int.fromEnvironment(
    'APP_UPDATE_CHECK_SECONDS',
    defaultValue: 300,
  );
  static const _requestTimeout = Duration(seconds: 8);
  static const _minimumForegroundCheckGap = Duration(minutes: 1);
  static const _reloadAttemptKey = 'academyhub.update.reloadTarget';

  final AppUpdateSafety _safety = AppUpdateSafety.instance;
  Timer? _timer;
  StreamSubscription<html.Event>? _focusSubscription;
  StreamSubscription<html.Event>? _visibilitySubscription;
  StreamSubscription<html.Event>? _onlineSubscription;
  html.ServiceWorkerContainer? _observedServiceWorker;
  late final html.EventListener _controllerChangeListener = _onControllerChange;
  DateTime? _lastCheckAt;
  bool _started = false;
  bool _isChecking = false;
  bool _isReloading = false;
  AppUpdateState _state = AppUpdateState.idle;
  AppBuildMetadata? _remoteBuild;
  String? _lastError;
  String? _workerSummary;

  bool get isUpdateAvailable =>
      _remoteBuild != null && _remoteBuild!.differsFrom(currentBuildId);
  bool get isChecking => _isChecking;
  bool get isBusy =>
      _isChecking ||
      _isReloading ||
      _state == AppUpdateState.updating ||
      _state == AppUpdateState.reloading;
  AppUpdateState get state => _state;
  AppBuildMetadata? get remoteBuild => _remoteBuild;
  String? get workerSummary => _workerSummary;
  String? get latestBuildId => _remoteBuild?.buildId;
  String? get latestDeployedAt => _remoteBuild?.deployedAt;
  String? get lastError => _lastError;

  void start() {
    if (_started) return;
    _started = true;
    _log('[AppUpdate] currentBuild=$currentBuildId');

    _safety.addListener(_onSafetyChanged);
    _focusSubscription = html.window.onFocus.listen((_) {
      _checkAfterForegroundEvent('focus');
    });
    _visibilitySubscription = html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible') {
        _checkAfterForegroundEvent('visible');
      }
    });
    _onlineSubscription = html.window.onOnline.listen((_) {
      unawaited(checkNow(reason: 'online'));
    });
    _observeServiceWorker();
    _timer = Timer.periodic(
      const Duration(seconds: _checkIntervalSeconds),
      (_) => unawaited(checkNow(reason: 'interval')),
    );
    unawaited(checkNow(reason: 'startup'));
  }

  void _onSafetyChanged() {
    if (_state == AppUpdateState.waitingForSafeState && _safety.canReload) {
      _setState(AppUpdateState.updateAvailable);
    }
  }

  void _checkAfterForegroundEvent(String reason) {
    final lastCheckAt = _lastCheckAt;
    if (lastCheckAt != null &&
        DateTime.now().difference(lastCheckAt) < _minimumForegroundCheckGap) {
      return;
    }
    unawaited(checkNow(reason: reason));
  }

  Future<void> checkNow({String reason = 'manual'}) async {
    if (_isChecking || _isReloading) return;
    if (!_isOnline) {
      _setState(AppUpdateState.offline, message: 'Sem conexão com a internet.');
      return;
    }

    _isChecking = true;
    _lastError = null;
    _setState(AppUpdateState.checking, notify: false);
    notifyListeners();

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final uri = Uri.base.resolve('version.json?t=$timestamp');
    _log('[AppUpdate] checking reason=$reason uri=$uri');

    try {
      final payload = await _fetchVersion(uri);
      final remoteBuild = AppBuildMetadata.tryParse(payload);
      if (remoteBuild == null) {
        throw const FormatException('version.json inválido ou incompleto.');
      }

      _remoteBuild = remoteBuild;
      if (remoteBuild.buildId == currentBuildId) {
        html.window.localStorage.remove(_reloadAttemptKey);
        _setState(AppUpdateState.upToDate);
      } else if (_safety.canReload) {
        _setState(AppUpdateState.updateAvailable);
      } else {
        _setState(AppUpdateState.waitingForSafeState);
      }
    } on TimeoutException {
      _lastError = 'A verificação de atualização excedeu o tempo limite.';
      _setState(AppUpdateState.failed);
    } catch (error) {
      _lastError = error.toString();
      _setState(AppUpdateState.failed);
      _log('[AppUpdate] check failed error=$_lastError');
    } finally {
      _lastCheckAt = DateTime.now();
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _fetchVersion(Uri uri) async {
    final dynamic response = await html.window.fetch(
      uri.toString(),
      <String, dynamic>{
        'cache': 'no-store',
        'credentials': 'same-origin',
        'headers': <String, String>{
          'Cache-Control': 'no-store, no-cache, must-revalidate',
          'Pragma': 'no-cache',
        },
      },
    ).timeout(_requestTimeout);
    final status = response.status as int? ?? 0;
    if (status < 200 || status >= 300) {
      throw StateError('version.json HTTP $status');
    }
    final body = await response.text() as String;
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('version.json deve conter um objeto JSON.');
    }
    return decoded;
  }

  /// Starts only an update of the known Flutter worker. It never unregisters a
  /// registration and never deletes CacheStorage, IndexedDB, preferences or
  /// credentials. The Flutter 3.41 migration worker handles its own cleanup.
  Future<void> _requestFlutterWorkerUpdate() async {
    try {
      final serviceWorker = html.window.navigator.serviceWorker;
      if (serviceWorker == null) {
        _workerSummary = 'Service Worker API indisponível';
        notifyListeners();
        return;
      }
      final registrations = await serviceWorker.getRegistrations();
      final matching = registrations
          .whereType<html.ServiceWorkerRegistration>()
          .where(_isKnownFlutterRegistration)
          .toList();
      if (matching.isEmpty) {
        _workerSummary = 'Nenhum worker Flutter registrado';
        notifyListeners();
        return;
      }

      final states = <String>[];
      for (final registration in matching) {
        final waiting = registration.waiting;
        if (waiting != null) {
          waiting.postMessage(<String, String>{'action': 'skipWaiting'});
        }
        await registration.update();
        states.add(_registrationSummary(registration));
      }
      _workerSummary = states.join(' | ');
      notifyListeners();
    } catch (error) {
      _workerSummary = 'Falha ao verificar worker Flutter: $error';
      _log('[AppUpdate] worker migration failed error=$error');
      notifyListeners();
    }
  }

  bool _isKnownFlutterRegistration(
      html.ServiceWorkerRegistration registration) {
    final scope = Uri.tryParse(registration.scope ?? '');
    if (scope == null || scope.origin != Uri.base.origin || scope.path != '/') {
      return false;
    }
    final workers = <html.ServiceWorker?>[
      registration.active,
      registration.waiting,
      registration.installing,
    ];
    return workers.whereType<html.ServiceWorker>().any((worker) {
      final script = Uri.tryParse(worker.scriptUrl ?? '');
      return script != null &&
          script.origin == Uri.base.origin &&
          script.path.endsWith('/flutter_service_worker.js');
    });
  }

  String _registrationSummary(html.ServiceWorkerRegistration registration) {
    String stateOf(html.ServiceWorker? worker) => worker?.state ?? '-';
    return 'scope=${registration.scope} active=${stateOf(registration.active)} '
        'waiting=${stateOf(registration.waiting)} '
        'installing=${stateOf(registration.installing)}';
  }

  void _observeServiceWorker() {
    final serviceWorker = html.window.navigator.serviceWorker;
    if (serviceWorker == null) return;
    _observedServiceWorker = serviceWorker;
    serviceWorker.addEventListener(
        'controllerchange', _controllerChangeListener);
  }

  void _onControllerChange(html.Event _) {
    _workerSummary = 'Controller do Service Worker foi atualizado';
    _log('[AppUpdate] service worker controller changed');
    notifyListeners();
  }

  Future<void> reloadToUpdate() async {
    final remoteBuild = _remoteBuild;
    if (remoteBuild == null || !remoteBuild.differsFrom(currentBuildId)) return;
    if (_isReloading) return;
    if (!_safety.canReload) {
      _setState(AppUpdateState.waitingForSafeState);
      return;
    }

    final previousTarget = html.window.localStorage[_reloadAttemptKey];
    if (previousTarget == remoteBuild.buildId) {
      _lastError =
          'A recarga para este build já foi tentada. Verifique a conexão.';
      _setState(AppUpdateState.failed);
      return;
    }

    _isReloading = true;
    html.window.localStorage[_reloadAttemptKey] = remoteBuild.buildId;
    _setState(AppUpdateState.updating);
    await _requestFlutterWorkerUpdate();
    await _waitForWorkerSettlement();
    _setState(AppUpdateState.reloading);

    // A navegação com parâmetro único evita reutilizar uma entrada de histórico.
    // A proteção em localStorage impede loops se um worker legado ainda responder.
    final nextUri = Uri.base.replace(
      queryParameters: <String, String>{
        ...Uri.base.queryParameters,
        'academyhub_update': remoteBuild.buildId,
      },
    );
    html.window.location.assign(nextUri.toString());
  }

  /// Gives a newly installed migration worker a short opportunity to replace
  /// an old controller. A timeout is intentional: an update must not trap an
  /// online user forever if a browser postpones worker activation.
  Future<void> _waitForWorkerSettlement() async {
    final serviceWorker = html.window.navigator.serviceWorker;
    if (serviceWorker == null || serviceWorker.controller == null) return;
    final completer = Completer<void>();
    late final html.EventListener listener;
    listener = (html.Event _) {
      if (!completer.isCompleted) completer.complete();
    };
    serviceWorker.addEventListener('controllerchange', listener);
    try {
      await completer.future.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      _log('[AppUpdate] worker controller did not change before reload');
    } finally {
      serviceWorker.removeEventListener('controllerchange', listener);
    }
  }

  bool get _isOnline => html.window.navigator.onLine != false;

  void _setState(AppUpdateState state, {String? message, bool notify = true}) {
    _state = state;
    if (message != null) _lastError = message;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _safety.removeListener(_onSafetyChanged);
    unawaited(_focusSubscription?.cancel());
    unawaited(_visibilitySubscription?.cancel());
    unawaited(_onlineSubscription?.cancel());
    _observedServiceWorker?.removeEventListener(
      'controllerchange',
      _controllerChangeListener,
    );
    super.dispose();
  }

  void _log(String message) {
    if (_enableLogs) debugPrint(message);
  }
}
