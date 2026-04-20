import 'dart:typed_data';

class OfficialDocumentFileActionResult {
  final bool success;
  final String message;

  const OfficialDocumentFileActionResult({
    required this.success,
    required this.message,
  });
}

class OfficialDocumentMobileFileService {
  Future<OfficialDocumentFileActionResult> openPdf({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/pdf',
  }) async {
    return const OfficialDocumentFileActionResult(
      success: false,
      message: 'Abertura de PDF não suportada nesta plataforma.',
    );
  }

  Future<OfficialDocumentFileActionResult> shareOrSavePdf({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/pdf',
  }) async {
    return const OfficialDocumentFileActionResult(
      success: false,
      message: 'Compartilhamento de PDF não suportado nesta plataforma.',
    );
  }
}
