import 'package:academyhub_mobile/services/app_update_service_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('version.json is always resolved from the site root', () {
    final uri = AppUpdateService.resolveVersionMetadataUri(
      Uri.parse(
        'https://academyhub-mobile.netlify.app/'
        'matricula-web/school-id?onlyMinors=true',
      ),
      123,
    );

    expect(
      uri.toString(),
      'https://academyhub-mobile.netlify.app/version.json?t=123',
    );
  });
}
