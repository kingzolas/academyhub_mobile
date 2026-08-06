import 'package:flutter/foundation.dart';

/// Shared opt-in guard for screens that own a non-persisted critical operation.
///
/// The update service never reloads automatically. Screens can use this guard to
/// postpone a user-requested reload until their save operation or draft flush has
/// completed, without exposing storage implementation details to the updater.
class AppUpdateSafety extends ChangeNotifier {
  AppUpdateSafety._();

  static final AppUpdateSafety instance = AppUpdateSafety._();

  final Set<String> _criticalOperationIds = <String>{};

  bool get canReload => _criticalOperationIds.isEmpty;
  int get criticalOperationCount => _criticalOperationIds.length;

  AppUpdateSafetyLease beginCriticalOperation(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Operation id cannot be empty.');
    }
    final changed = _criticalOperationIds.add(normalized);
    if (changed) notifyListeners();
    return AppUpdateSafetyLease._(this, normalized);
  }

  void _finish(String id) {
    if (_criticalOperationIds.remove(id)) notifyListeners();
  }
}

class AppUpdateSafetyLease {
  AppUpdateSafetyLease._(this._owner, this._id);

  final AppUpdateSafety _owner;
  final String _id;
  bool _finished = false;

  void finish() {
    if (_finished) return;
    _finished = true;
    _owner._finish(_id);
  }
}
