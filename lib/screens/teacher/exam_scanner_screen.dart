// lib/screens/teacher/exam_scanner_screen.dart

import 'dart:typed_data';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/school_provider.dart';
import 'package:academyhub_mobile/services/exam_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'; // Necessário para o 'compute'
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img; // PACOTE DE RECORTE

enum ScannerState { scanningQR, takingPhoto, processing }

// 👇 Função TOP-LEVEL (Fora da classe) para rodar em Isolate e não travar o app
Uint8List processImageCrop(Map<String, dynamic> data) {
  final bytes = data['bytes'] as Uint8List;
  final screenW = data['screenW'] as double;
  final screenH = data['screenH'] as double;
  final boxW = data['boxW'] as double;
  final boxH = data['boxH'] as double;

  img.Image? decodedImage = img.decodeImage(bytes);
  if (decodedImage == null)
    return bytes; // Se falhar, manda a original por segurança

  // Corrige a rotação oculta que o iOS/Android salvam no EXIF da foto
  decodedImage = img.bakeOrientation(decodedImage);

  final imgW = decodedImage.width.toDouble();
  final imgH = decodedImage.height.toDouble();

  // Calcula a escala que a tela usou para cobrir os espaços vazios (BoxFit.cover matemático)
  double scale =
      (screenW / imgW) > (screenH / imgH) ? (screenW / imgW) : (screenH / imgH);

  final scaledImgW = imgW * scale;
  final scaledImgH = imgH * scale;

  // Calcula os espaços que vazaram para fora da tela
  final offsetX = (scaledImgW - screenW) / 2;
  final offsetY = (scaledImgH - screenH) / 2;

  // Posição da máscara verde desenhada na tela
  final maskLeft = (screenW - boxW) / 2;
  final maskTop = (screenH - boxH) / 2;

  // Converte a coordenada da tela para a coordenada real dos pixels da foto gigante
  final cropLeft = ((maskLeft + offsetX) / scale).toInt();
  final cropTop = ((maskTop + offsetY) / scale).toInt();
  final cropWidth = (boxW / scale).toInt();
  final cropHeight = (boxH / scale).toInt();

  // Travas de segurança para o corte não ultrapassar o limite da imagem
  final finalX = cropLeft.clamp(0, decodedImage.width - 1).toInt();
  final finalY = cropTop.clamp(0, decodedImage.height - 1).toInt();
  final finalW = cropWidth.clamp(1, decodedImage.width - finalX).toInt();
  final finalH = cropHeight.clamp(1, decodedImage.height - finalY).toInt();

  // Executa o recorte cirúrgico
  img.Image croppedImage = img.copyCrop(
    decodedImage,
    x: finalX,
    y: finalY,
    width: finalW,
    height: finalH,
  );

  // Devolve a imagem em formato JPG super otimizado
  return img.encodeJpg(croppedImage, quality: 90);
}

class ExamScannerScreen extends StatefulWidget {
  const ExamScannerScreen({super.key});

  @override
  State<ExamScannerScreen> createState() => _ExamScannerScreenState();
}

class _ExamScannerScreenState extends State<ExamScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  ScannerState _currentState = ScannerState.scanningQR;
  String _processingStatus = "";

  String? _scannedQrCodeUuid;
  Map<String, dynamic>? _scannedSheetData;

  final Color _primaryThemeColor = const Color(0xFFC8A2C8);

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initPhotoCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset
            .max, // Máxima qualidade para não perder detalhes do recorte
        enableAudio: false,
      );
      await _cameraController!.initialize();
    }
  }

  Future<void> _resetToQrMode() async {
    setState(() => _currentState = ScannerState.processing);
    await _cameraController?.dispose();
    _cameraController = null;

    if (mounted) {
      setState(() {
        _scannedQrCodeUuid = null;
        _scannedSheetData = null;
        _currentState = ScannerState.scanningQR;
      });
      _scannerController.start();
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _showLoadingDialog(String message) {
    if (!mounted) return;
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

      _showLoadingDialog("Buscando dados...");
      final sheetData = await ExamApiService()
          .verifySheetData(qrCodeUuid: qrCodeUuid, token: token!);

      setState(() => _processingStatus = "Preparando câmera...");
      await _initPhotoCamera();

      _hideLoadingDialog();

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
        await _resetToQrMode();
      }
    }
  }

  Future<void> _takePhotoAndSendToAI() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    setState(() => _currentState = ScannerState.processing);

    try {
      // 1. Dispara a foto inteira
      final XFile photo = await _cameraController!.takePicture();
      final Uint8List fullImageBytes = await photo.readAsBytes();

      _showLoadingDialog("Recortando imagem...");

      // 2. Extrai os tamanhos da tela atual para calcular a proporção do recorte
      final screenSize = MediaQuery.of(context).size;
      final boxW = screenSize.width * 0.90; // 90% da largura
      final boxH = boxW * 0.55; // Altura ideal para cobrir os quadrados pretos

      // 3. Envia para a Isolate para processar no fundo sem travar o celular
      final Uint8List croppedBytes = await compute(processImageCrop, {
        'bytes': fullImageBytes,
        'screenW': screenSize.width,
        'screenH': screenSize.height,
        'boxW': boxW,
        'boxH': boxH,
      });

      _hideLoadingDialog();
      _showLoadingDialog("Analisando gabarito com IA...");

      final token = Provider.of<AuthProvider>(context, listen: false).token;

      // 4. Envia apenas a tira recortada para a API Node/Python
      double? detectedGrade =
          await ExamApiService().processOmrImage(croppedBytes, token!);

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

  // --- Função responsável por tirar o achatamento da câmera ---
  Widget _buildUndistortedCameraPreview() {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _cameraController!.value.aspectRatio;

    // Ajusta a escala para sempre preencher a tela, como um BoxFit.cover
    if (scale < 1) scale = 1 / scale;

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  // Manteve as outras funções visuais, mas com as novas chamadas e medidas ajustadas
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
                                : () async {
                                    Navigator.pop(context);
                                    await _resetToQrMode();
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
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    'Nota salva com sucesso!'),
                                                backgroundColor:
                                                    _primaryThemeColor));

                                        await _resetToQrMode();
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
          if (_currentState == ScannerState.scanningQR)
            MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            )
          else if ((_currentState == ScannerState.takingPhoto ||
                  _currentState == ScannerState.processing) &&
              _cameraController != null &&
              _cameraController!.value.isInitialized)
            // Câmera Fotográfica sem achatamento
            _buildUndistortedCameraPreview()
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_currentState == ScannerState.scanningQR)
            _buildQrScannerOverlay()
          else if (_currentState == ScannerState.takingPhoto ||
              _currentState == ScannerState.processing)
            _buildPhotoCaptureOverlay(),
          Positioned(
            top: 50.h,
            left: 20.w,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(PhosphorIcons.arrow_left, color: Colors.white),
                onPressed: () async {
                  if (_currentState == ScannerState.takingPhoto) {
                    await _resetToQrMode();
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

  Widget _buildPhotoCaptureOverlay() {
    return LayoutBuilder(builder: (context, constraints) {
      // Formato perfeito para enquadrar os 4 quadrados pretos
      final boxWidth = constraints.maxWidth * 0.90;
      final boxHeight = boxWidth * 0.55;

      final horizontalPadding = (constraints.maxWidth - boxWidth) / 2;
      final verticalPadding = (constraints.maxHeight - boxHeight) / 2;

      return Stack(
        children: [
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
                  child: Text(
                      "Encaixe os quadrados pretos dentro da linha verde",
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
