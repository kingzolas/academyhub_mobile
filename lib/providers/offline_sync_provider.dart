import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../services/attendance_service.dart';
import '../services/auth_session_manager.dart';
import '../services/offline_attendance_store.dart';
import 'auth_provider.dart';

class OfflineSyncProvider with ChangeNotifier {
  final AttendanceService _service = AttendanceService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<void>? _queueSubscription;
  String? _identity;
  bool _isOnline = true;
  bool _syncing = false;
  int _pendingCount = 0;
  int _conflictCount = 0;
  String? _confirmation;
  Timer? _confirmationTimer;
  Timer? _retryTimer;

  bool get isOnline => _isOnline;
  bool get isSyncing => _syncing;
  int get pendingCount => _pendingCount;
  int get conflictCount => _conflictCount;
  String? get confirmation => _confirmation;

  OfflineSyncProvider() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivity);
    _queueSubscription =
        OfflineAttendanceStore.instance.queueChanges.listen((_) async {
      await _refreshCounts();
      if (_isOnline) unawaited(processQueue());
    });
    AuthSessionManager.instance.onSessionRenewed = () => processQueue();
  }

  Future<void> updateAuth(AuthProvider auth) async {
    final user = auth.user;
    if (user == null ||
        user.id.isEmpty ||
        user.schoolId.isEmpty ||
        auth.isGuardian) {
      _identity = null;
      OfflineAttendanceStore.instance.deactivate();
      _pendingCount = 0;
      _conflictCount = 0;
      notifyListeners();
      return;
    }
    final nextIdentity = '${user.schoolId}.${user.id}';
    if (_identity == nextIdentity) return;
    _identity = nextIdentity;
    OfflineAttendanceStore.instance
        .activate(userId: user.id, schoolId: user.schoolId);
    final connectivity = await Connectivity().checkConnectivity();
    _isOnline = !connectivity.contains(ConnectivityResult.none);
    await _refreshCounts();
    if (_isOnline) unawaited(processQueue());
  }

  Future<void> _onConnectivity(List<ConnectivityResult> results) async {
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);
    notifyListeners();
    if (_isOnline && !wasOnline) {
      unawaited(AuthSessionManager.instance.retryPendingLogouts());
      await processQueue();
    }
  }

  Future<void> processQueue() async {
    if (_syncing || !_isOnline || _identity == null) return;
    _syncing = true;
    notifyListeners();
    var synchronized = 0;
    var temporaryFailure = false;
    final operations =
        await OfflineAttendanceStore.instance.pendingOperations();
    for (final operation
        in operations.where((item) => item.state != 'conflict')) {
      try {
        final sheet = await _service.syncOperation(operation);
        await OfflineAttendanceStore.instance.saveSheet(sheet);
        await OfflineAttendanceStore.instance
            .removeOperation(operation.operationId);
        synchronized++;
      } on AttendanceConflictException catch (error) {
        await OfflineAttendanceStore.instance.markFailure(
          operation.operationId,
          error.message,
          conflict: true,
        );
      } catch (_) {
        temporaryFailure = true;
        break;
      }
    }
    _syncing = false;
    await _refreshCounts();
    if (synchronized > 0) {
      _showConfirmation('$synchronized chamada(s) sincronizada(s)');
    }
    if (temporaryFailure && _pendingCount > 0) {
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 30), () {
        if (_isOnline) {
          unawaited(processQueue());
        }
      });
    }
    notifyListeners();
  }

  Future<void> refreshStatus() => _refreshCounts();

  Future<void> _refreshCounts() async {
    final items = await OfflineAttendanceStore.instance.pendingOperations();
    _pendingCount = items.length;
    _conflictCount = items.where((item) => item.state == 'conflict').length;
    notifyListeners();
  }

  void _showConfirmation(String text) {
    _confirmationTimer?.cancel();
    _retryTimer?.cancel();
    _confirmation = text;
    notifyListeners();
    _confirmationTimer = Timer(const Duration(seconds: 3), () {
      _confirmation = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _queueSubscription?.cancel();
    _confirmationTimer?.cancel();
    super.dispose();
  }
}
