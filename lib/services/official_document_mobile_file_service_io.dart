import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
    final file = await _writeTemporaryPdf(bytes: bytes, fileName: fileName);
    final result = await OpenFilex.open(file.path, type: mimeType);

    if (result.type == ResultType.done) {
      return const OfficialDocumentFileActionResult(
        success: true,
        message: 'Documento aberto.',
      );
    }

    return OfficialDocumentFileActionResult(
      success: false,
      message: result.message.isNotEmpty
          ? result.message
          : 'Não foi possível abrir o PDF neste dispositivo.',
    );
  }

  Future<OfficialDocumentFileActionResult> shareOrSavePdf({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/pdf',
  }) async {
    final file = await _writeTemporaryPdf(bytes: bytes, fileName: fileName);
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          name: _safePdfName(fileName),
          mimeType: mimeType,
        ),
      ],
      text: 'Documento oficial disponibilizado pela escola.',
    );

    return const OfficialDocumentFileActionResult(
      success: true,
      message: 'Escolha onde salvar ou compartilhar o PDF.',
    );
  }

  Future<File> _writeTemporaryPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final directory = await getTemporaryDirectory();
    final folder = Directory(
        '${directory.path}${Platform.pathSeparator}academyhub-documentos');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File(
        '${folder.path}${Platform.pathSeparator}${_safePdfName(fileName)}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
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
