// lib/screens/teacher/exam_scanner_screen.dart

import 'dart:typed_data';

import 'package:academyhub_mobile/model/exam_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/school_provider.dart';
import 'package:academyhub_mobile/services/exam_service.dart';
// 👇 Import do pop-up inteligente!
import 'package:academyhub_mobile/widgets/scanner_operation_dialog.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

enum ScannerState { scanningQR, takingPhoto, processing }

Uint8List processImageCrop(Map<String, dynamic> data) {
  final bytes = data['bytes'] as Uint8List;
  final screenW = data['screenW'] as double;
  final screenH = data['screenH'] as double;
  final boxW = data['boxW'] as double;
  final boxH = data['boxH'] as double;

  img.Image? decodedImage = img.decodeImage(bytes);
  if (decodedImage == null) return bytes;

  decodedImage = img.bakeOrientation(decodedImage);

  final imgW = decodedImage.width.toDouble();
  final imgH = decodedImage.height.toDouble();

  double scale =
      (screenW / imgW) > (screenH / imgH) ? (screenW / imgW) : (screenH / imgH);

  final scaledImgW = imgW * scale;
  final scaledImgH = imgH * scale;

  final offsetX = (scaledImgW - screenW) / 2;
  final offsetY = (scaledImgH - screenH) / 2;

  final maskLeft = (screenW - boxW) / 2;
  final maskTop = (screenH - boxH) / 2;

  final cropLeft = ((maskLeft + offsetX) / scale).toInt();
  final cropTop = ((maskTop + offsetY) / scale).toInt();
  final cropWidth = (boxW / scale).toInt();
  final cropHeight = (boxH / scale).toInt();

  final finalX = cropLeft.clamp(0, decodedImage.width - 1).toInt();
  final finalY = cropTop.clamp(0, decodedImage.height - 1).toInt();
  final finalW = cropWidth.clamp(1, decodedImage.width - finalX).toInt();
  final finalH = cropHeight.clamp(1, decodedImage.height - finalY).toInt();

  img.Image croppedImage = img.copyCrop(
    decodedImage,
    x: finalX,
    y: finalY,
    width: finalW,
    height: finalH,
  );

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
    autoStart: false,
  );

  final ImagePicker _imagePicker = ImagePicker();

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  ScannerState _currentState = ScannerState.scanningQR;

  String? _scannedQrCodeUuid;
  Map<String, dynamic>? _scannedSheetData;

  final Color _primaryThemeColor = const Color(0xFFC8A2C8);

  bool _isCapturingPhoto = false;
  Uint8List? _webPickedPreviewBytes;

  bool get _isWebCameraFlow => kIsWeb;

  @override
  void initState() {
    super.initState();
    _startScannerSafely();
  }

  Future<void> _startScannerSafely() async {
    try {
      await _scannerController.start();
    } catch (e) {
      debugPrint("Erro ao iniciar o scanner de QR: $e");
    }
  }

  Future<void> _initPhotoCamera() async {
    if (kIsWeb) return;

    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      CameraDescription selectedCamera = _cameras!.first;

      try {
        selectedCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
      } catch (_) {}

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
    }
  }

  Future<void> _resetToQrMode() async {
    setState(() => _currentState = ScannerState.processing);

    await _cameraController?.dispose();
    _cameraController = null;
    _webPickedPreviewBytes = null;
    _isCapturingPhoto = false;

    if (mounted) {
      setState(() {
        _scannedQrCodeUuid = null;
        _scannedSheetData = null;
        _currentState = ScannerState.scanningQR;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startScannerSafely();
      });
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // 👇 LÓGICA ATUALIZADA DO QR CODE COM O NOVO POP-UP
  void _onDetect(BarcodeCapture capture) async {
    if (_currentState != ScannerState.scanningQR) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrCodeUuid = barcodes.first.rawValue;
    if (qrCodeUuid == null || qrCodeUuid.isEmpty) return;

    setState(() => _currentState = ScannerState.processing);
    await _scannerController.stop();

    if (!mounted) return;
    final token = Provider.of<AuthProvider>(context, listen: false).token;

    final sheetData = await showScannerOperationDialog<Map<String, dynamic>>(
      context: context,
      loadingTitle: 'Identificando...',
      loadingMessage: 'Buscando informações do aluno.',
      loadingDetail: 'Sincronizando com a nuvem...',
      successTitle: 'Aluno Encontrado!',
      successMessage: 'Preparando a câmera de correção.',
      successVisibleDuration: const Duration(milliseconds: 900),
      operation: () async {
        final data = await ExamApiService()
            .verifySheetData(qrCodeUuid: qrCodeUuid, token: token!);
        if (!kIsWeb) await _initPhotoCamera();
        return data;
      },
    );

    if (sheetData == null) {
      // Usuário cancelou ou deu erro
      await _resetToQrMode();
      return;
    }

    setState(() {
      _scannedQrCodeUuid = qrCodeUuid;
      _scannedSheetData = sheetData;
      _currentState = ScannerState.takingPhoto;
    });
  }

  // 👇 LÓGICA ATUALIZADA DO ENVIO DA FOTO COM O NOVO POP-UP
  Future<void> _takePhotoAndSendToAI() async {
    if (_isCapturingPhoto) return;

    _isCapturingPhoto = true;
    setState(() => _currentState = ScannerState.processing);

    Uint8List fullImageBytes;

    if (_isWebCameraFlow) {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 92,
      );

      if (pickedFile == null) {
        setState(() => _currentState = ScannerState.takingPhoto);
        _isCapturingPhoto = false;
        return;
      }
      fullImageBytes = await pickedFile.readAsBytes();
      _webPickedPreviewBytes = fullImageBytes;
    } else {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        _isCapturingPhoto = false;
        setState(() => _currentState = ScannerState.takingPhoto);
        return;
      }
      final XFile photo = await _cameraController!.takePicture();
      fullImageBytes = await photo.readAsBytes();
    }

    final screenSize = MediaQuery.of(context).size;
    final isBubbleSheet =
        _scannedSheetData?['correctionType'] == 'BUBBLE_SHEET';
    final boxW =
        isBubbleSheet ? screenSize.width * 0.85 : screenSize.width * 0.90;
    final boxH = isBubbleSheet ? boxW * 1.05 : boxW * 0.55;
    final token = Provider.of<AuthProvider>(context, listen: false).token;

    final studentName = _scannedSheetData?['studentName']?.toUpperCase() ??
        'ALUNO DESCONHECIDO';

    final aiResult = await showScannerOperationDialog<Map<String, dynamic>>(
      context: context,
      loadingTitle: 'Analisando Prova',
      loadingMessage: 'A Inteligência Artificial está calculando a nota...',
      loadingDetail: 'Aluno(a): $studentName',
      successTitle: 'Correção Concluída!',
      successMessage: 'O resultado está pronto para validação.',
      operation: () async {
        // 1. Recorta a imagem
        final Uint8List croppedBytes = await compute(processImageCrop, {
          'bytes': fullImageBytes,
          'screenW': screenSize.width,
          'screenH': screenSize.height,
          'boxW': boxW,
          'boxH': boxH,
        });

        // 2. Envia para a IA
        return await ExamApiService().processOmrImage(
          imageBytes: croppedBytes,
          token: token!,
          correctionType: isBubbleSheet ? 'BUBBLE_SHEET' : 'DIRECT_GRADE',
          examId: _scannedSheetData?['examId'],
        );
      },
    );

    _isCapturingPhoto = false;

    if (aiResult != null && mounted) {
      final rawGrade = aiResult['grade'];
      double? detectedGrade;
      if (rawGrade != null) {
        detectedGrade = (rawGrade as num).toDouble();
      }

      List<dynamic>? details;
      if (aiResult['correctionDetails'] != null) {
        details = aiResult['correctionDetails'] as List<dynamic>;
      }

      await _showGradeConfirmationModal(
        _scannedQrCodeUuid!,
        _scannedSheetData!,
        autoDetectedGrade: detectedGrade,
        correctionDetails: details,
      );
    } else {
      if (mounted) setState(() => _currentState = ScannerState.takingPhoto);
    }
  }

  // 👇 LÓGICA ATUALIZADA DA GALERIA COM O NOVO POP-UP
  Future<void> _pickPhotoFromGalleryFallback() async {
    if (_isCapturingPhoto) return;

    _isCapturingPhoto = true;
    setState(() => _currentState = ScannerState.processing);

    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );

    if (pickedFile == null) {
      setState(() => _currentState = ScannerState.takingPhoto);
      _isCapturingPhoto = false;
      return;
    }

    final Uint8List fullImageBytes = await pickedFile.readAsBytes();
    _webPickedPreviewBytes = fullImageBytes;

    final screenSize = MediaQuery.of(context).size;
    final isBubbleSheet =
        _scannedSheetData?['correctionType'] == 'BUBBLE_SHEET';
    final boxW =
        isBubbleSheet ? screenSize.width * 0.85 : screenSize.width * 0.90;
    final boxH = isBubbleSheet ? boxW * 1.05 : boxW * 0.55;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final studentName = _scannedSheetData?['studentName']?.toUpperCase() ??
        'ALUNO DESCONHECIDO';

    final aiResult = await showScannerOperationDialog<Map<String, dynamic>>(
      context: context,
      loadingTitle: 'Analisando Prova',
      loadingMessage: 'A Inteligência Artificial está calculando a nota...',
      loadingDetail: 'Aluno(a): $studentName',
      successTitle: 'Correção Concluída!',
      successMessage: 'O resultado está pronto para validação.',
      operation: () async {
        final Uint8List croppedBytes = await compute(processImageCrop, {
          'bytes': fullImageBytes,
          'screenW': screenSize.width,
          'screenH': screenSize.height,
          'boxW': boxW,
          'boxH': boxH,
        });

        return await ExamApiService().processOmrImage(
          imageBytes: croppedBytes,
          token: token!,
          correctionType: isBubbleSheet ? 'BUBBLE_SHEET' : 'DIRECT_GRADE',
          examId: _scannedSheetData?['examId'],
        );
      },
    );

    _isCapturingPhoto = false;

    if (aiResult != null && mounted) {
      final rawGrade = aiResult['grade'];
      double? detectedGrade;
      if (rawGrade != null) {
        detectedGrade = (rawGrade as num).toDouble();
      }

      List<dynamic>? details;
      if (aiResult['correctionDetails'] != null) {
        details = aiResult['correctionDetails'] as List<dynamic>;
      }

      await _showGradeConfirmationModal(
        _scannedQrCodeUuid!,
        _scannedSheetData!,
        autoDetectedGrade: detectedGrade,
        correctionDetails: details,
      );
    } else {
      if (mounted) setState(() => _currentState = ScannerState.takingPhoto);
    }
  }

  Widget _buildUndistortedCameraPreview() {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _cameraController!.value.aspectRatio;

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

  Widget _buildWebCapturePlaceholder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_webPickedPreviewBytes != null)
          Image.memory(
            _webPickedPreviewBytes!,
            fit: BoxFit.cover,
          )
        else
          Container(
            color: Colors.black,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIcons.camera,
                      color: Colors.white,
                      size: 60.sp,
                    ),
                    SizedBox(height: 18.h),
                    Text(
                      "Captura via navegador",
                      style: GoogleFonts.saira(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      "No iPhone pela web, vamos usar a câmera nativa do navegador para tirar a foto do gabarito com mais compatibilidade.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14.sp,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<double?> _showGradeConfirmationModal(
    String qrCodeUuid,
    Map<String, dynamic> sheetData, {
    double? autoDetectedGrade,
    List<dynamic>? correctionDetails,
    bool fromManualMode = false,
  }) async {
    final TextEditingController gradeController = TextEditingController(
      text:
          autoDetectedGrade != null ? autoDetectedGrade.toStringAsFixed(1) : '',
    );
    bool isSaving = false;
    double? finalReturnedGrade;

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
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24.r)),
                ),
                child: SingleChildScrollView(
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
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Row(
                        children: [
                          Icon(
                            PhosphorIcons.user_focus,
                            size: 40.sp,
                            color: _primaryThemeColor,
                          ),
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
                                    height: 1.1,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  "${sheetData['subjectName']} • ${sheetData['className']}",
                                  style: TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                  ),
                                ),
                                Text(
                                  "${sheetData['examTitle']} • $schoolName",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12.sp,
                                  ),
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
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: _primaryThemeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    PhosphorIcons.magic_wand_fill,
                                    color: _primaryThemeColor,
                                    size: 14.sp,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    "Nota calculada pela IA",
                                    style: TextStyle(
                                      color: _primaryThemeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (fromManualMode)
                        Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: Center(
                            child: Text(
                              "Lançamento Manual",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ),
                      TextField(
                        controller: gradeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        autofocus: autoDetectedGrade == null,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 48.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: "0.0",
                          hintStyle: TextStyle(color: Colors.grey[300]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.grey[100],
                          contentPadding: EdgeInsets.symmetric(vertical: 20.h),
                        ),
                      ),
                      if (correctionDetails != null &&
                          correctionDetails.isNotEmpty) ...[
                        SizedBox(height: 15.h),
                        Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              "Detalhes da Correção Automática",
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                            iconColor: isDark ? Colors.white : Colors.black,
                            collapsedIconColor:
                                isDark ? Colors.grey[400] : Colors.grey[600],
                            children: [
                              Container(
                                constraints: BoxConstraints(maxHeight: 250.h),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.grey[800]!
                                        : Colors.grey[300]!,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: correctionDetails.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                  ),
                                  itemBuilder: (context, index) {
                                    final detail = correctionDetails[index];
                                    final isCorrect =
                                        detail['isCorrect'] == true;
                                    final marked = detail['studentMarked'];
                                    final correctAns = detail['correctAnswer'];

                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        isCorrect
                                            ? PhosphorIcons.check_circle_fill
                                            : PhosphorIcons.x_circle_fill,
                                        color: isCorrect
                                            ? Colors.green
                                            : Colors.red,
                                        size: 20.sp,
                                      ),
                                      title: Text(
                                        'Questão ${detail['questionNumber']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      subtitle: Text(
                                        marked == null
                                            ? 'Em branco'
                                            : (isCorrect
                                                ? 'Acertou (Marcou $marked)'
                                                : 'Errou (Marcou $marked, era $correctAns)'),
                                        style: TextStyle(
                                          color: isCorrect
                                              ? Colors.green
                                              : Colors.red,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      trailing: Text(
                                        '+${detail['earnedPoints']} pts',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 30.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      Navigator.pop(context);
                                      if (!fromManualMode) {
                                        await _resetToQrMode();
                                      }
                                    },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
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
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Digite uma nota válida entre 0 e 10.',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                        return;
                                      }

                                      setModalState(() => isSaving = true);

                                      try {
                                        final token = Provider.of<AuthProvider>(
                                          context,
                                          listen: false,
                                        ).token;

                                        await ExamApiService()
                                            .scanAndGradeSheet(
                                          qrCodeUuid: qrCodeUuid,
                                          grade: finalGrade,
                                          token: token!,
                                        );

                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Nota salva com sucesso!',
                                              ),
                                              backgroundColor:
                                                  _primaryThemeColor,
                                            ),
                                          );

                                          if (fromManualMode) {
                                            finalReturnedGrade = finalGrade;
                                          } else {
                                            await _resetToQrMode();
                                          }
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Erro: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        setModalState(() => isSaving = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: isSaving
                                  ? SizedBox(
                                      width: 20.w,
                                      height: 20.w,
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Confirmar",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return finalReturnedGrade;
  }

  Future<void> _openManualEntryFlow() async {
    await _scannerController.stop();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualEntrySheet(
        openGradeModal: _showGradeConfirmationModal,
      ),
    );

    if (_currentState == ScannerState.scanningQR && mounted) {
      _startScannerSafely();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showNativeCameraPreview = !kIsWeb &&
        (_currentState == ScannerState.takingPhoto ||
            _currentState == ScannerState.processing) &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    final showWebCaptureStage = kIsWeb &&
        (_currentState == ScannerState.takingPhoto ||
            _currentState == ScannerState.processing);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_currentState == ScannerState.scanningQR)
            MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            )
          else if (showNativeCameraPreview)
            _buildUndistortedCameraPreview()
          else if (showWebCaptureStage)
            _buildWebCapturePlaceholder()
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
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
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  PhosphorIcons.arrow_left,
                  color: Colors.white,
                ),
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
          if (_currentState == ScannerState.scanningQR)
            Positioned(
              top: 50.h,
              right: 20.w,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: TextButton.icon(
                  icon: const Icon(
                    PhosphorIcons.keyboard,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    "Modo Manual",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: _openManualEntryFlow,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQrScannerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
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
                    width: verticalPadding,
                  ),
                  bottom: BorderSide(
                    color: Colors.black.withOpacity(0.5),
                    width: verticalPadding,
                  ),
                  left: BorderSide(
                    color: Colors.black.withOpacity(0.5),
                    width: horizontalPadding,
                  ),
                  right: BorderSide(
                    color: Colors.black.withOpacity(0.5),
                    width: horizontalPadding,
                  ),
                ),
              ),
              child: Center(
                child: Container(
                  height: scanWindowSize,
                  width: scanWindowSize,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _primaryThemeColor.withOpacity(0.8),
                      width: 3,
                    ),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    "1º Passo: Aponte para o QR Code",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildPhotoCaptureOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isBubbleSheet =
            _scannedSheetData?['correctionType'] == 'BUBBLE_SHEET';

        final boxWidth = isBubbleSheet
            ? constraints.maxWidth * 0.85
            : constraints.maxWidth * 0.90;
        final boxHeight = isBubbleSheet ? boxWidth * 1.05 : boxWidth * 0.55;

        final horizontalPadding = (constraints.maxWidth - boxWidth) / 2;
        final verticalPadding = (constraints.maxHeight - boxHeight) / 2;

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.black.withOpacity(0.7),
                    width: verticalPadding,
                  ),
                  bottom: BorderSide(
                    color: Colors.black.withOpacity(0.7),
                    width: verticalPadding,
                  ),
                  left: BorderSide(
                    color: Colors.black.withOpacity(0.7),
                    width: horizontalPadding,
                  ),
                  right: BorderSide(
                    color: Colors.black.withOpacity(0.7),
                    width: horizontalPadding,
                  ),
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
              top: 100.h,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    "Aluno Identificado:",
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14.sp,
                    ),
                  ),
                  Text(
                    _scannedSheetData?['studentName']?.toUpperCase() ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 60.h,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      kIsWeb
                          ? "No iPhone/web, toque para abrir a câmera do navegador e fotografe o gabarito"
                          : "Encaixe as 4 âncoras pretas dentro da linha verde",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  if (kIsWeb)
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _takePhotoAndSendToAI,
                          child: Container(
                            height: 70.w,
                            width: 70.w,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey[400]!,
                                width: 4,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                PhosphorIcons.camera,
                                color: Colors.black,
                                size: 28.sp,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 14.h),
                        TextButton.icon(
                          onPressed: _pickPhotoFromGalleryFallback,
                          icon: const Icon(
                            PhosphorIcons.image,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Escolher da galeria",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: _takePhotoAndSendToAI,
                      child: Container(
                        height: 70.w,
                        width: 70.w,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey[400]!,
                            width: 4,
                          ),
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
      },
    );
  }
}

// =========================================================================
// WIDGET EXCLUSIVO PARA O BOTTOM SHEET DO MODO MANUAL
// =========================================================================
class _ManualEntrySheet extends StatefulWidget {
  final Future<double?> Function(
    String,
    Map<String, dynamic>, {
    double? autoDetectedGrade,
    List<dynamic>? correctionDetails,
    bool fromManualMode,
  }) openGradeModal;

  const _ManualEntrySheet({required this.openGradeModal});

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  bool isLoading = true;
  List<ExamModel>? _exams;
  ExamModel? _selectedExam;
  List<dynamic>? _studentsList;
  String _searchQuery = "";

  final Color _primaryThemeColor = const Color(0xFFC8A2C8);

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  Future<void> _fetchExams() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final exams = await ExamApiService().getExams(token!);
      setState(() {
        _exams = exams;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchStudents(ExamModel exam) async {
    setState(() {
      _selectedExam = exam;
      isLoading = true;
      _searchQuery = "";
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final data =
          await ExamApiService().getExamSheetsByExamId(exam.id!, token!);
      setState(() {
        _studentsList = data['sheets'];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Row(
              children: [
                if (_selectedExam != null)
                  IconButton(
                    icon: Icon(
                      PhosphorIcons.arrow_left,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: () => setState(() => _selectedExam = null),
                  ),
                Expanded(
                  child: Text(
                    _selectedExam == null
                        ? "Selecione a Prova"
                        : _selectedExam!.title,
                    style: GoogleFonts.saira(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(color: _primaryThemeColor),
              ),
            )
          else if (_selectedExam == null)
            Expanded(
              child: ListView.builder(
                itemCount: _exams?.length ?? 0,
                itemBuilder: (context, index) {
                  final exam = _exams![index];
                  return ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                    leading: CircleAvatar(
                      backgroundColor: _primaryThemeColor.withOpacity(0.2),
                      child: Icon(
                        PhosphorIcons.file_text,
                        color: _primaryThemeColor,
                      ),
                    ),
                    title: Text(
                      exam.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                    ),
                    subtitle: Text(
                      "${exam.subjectName ?? 'Disciplina'} • ${exam.className ?? 'Turma'}",
                    ),
                    trailing: const Icon(PhosphorIcons.caret_right),
                    onTap: () => _fetchStudents(exam),
                  );
                },
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                    child: TextField(
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: "Buscar aluno...",
                        prefixIcon: const Icon(PhosphorIcons.magnifying_glass),
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        var filtered = _studentsList?.where((s) {
                              return s['studentName']
                                  .toString()
                                  .toLowerCase()
                                  .contains(_searchQuery);
                            }).toList() ??
                            [];

                        filtered.sort((a, b) {
                          if (a['status'] == 'SCANNED' &&
                              b['status'] != 'SCANNED') {
                            return 1;
                          }
                          if (a['status'] != 'SCANNED' &&
                              b['status'] == 'SCANNED') {
                            return -1;
                          }
                          return 0;
                        });

                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text(
                              "Nenhum aluno encontrado.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final student = filtered[index];
                            final isScanned = student['status'] == 'SCANNED';

                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 24.w,
                                vertical: 4.h,
                              ),
                              title: Text(
                                student['studentName'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                ),
                              ),
                              subtitle: Text(
                                "Matrícula: ${student['registration'] ?? 'N/A'}",
                              ),
                              trailing: isScanned
                                  ? Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12.w,
                                        vertical: 6.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(20.r),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            student['grade'].toString(),
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16.sp,
                                            ),
                                          ),
                                          SizedBox(width: 4.w),
                                          Icon(
                                            PhosphorIcons.check_circle_fill,
                                            color: Colors.green,
                                            size: 16.sp,
                                          ),
                                        ],
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: () async {
                                        final mockSheetData = {
                                          'studentName': student['studentName'],
                                          'subjectName':
                                              _selectedExam?.subjectName ?? '',
                                          'className':
                                              _selectedExam?.className ?? '',
                                          'examTitle':
                                              _selectedExam?.title ?? '',
                                        };

                                        final finalGrade =
                                            await widget.openGradeModal(
                                          student['qrCodeUuid'],
                                          mockSheetData,
                                          fromManualMode: true,
                                        );

                                        if (finalGrade != null) {
                                          setState(() {
                                            student['status'] = 'SCANNED';
                                            student['grade'] = finalGrade;
                                          });
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryThemeColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.r),
                                        ),
                                      ),
                                      child: const Text("Lançar Nota"),
                                    ),
                            );
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            )
        ],
      ),
    );
  }
}
