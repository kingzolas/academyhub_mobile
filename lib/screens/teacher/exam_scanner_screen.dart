// lib/screens/teacher/exam_scanner_screen.dart

import 'dart:typed_data';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/school_provider.dart';
import 'package:academyhub_mobile/services/exam_service.dart';
import 'package:camera/camera.dart'; // PACOTE NOVO
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

// Definindo os estados possíveis da tela
enum ScannerState { scanningQR, takingPhoto, processing }

class ExamScannerScreen extends StatefulWidget {
  const ExamScannerScreen({super.key});

  @override
  State<ExamScannerScreen> createState() => _ExamScannerScreenState();
}

class _ExamScannerScreenState extends State<ExamScannerScreen> {
  // Controle do Scanner de QR Code
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  // Controle da Câmera Fotográfica (Para a parte do enquadramento)
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  ScannerState _currentState = ScannerState.scanningQR;
  String _processingStatus = "";

  // Dados salvos após ler o QR Code
  String? _scannedQrCodeUuid;
  Map<String, dynamic>? _scannedSheetData;

  final Color _primaryThemeColor = const Color(0xFFC8A2C8);

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  // Prepara a câmera fotográfica em segundo plano
  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.max, // Qualidade máxima para a IA ler as bolinhas
        enableAudio: false,
      );
      await _cameraController!.initialize();
      // Oculta a câmera do Flutter enquanto estamos no modo MobileScanner
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

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

  // Passo 1: O Scanner leu o QR Code
  void _onDetect(BarcodeCapture capture) async {
    if (_currentState != ScannerState.scanningQR) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrCodeUuid = barcodes.first.rawValue;
    if (qrCodeUuid == null || qrCodeUuid.isEmpty) return;

    setState(() => _currentState = ScannerState.processing);

    await _scannerController.stop();

    if (!mounted) return;

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;

      _showLoadingDialog("Buscando dados do aluno...");
      final sheetData = await ExamApiService()
          .verifySheetData(qrCodeUuid: qrCodeUuid, token: token!);
      _hideLoadingDialog();

      // Muda a tela: Sai o MobileScanner, entra a Câmera Fotográfica com Máscara
      setState(() {
        _scannedQrCodeUuid = qrCodeUuid;
        _scannedSheetData = sheetData;
        _currentState = ScannerState.takingPhoto;
      });
    } catch (e) {
      _hideLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
        setState(() => _currentState = ScannerState.scanningQR);
        _scannerController.start();
      }
    }
  }

  // Passo 2: O Professor toca no botão para tirar a foto enquadrada
  Future<void> _takePhotoAndSendToAI() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    setState(() => _currentState = ScannerState.processing);

    try {
      // Tira a foto
      final XFile photo = await _cameraController!.takePicture();
      final Uint8List imageBytes = await photo.readAsBytes();

      _showLoadingDialog("Analisando gabarito com IA...");

      final token = Provider.of<AuthProvider>(context, listen: false).token;

      // Envia os bytes reais para a API (que enviará para o Python)
      double? detectedGrade =
          await ExamApiService().processOmrImage(imageBytes, token!);

      _hideLoadingDialog();

      if (mounted) {
        await _showGradeConfirmationModal(
            _scannedQrCodeUuid!, _scannedSheetData!,
            autoDetectedGrade: detectedGrade);
      }
    } catch (e) {
      _hideLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro na leitura: $e'), backgroundColor: Colors.red));
        setState(() => _currentState = ScannerState.takingPhoto);
      }
    }
  }

  // Modal final de Confirmação (Mantido como você já fez)
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
                            onPressed: isSaving
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    // Se o usuário cancelar, volta para tentar tirar a foto de novo
                                    setState(() => _currentState =
                                        ScannerState.takingPhoto);
                                  },
                            style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r))),
                            child: const Text("Tentar de novo"),
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
                                        Navigator.pop(context); // Fecha o modal
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    'Nota salva com sucesso!'),
                                                backgroundColor:
                                                    _primaryThemeColor));

                                        // Reinicia o fluxo do zero para a próxima prova!
                                        setState(() {
                                          _currentState =
                                              ScannerState.scanningQR;
                                          _scannedQrCodeUuid = null;
                                          _scannedSheetData = null;
                                        });
                                        _scannerController.start();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1º CAMADA: Exibe a Câmera Correta dependendo do estado
          if (_currentState == ScannerState.scanningQR)
            MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            )
          else if ((_currentState == ScannerState.takingPhoto ||
                  _currentState == ScannerState.processing) &&
              _cameraController != null &&
              _cameraController!.value.isInitialized)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 2º CAMADA: A Máscara/Overlay por cima do vídeo
          if (_currentState == ScannerState.scanningQR)
            _buildQrScannerOverlay()
          else if (_currentState == ScannerState.takingPhoto ||
              _currentState == ScannerState.processing)
            _buildPhotoCaptureOverlay(),

          // 3º CAMADA: Botão de Voltar no topo
          Positioned(
            top: 50.h,
            left: 20.w,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(PhosphorIcons.arrow_left, color: Colors.white),
                onPressed: () {
                  if (_currentState == ScannerState.takingPhoto) {
                    // Se desistiu de tirar foto, volta para ler QR
                    setState(() => _currentState = ScannerState.scanningQR);
                    _scannerController.start();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // OVERLAY 1: O quadrado padrão para ler o QR Code
  Widget _buildQrScannerOverlay() {
    return LayoutBuilder(builder: (context, constraints) {
      final scanWindowSize = constraints.maxWidth * 0.7;
      final horizontalPadding = (constraints.maxWidth - scanWindowSize) / 2;
      final verticalPadding = (constraints.maxHeight - scanWindowSize) / 2;

      return Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: Colors.black.withOpacity(0.5),
                    width: verticalPadding),
                bottom: BorderSide(
                    color: Colors.black.withOpacity(0.5),
                    width: verticalPadding),
                left: BorderSide(
                    color: Colors.black.withOpacity(0.5),
                    width: horizontalPadding),
                right: BorderSide(
                    color: Colors.black.withOpacity(0.5),
                    width: horizontalPadding),
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
          ),
          Positioned(
            bottom: 100.h,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20.r)),
                child: Text("1º Passo: Aponte para o QR Code",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      );
    });
  }

  // OVERLAY 2: O Retângulo para guiar o enquadramento do gabarito das notas
  Widget _buildPhotoCaptureOverlay() {
    return LayoutBuilder(builder: (context, constraints) {
      // Proporção exata da caixa de notas (Mais larga do que alta)
      final boxWidth = constraints.maxWidth * 0.85;
      final boxHeight = boxWidth * 0.4; // Proporção horizontal

      final horizontalPadding = (constraints.maxWidth - boxWidth) / 2;
      final verticalPadding = (constraints.maxHeight - boxHeight) / 2;

      return Stack(
        children: [
          // Tela semi-transparente fora do retângulo
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: Colors.black.withOpacity(0.7),
                    width: verticalPadding),
                bottom: BorderSide(
                    color: Colors.black.withOpacity(0.7),
                    width: verticalPadding),
                left: BorderSide(
                    color: Colors.black.withOpacity(0.7),
                    width: horizontalPadding),
                right: BorderSide(
                    color: Colors.black.withOpacity(0.7),
                    width: horizontalPadding),
              ),
            ),
            child: Center(
              child: Container(
                height: boxHeight,
                width: boxWidth,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 3),
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
          // Informação visual no topo
          Positioned(
            top: 120.h,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text("Aluno Identificado:",
                    style: TextStyle(color: Colors.grey[300], fontSize: 14.sp)),
                Text(_scannedSheetData?['studentName']?.toUpperCase() ?? '',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          // Instrução e Botão de Captura embaixo
          Positioned(
            bottom: 80.h,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                  decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16.r)),
                  child: Text("Enquadre o quadro de notas e fotografe",
                      style: TextStyle(color: Colors.white, fontSize: 12.sp)),
                ),
                SizedBox(height: 20.h),
                GestureDetector(
                  onTap: _takePhotoAndSendToAI,
                  child: Container(
                    height: 70.w,
                    width: 70.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[400]!, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        height: 55.w,
                        width: 55.w,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      );
    });
  }
}
