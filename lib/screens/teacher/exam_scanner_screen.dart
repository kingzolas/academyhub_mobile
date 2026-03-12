// lib/screens/teacher/exam_scanner_screen.dart

import 'dart:typed_data';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/school_provider.dart';
import 'package:academyhub_mobile/services/exam_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ExamScannerScreen extends StatefulWidget {
  const ExamScannerScreen({super.key});

  @override
  State<ExamScannerScreen> createState() => _ExamScannerScreenState();
}

class _ExamScannerScreenState extends State<ExamScannerScreen> {
  // 👇 Retiramos o returnImage: true, pois não usaremos o frame ruim do vídeo
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    returnImage: false,
  );

  final ImagePicker _imagePicker = ImagePicker();

  bool _isProcessing = false;
  String _processingStatus = "";

  // Cor principal do tema atualizada
  final Color _primaryThemeColor = const Color(0xFFC8A2C8);

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // 👇 Função auxiliar para gerenciar os modais de carregamento sem repetir código
  void _showLoadingDialog(String message) {
    setState(() => _processingStatus = message);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Center(
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16.r)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _primaryThemeColor),
                SizedBox(height: 20.h),
                Text(_processingStatus,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _hideLoadingDialog() {
    if (mounted) Navigator.pop(context);
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrCodeUuid = barcodes.first.rawValue;
    if (qrCodeUuid == null || qrCodeUuid.isEmpty) return;

    setState(() => _isProcessing = true);

    // 1. Pausa o scanner imediatamente
    await _scannerController.stop();

    if (!mounted) return;

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;

      // 2. Busca os dados do Aluno
      _showLoadingDialog("Buscando dados do aluno...");
      final sheetData = await ExamApiService()
          .verifySheetData(qrCodeUuid: qrCodeUuid, token: token!);
      _hideLoadingDialog();

      // 3. Aciona a câmera nativa (ImagePicker) para a foto de alta qualidade
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 100, // Garantindo a máxima qualidade para o Python
      );

      // Se o professor cancelou a câmera, aborta e reinicia o fluxo
      if (photo == null) {
        setState(() => _isProcessing = false);
        _scannerController.start();
        return;
      }

      final Uint8List imageBytes = await photo.readAsBytes();
      double? detectedGrade;

      debugPrint(
          "📷 Foto da prova capturada! Tamanho: ${imageBytes.lengthInBytes} bytes.");

      // 4. Envia a foto real e nítida para a IA
      _showLoadingDialog("Lendo gabarito com Inteligência Artificial...");
      detectedGrade = await ExamApiService().processOmrImage(imageBytes, token);
      debugPrint("🧠 IA respondeu: $detectedGrade");
      _hideLoadingDialog();

      // 5. Exibe o modal de confirmação
      if (mounted) {
        await _showGradeConfirmationModal(qrCodeUuid, sheetData,
            autoDetectedGrade: detectedGrade);
      }
    } catch (e) {
      _hideLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
        setState(() => _isProcessing = false);
        _scannerController.start();
      }
    }
  }

  Future<void> _showGradeConfirmationModal(
      String qrCodeUuid, Map<String, dynamic> sheetData,
      {double? autoDetectedGrade}) async {
    final TextEditingController gradeController = TextEditingController(
      text: autoDetectedGrade != null ? autoDetectedGrade.toString() : '',
    );
    bool isSaving = false;

    final schoolName =
        Provider.of<SchoolProvider>(context, listen: false).school?.name ??
            'Academy Hub';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24.r)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 40.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2)))),
                    SizedBox(height: 20.h),
                    Row(
                      children: [
                        Icon(PhosphorIcons.user_focus,
                            size: 40.sp, color: _primaryThemeColor),
                        SizedBox(width: 15.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sheetData['studentName']?.toUpperCase() ??
                                    'ALUNO DESCONHECIDO',
                                style: GoogleFonts.saira(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                "${sheetData['subjectName']} • ${sheetData['className']}",
                                style: TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp),
                              ),
                              Text(
                                "${sheetData['examTitle']} • $schoolName",
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12.sp),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 25.h),
                    if (autoDetectedGrade != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                                color: _primaryThemeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20.r)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(PhosphorIcons.magic_wand_fill,
                                    color: _primaryThemeColor, size: 14.sp),
                                SizedBox(width: 6.w),
                                Text("Nota lida pela Inteligência Artificial",
                                    style: TextStyle(
                                        color: _primaryThemeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.sp)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    TextField(
                      controller: gradeController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: autoDetectedGrade == null,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 48.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: "0.0",
                        hintStyle: TextStyle(color: Colors.grey[300]),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.grey[100],
                        contentPadding: EdgeInsets.symmetric(vertical: 20.h),
                      ),
                    ),
                    SizedBox(height: 30.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isSaving ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r))),
                            child: const Text("Cancelar"),
                          ),
                        ),
                        SizedBox(width: 15.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final String input = gradeController.text
                                        .replaceAll(',', '.');
                                    final double? finalGrade =
                                        double.tryParse(input);

                                    if (finalGrade == null ||
                                        finalGrade < 0 ||
                                        finalGrade > 10) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Digite uma nota válida entre 0 e 10.'),
                                              backgroundColor: Colors.orange));
                                      return;
                                    }

                                    setModalState(() => isSaving = true);

                                    try {
                                      final token = Provider.of<AuthProvider>(
                                              context,
                                              listen: false)
                                          .token;

                                      await ExamApiService().scanAndGradeSheet(
                                        qrCodeUuid: qrCodeUuid,
                                        grade: finalGrade,
                                        token: token!,
                                      );

                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    'Nota de ${sheetData['studentName']} salva com sucesso!'),
                                                backgroundColor:
                                                    _primaryThemeColor));
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text('Erro: $e'),
                                              backgroundColor: Colors.red));
                                      setModalState(() => isSaving = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r)),
                            ),
                            child: isSaving
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.w,
                                    child: const CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text("Confirmar Nota",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    setState(() => _isProcessing = false);
    _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIcons.camera_slash,
                          color: Colors.red, size: 50.sp),
                      SizedBox(height: 15.h),
                      Text(
                          "Erro: ${error.errorDetails?.message ?? error.errorCode}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              );
            },
          ),
          _buildScannerOverlay(),
          Positioned(
            top: 50.h,
            left: 20.w,
            right: 20.w,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(PhosphorIcons.arrow_left,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.all(Radius.circular(20))),
                  child: TextButton.icon(
                    icon: const Icon(PhosphorIcons.arrows_clockwise,
                        color: Colors.white, size: 16),
                    label: const Text("Reiniciar Câmera",
                        style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      _scannerController.stop();
                      Future.delayed(const Duration(milliseconds: 500),
                          () => _scannerController.start());
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 100.h,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 50.w),
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                  decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20.r)),
                  child: Text("Aponte para o QR Code da prova",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return LayoutBuilder(builder: (context, constraints) {
      final scanWindowSize = constraints.maxWidth * 0.7;
      final horizontalPadding = (constraints.maxWidth - scanWindowSize) / 2;
      final verticalPadding = (constraints.maxHeight - scanWindowSize) / 2;

      return Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
                color: Colors.black.withOpacity(0.5), width: verticalPadding),
            bottom: BorderSide(
                color: Colors.black.withOpacity(0.5), width: verticalPadding),
            left: BorderSide(
                color: Colors.black.withOpacity(0.5), width: horizontalPadding),
            right: BorderSide(
                color: Colors.black.withOpacity(0.5), width: horizontalPadding),
          ),
        ),
        child: Center(
          child: Container(
            height: scanWindowSize,
            width: scanWindowSize,
            decoration: BoxDecoration(
              border: Border.all(
                  color: _primaryThemeColor.withOpacity(0.8), width: 3),
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
        ),
      );
    });
  }
}
