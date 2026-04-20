import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

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
    final url = _createObjectUrl(bytes, mimeType);
    html.window.open(url, '_blank');

    return const OfficialDocumentFileActionResult(
      success: true,
      message: 'Documento aberto em uma nova aba.',
    );
  }

  Future<OfficialDocumentFileActionResult> shareOrSavePdf({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/pdf',
  }) async {
    final url = _createObjectUrl(bytes, mimeType);
    final anchor = html.AnchorElement(href: url)
      ..download = _safePdfName(fileName)
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    return const OfficialDocumentFileActionResult(
      success: true,
      message: 'Download iniciado no navegador.',
    );
  }

  String _createObjectUrl(Uint8List bytes, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    return html.Url.createObjectUrlFromBlob(blob);
  }

  String _safePdfName(String value) {
    final normalized =
        value.trim().isEmpty ? 'documento-oficial.pdf' : value.trim();
    final sanitized = normalized.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
    return sanitized.toLowerCase().endsWith('.pdf')
        ? sanitized
        : '$sanitized.pdf';
  }
}
