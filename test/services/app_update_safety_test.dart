import 'package:academyhub_mobile/services/app_update_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('critical operation blocks reload until its lease is finished', () {
    final safety = AppUpdateSafety.instance;
    final id = 'test-operation-${DateTime.now().microsecondsSinceEpoch}';
    expect(safety.canReload, isTrue);

    final lease = safety.beginCriticalOperation(id);
    expect(safety.canReload, isFalse);
    expect(safety.criticalOperationCount, greaterThanOrEqualTo(1));

    lease.finish();
    expect(safety.canReload, isTrue);
  });

  test('finishing a lease twice is safe and does not underflow state', () {
    final safety = AppUpdateSafety.instance;
    final id = 'test-idempotent-${DateTime.now().microsecondsSinceEpoch}';
    final lease = safety.beginCriticalOperation(id);

    lease.finish();
    lease.finish();

    expect(safety.canReload, isTrue);
  });
}
