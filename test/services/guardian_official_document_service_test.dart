import 'package:academyhub_mobile/model/guardian_official_document_model.dart';
import 'package:academyhub_mobile/services/guardian_official_document_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guardian document catalog uses local defaults without a staff fallback',
      () async {
    final service = GuardianOfficialDocumentService();

    final catalog = await service.getCatalog(token: 'guardian-token');

    expect(catalog, same(GuardianOfficialDocumentCatalogItem.defaults));
  });
}
