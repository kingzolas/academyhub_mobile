import 'package:academyhub_mobile/services/app_update_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppBuildMetadata parse({String buildId = 'netlify-deploy-a-commit-a'}) {
    final value = AppBuildMetadata.tryParse(<String, dynamic>{
      'app': 'academyhub-mobile-web',
      'version': '1.5.7',
      'buildNumber': '1',
      'buildId': buildId,
      'commit': 'commit-a',
      'deployedAt': '2026-08-06T12:00:00Z',
    });
    expect(value, isNotNull);
    return value!;
  }

  group('AppBuildMetadata', () {
    test('reads a valid published build identifier', () {
      final metadata = parse();

      expect(metadata.buildId, 'netlify-deploy-a-commit-a');
      expect(metadata.version, '1.5.7');
    });

    test('rejects an invalid version.json payload', () {
      expect(
        AppBuildMetadata.tryParse(<String, dynamic>{
          'app': 'academyhub-mobile-web',
          'deployedAt': '2026-08-06T12:00:00Z',
        }),
        isNull,
      );
    });

    test('the same build does not request an update', () {
      expect(parse().differsFrom('netlify-deploy-a-commit-a'), isFalse);
    });

    test('a different build requests an update', () {
      expect(parse().differsFrom('netlify-deploy-old-commit-old'), isTrue);
    });

    test('a rollback still requests an update because its ID differs', () {
      final rollback = parse(buildId: 'netlify-rollback-deploy-old-commit');

      expect(rollback.differsFrom('netlify-newer-deploy-new-commit'), isTrue);
    });
  });
}
