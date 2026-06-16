// lib/screens/teacher/exam_scanner_screen.dart

import 'dart:convert';

import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/activity_correction_model.dart';
import 'package:academyhub_mobile/model/exam_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/school_provider.dart';
import 'package:academyhub_mobile/screens/teacher/activity_correction_screen.dart';
import 'package:academyhub_mobile/services/activity_correction_service.dart';
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

import 'embedded_web_camera_stub.dart'
    if (dart.library.html) 'embedded_web_camera_web.dart';
import 'qr_scanner_web_compat_stub.dart'
    if (dart.library.html) 'qr_scanner_web_compat_web.dart';

enum ScannerState { scanningQR, takingPhoto, processing }

const bool kOmrFileDiagnostic =
    bool.fromEnvironment('OMR_FILE_DIAGNOSTIC', defaultValue: false);

Map<String, dynamic> processImageForUpload(Map<String, dynamic> data) {
  final bytes = data['bytes'] as Uint8List;
  final screenW = data['screenW'] as double;
  final screenH = data['screenH'] as double;
  final boxW = data['boxW'] as double;
  final boxH = data['boxH'] as double;
  final isBubbleSheet = data['isBubbleSheet'] == true;
  final source = data['source']?.toString() ?? 'unknown';

  img.Image? decodedImage = img.decodeImage(bytes);
  if (decodedImage == null) {
    return {
      'bytes': bytes,
      'source': source,
      'isBubbleSheet': isBubbleSheet,
      'cropMode': 'decode_failed_passthrough',
      'originalWidth': null,
      'originalHeight': null,
      'cropX': 0,
      'cropY': 0,
      'cropWidth': null,
      'cropHeight': null,
      'croppedWidth': null,
      'croppedHeight': null,
      'removedLeftPercent': 0,
      'removedRightPercent': 0,
      'removedTopPercent': 0,
      'removedBottomPercent': 0,
    };
  }

  decodedImage = img.bakeOrientation(decodedImage);

  final imgW = decodedImage.width.toDouble();
  final imgH = decodedImage.height.toDouble();

  if (isBubbleSheet) {
    return {
      'bytes': bytes,
      'source': source,
      'isBubbleSheet': true,
      'cropMode': 'full_sheet_preserve_anchors_passthrough',
      'originalWidth': decodedImage.width,
      'originalHeight': decodedImage.height,
      'screenWidth': screenW,
      'screenHeight': screenH,
      'maskBoxWidth': boxW,
      'maskBoxHeight': boxH,
      'cropX': 0,
      'cropY': 0,
      'cropWidth': decodedImage.width,
      'cropHeight': decodedImage.height,
      'croppedWidth': decodedImage.width,
      'croppedHeight': decodedImage.height,
      'removedLeftPercent': 0,
      'removedRightPercent': 0,
      'removedTopPercent': 0,
      'removedBottomPercent': 0,
    };
  }

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

  return {
    'bytes': img.encodeJpg(croppedImage, quality: 90),
    'source': source,
    'isBubbleSheet': false,
    'cropMode': 'mask_crop',
    'originalWidth': decodedImage.width,
    'originalHeight': decodedImage.height,
    'screenWidth': screenW,
    'screenHeight': screenH,
    'maskBoxWidth': boxW,
    'maskBoxHeight': boxH,
    'cropX': finalX,
    'cropY': finalY,
    'cropWidth': finalW,
    'cropHeight': finalH,
    'croppedWidth': croppedImage.width,
    'croppedHeight': croppedImage.height,
    'removedLeftPercent': finalX / decodedImage.width,
    'removedRightPercent':
        (decodedImage.width - finalX - finalW) / decodedImage.width,
    'removedTopPercent': finalY / decodedImage.height,
    'removedBottomPercent':
        (decodedImage.height - finalY - finalH) / decodedImage.height,
  };
}

class ExamScannerScreen extends StatefulWidget {
  const ExamScannerScreen({super.key});

  @override
  State<ExamScannerScreen> createState() => _ExamScannerScreenState();
}

class _ExamScannerScreenState extends State<ExamScannerScreen> {
  final ActivityCorrectionService _activityCorrectionService =
      ActivityCorrectionService();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    autoStart: false,
  );

  final ImagePicker _imagePicker = ImagePicker();

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  late final EmbeddedWebCameraController _webCameraController;

  ScannerState _currentState = ScannerState.scanningQR;

  String? _scannedQrCodeUuid;
  Map<String, dynamic>? _scannedSheetData;

  final Color _primaryThemeColor = const Color(0xFFC8A2C8);

  bool _isCapturingPhoto = false;
  Uint8List? _webPickedPreviewBytes;
  bool _hasStartedQrScanner = false;
  bool _isStartingQrScanner = false;
  String? _qrScannerErrorMessage;
  DateTime? _lastSheetVisualLogAt;
  int _correlationSequence = 0;
  int _qrDetectionEvents = 0;
  String? _lastDetectedQrCode;
  String? _activeCorrelationId;
  Stopwatch? _qrScanStopwatch;
  Stopwatch? _scanTotalStopwatch;
  final TextEditingController _diagnosticQrUuidController =
      TextEditingController();

  bool get _isWebCameraFlow => kIsWeb;
  bool get _usesWebDomOverlayFlow =>
      kIsWeb && _webCameraController.shouldUseDomOverlay;

  String _newCorrelationId() {
    _correlationSequence += 1;
    return 'omr-${DateTime.now().microsecondsSinceEpoch}-$_correlationSequence';
  }

  void _logOmrPerformance(String event, Map<String, Object?> data) {
    if (!kOmrPerformanceDebug) return;
    debugPrint('[OMR PERF MOBILE SCANNER] $event ${jsonEncode(data)}');
  }

  Map<String, dynamic> _buildBubbleSheetPassthroughImage({
    required Uint8List bytes,
    required String source,
    required Size screenSize,
    required double boxW,
    required double boxH,
    img.Image? originalImage,
  }) {
    return {
      'bytes': bytes,
      'source': source,
      'isBubbleSheet': true,
      'cropMode': 'full_sheet_preserve_anchors_passthrough',
      'originalWidth': originalImage?.width,
      'originalHeight': originalImage?.height,
      'screenWidth': screenSize.width,
      'screenHeight': screenSize.height,
      'maskBoxWidth': boxW,
      'maskBoxHeight': boxH,
      'cropX': 0,
      'cropY': 0,
      'cropWidth': originalImage?.width,
      'cropHeight': originalImage?.height,
      'croppedWidth': originalImage?.width,
      'croppedHeight': originalImage?.height,
      'removedLeftPercent': 0,
      'removedRightPercent': 0,
      'removedTopPercent': 0,
      'removedBottomPercent': 0,
    };
  }

  @override
  void initState() {
    super.initState();
    _webCameraController = EmbeddedWebCameraController()
      ..addListener(_onWebCameraChanged);

    if (!kIsWeb) {
      _startScannerSafely();
    } else {
      debugPrint(
        '[ExamScanner] Flutter Web detectado. A camera sera iniciada por acao do usuario.',
      );
    }
  }

  Future<void> _startScannerSafely() async {
    if (_isStartingQrScanner) return;

    if (mounted) {
      setState(() {
        _isStartingQrScanner = true;
        _qrScannerErrorMessage = null;
      });
    }

    try {
      debugPrint(
        '[ExamScanner] Iniciando scanner QR. kIsWeb=$kIsWeb',
      );
      await _scannerController.start();
      if (kIsWeb) {
        scheduleQrPreviewRepair(reason: 'scanner-started');
      }
      debugPrint('[ExamScanner] Scanner QR iniciado com sucesso.');
      _qrDetectionEvents = 0;
      _lastDetectedQrCode = null;
      _qrScanStopwatch = Stopwatch()..start();
      _logOmrPerformance('qr_scanner_started', {
        'baseUrl': ApiConfig.baseUrl,
        'apiUrl': ApiConfig.apiUrl,
        'usingLocalhost': ApiConfig.baseUrl.contains('localhost'),
        'kIsWeb': kIsWeb,
      });
      if (mounted) {
        setState(() {
          _hasStartedQrScanner = true;
        });
      }
    } catch (e) {
      debugPrint("Erro ao iniciar o scanner de QR: $e");
      if (mounted) {
        setState(() {
          _qrScannerErrorMessage = kIsWeb
              ? 'Nao foi possivel acessar a camera. Verifique a permissao da camera no Safari/iPhone e use HTTPS.'
              : 'Nao foi possivel acessar a camera.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingQrScanner = false;
        });
      }
    }
  }

  void _onWebCameraChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initPhotoCamera() async {
    if (kIsWeb) {
      await _webCameraController.start();
      return;
    }

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
    await _webCameraController.stop();
    _webPickedPreviewBytes = null;
    _isCapturingPhoto = false;

    if (mounted) {
      setState(() {
        _scannedQrCodeUuid = null;
        _scannedSheetData = null;
        _activeCorrelationId = null;
        _scanTotalStopwatch = null;
        _currentState = ScannerState.scanningQR;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!kIsWeb || _hasStartedQrScanner) {
          _startScannerSafely();
        }
      });
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _cameraController?.dispose();
    _diagnosticQrUuidController.dispose();
    _webCameraController
      ..removeListener(_onWebCameraChanged)
      ..dispose();
    super.dispose();
  }

  String _friendlyOmrError(Object error) {
    final message =
        error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();

    if (message.isEmpty) {
      return 'Nao foi possivel processar o gabarito. Tente capturar novamente.';
    }

    return message;
  }

  bool _isActivityQr(String qrCodeValue) {
    return qrCodeValue.trim().startsWith('AH-ACTIVITY-1:');
  }

  String _friendlyActivityCorrectionError(Object error) {
    final message =
        error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();

    if (message.isEmpty) {
      return 'Nao foi possivel carregar a atividade.';
    }

    return message;
  }

  Future<void> _openActivityCorrectionFlow({
    required String qrCodePayload,
    String? correlationId,
  }) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      await _resetToQrMode();
      return;
    }

    _logOmrPerformance('activity_qr_resolve_started', {
      'correlationId': correlationId,
      'qrCodePayload': qrCodePayload,
    });

    final resolveResult =
        await showScannerOperationDialog<ActivityQrResolveResult>(
      context: context,
      loadingTitle: 'Carregando atividade...',
      loadingMessage: 'Buscando dados da atividade impressa.',
      loadingDetail: 'Preparando a correção qualitativa.',
      successTitle: 'Atividade encontrada!',
      successMessage: 'Abrindo a tela de correção.',
      successVisibleDuration: const Duration(milliseconds: 900),
      operation: () async {
        try {
          return await _activityCorrectionService.resolveQr(
            token: token,
            qrCodePayload: qrCodePayload,
          );
        } catch (error) {
          throw Exception(_friendlyActivityCorrectionError(error));
        }
      },
    );

    if (resolveResult == null) {
      await _resetToQrMode();
      return;
    }

    if (!mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityCorrectionScreen(resolveResult: resolveResult),
      ),
    );

    if (!mounted) return;
    await _resetToQrMode();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correcao da atividade salva com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _runFileQrDiagnostic() async {
    final qrCodeUuid = _diagnosticQrUuidController.text.trim();
    if (qrCodeUuid.isEmpty || _currentState != ScannerState.scanningQR) {
      return;
    }

    final correlationId = _newCorrelationId();
    _activeCorrelationId = correlationId;
    _scanTotalStopwatch = Stopwatch()..start();
    _qrScanStopwatch ??= Stopwatch()..start();

    _logOmrPerformance('file_qr_diagnostic_started', {
      'correlationId': correlationId,
      'qrCodeUuid': qrCodeUuid,
      'baseUrl': ApiConfig.baseUrl,
      'usingLocalhost': ApiConfig.baseUrl.contains('localhost'),
    });

    setState(() => _currentState = ScannerState.processing);
    await _scannerController.stop();

    if (!mounted) return;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (_isActivityQr(qrCodeUuid)) {
      await _openActivityCorrectionFlow(
        qrCodePayload: qrCodeUuid,
        correlationId: correlationId,
      );
      return;
    }

    final sheetData = await showScannerOperationDialog<Map<String, dynamic>>(
      context: context,
      loadingTitle: 'Identificando...',
      loadingMessage: 'Validando QR informado por arquivo.',
      loadingDetail: 'Teste OMR Web sem camera',
      successTitle: 'Aluno Encontrado!',
      successMessage: 'Agora selecione a imagem do gabarito.',
      successVisibleDuration: const Duration(milliseconds: 700),
      operation: () async {
        final verifyStopwatch = Stopwatch()..start();
        try {
          final data = await ExamApiService().verifySheetData(
            qrCodeUuid: qrCodeUuid,
            token: token!,
            correlationId: correlationId,
          );
          verifyStopwatch.stop();
          _logOmrPerformance('file_qr_verify_completed', {
            'correlationId': correlationId,
            'verifyMs': verifyStopwatch.elapsedMilliseconds,
            'studentName': data['studentName'],
            'examId': data['examId']?.toString(),
            'correctionType': data['correctionType'],
            'hasOmrLayout': data['hasOmrLayout'],
            'apiPerformance': data['performance'],
          });
          return data;
        } catch (error) {
          verifyStopwatch.stop();
          _logOmrPerformance('file_qr_verify_failed', {
            'correlationId': correlationId,
            'verifyMs': verifyStopwatch.elapsedMilliseconds,
            'error': error.toString(),
          });
          rethrow;
        }
      },
    );

    if (sheetData == null) {
      await _resetToQrMode();
      return;
    }

    setState(() {
      _scannedQrCodeUuid = qrCodeUuid;
      _scannedSheetData = sheetData;
      _currentState = ScannerState.takingPhoto;
    });
  }

  // 👇 LÓGICA ATUALIZADA DO QR CODE COM O NOVO POP-UP
  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrCodeUuid = barcodes.first.rawValue;
    if (qrCodeUuid == null || qrCodeUuid.isEmpty) return;

    _qrDetectionEvents += 1;
    final sameAsPrevious = _lastDetectedQrCode == qrCodeUuid;
    _lastDetectedQrCode = qrCodeUuid;
    _logOmrPerformance('qr_detect_event', {
      'qrDetectionEvents': _qrDetectionEvents,
      'sameAsPrevious': sameAsPrevious,
      'state': _currentState.name,
      'elapsedSinceScannerStartMs': _qrScanStopwatch?.elapsedMilliseconds,
    });

    if (_currentState != ScannerState.scanningQR) return;

    final correlationId = _newCorrelationId();
    _activeCorrelationId = correlationId;
    _scanTotalStopwatch = Stopwatch()..start();

    debugPrint('[ExamScanner] QR: detectado $qrCodeUuid');
    _logOmrPerformance('qr_accept', {
      'correlationId': correlationId,
      'elapsedUntilQrMs': _qrScanStopwatch?.elapsedMilliseconds,
      'qrDetectionEvents': _qrDetectionEvents,
    });
    setState(() => _currentState = ScannerState.processing);
    await _scannerController.stop();
    debugPrint('[ExamScanner] QR: scanner pausado/parado.');

    if (!mounted) return;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (_isActivityQr(qrCodeUuid)) {
      await _openActivityCorrectionFlow(
        qrCodePayload: qrCodeUuid,
        correlationId: correlationId,
      );
      return;
    }

    final sheetData = await showScannerOperationDialog<Map<String, dynamic>>(
      context: context,
      loadingTitle: 'Identificando...',
      loadingMessage: 'Buscando informações do aluno.',
      loadingDetail: 'Sincronizando com a nuvem...',
      successTitle: 'Aluno Encontrado!',
      successMessage: 'Preparando a câmera de correção.',
      successVisibleDuration: const Duration(milliseconds: 900),
      operation: () async {
        final verifyStopwatch = Stopwatch()..start();
        try {
          final data = await ExamApiService().verifySheetData(
            qrCodeUuid: qrCodeUuid,
            token: token!,
            correlationId: correlationId,
          );
          verifyStopwatch.stop();
          _logOmrPerformance('qr_verify_completed', {
            'correlationId': correlationId,
            'verifyMs': verifyStopwatch.elapsedMilliseconds,
            'studentName': data['studentName'],
            'examId': data['examId']?.toString(),
            'correctionType': data['correctionType'],
          });
          if (!kIsWeb) await _initPhotoCamera();
          return data;
        } catch (error) {
          verifyStopwatch.stop();
          _logOmrPerformance('qr_verify_failed', {
            'correlationId': correlationId,
            'verifyMs': verifyStopwatch.elapsedMilliseconds,
            'error': error.toString(),
          });
          rethrow;
        }
      },
    );

    if (sheetData == null) {
      // Usuário cancelou ou deu erro
      await _resetToQrMode();
      return;
    }

    debugPrint('[ExamScanner] QR: aluno identificado.');
    debugPrint('[ExamScanner] QR: avancando para etapa do gabarito.');

    setState(() {
      _scannedQrCodeUuid = qrCodeUuid;
      _scannedSheetData = sheetData;
      _currentState = ScannerState.takingPhoto;
    });

    debugPrint(
      '[ExamScanner] Avancou para captura do gabarito. kIsWeb=$kIsWeb',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _logSheetVisualState(
        'apos leitura do QR',
        platformViewActive: kIsWeb && !_usesWebDomOverlayFlow,
        fullBlackCoverActive: false,
      );
    });
  }

  // 👇 LÓGICA ATUALIZADA DO ENVIO DA FOTO COM O NOVO POP-UP
  Future<void> _takePhotoAndSendToAI() async {
    if (_isCapturingPhoto) return;

    _isCapturingPhoto = true;

    Uint8List fullImageBytes;
    final correlationId = _activeCorrelationId ?? _newCorrelationId();
    _activeCorrelationId = correlationId;
    _scanTotalStopwatch ??= Stopwatch()..start();
    final captureStopwatch = Stopwatch()..start();

    if (_isWebCameraFlow) {
      if (!_webCameraController.isStarted) {
        _isCapturingPhoto = false;
        setState(() => _currentState = ScannerState.takingPhoto);
        await _startPhotoCameraFromUserGesture();
        return;
      }

      try {
        debugPrint(
          '[ExamScanner] GABARITO: captura solicitada pela camera web embutida.',
        );
        fullImageBytes = await _webCameraController.captureFrame();
        captureStopwatch.stop();
        _logOmrPerformance('sheet_capture_completed', {
          'correlationId': correlationId,
          'source': 'web_camera',
          'captureMs': captureStopwatch.elapsedMilliseconds,
          'bytes': fullImageBytes.length,
        });
      } catch (e) {
        debugPrint('[ExamScanner] Erro ao capturar frame da camera web: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nao foi possivel capturar a imagem da camera. Tente novamente.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _currentState = ScannerState.takingPhoto);
        }
        _isCapturingPhoto = false;
        return;
      }
    } else {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        _isCapturingPhoto = false;
        setState(() => _currentState = ScannerState.takingPhoto);
        return;
      }
      final XFile photo = await _cameraController!.takePicture();
      fullImageBytes = await photo.readAsBytes();
      captureStopwatch.stop();
      _logOmrPerformance('sheet_capture_completed', {
        'correlationId': correlationId,
        'source': 'camera_package',
        'captureMs': captureStopwatch.elapsedMilliseconds,
        'bytes': fullImageBytes.length,
      });
    }

    await _processCapturedSheetImage(fullImageBytes);
  }

  Future<void> _processCapturedSheetImage(Uint8List fullImageBytes) async {
    if (!mounted) {
      _isCapturingPhoto = false;
      return;
    }

    debugPrint(
      '[ExamScanner] GABARITO: iniciando processamento. '
      'bytes=${fullImageBytes.length}',
    );
    final correlationId = _activeCorrelationId ?? _newCorrelationId();
    _activeCorrelationId = correlationId;
    _scanTotalStopwatch ??= Stopwatch()..start();
    setState(() => _currentState = ScannerState.processing);

    final screenSize = MediaQuery.of(context).size;
    final isBubbleSheet =
        _scannedSheetData?['correctionType'] == 'BUBBLE_SHEET';
    final boxW =
        isBubbleSheet ? screenSize.width * 0.85 : screenSize.width * 0.90;
    final boxH = isBubbleSheet ? boxW * 1.05 : boxW * 0.55;
    final token = Provider.of<AuthProvider>(context, listen: false).token;

    _logOmrPerformance('sheet_processing_started', {
      'correlationId': correlationId,
      'fullImageBytes': fullImageBytes.length,
      'screenWidth': screenSize.width,
      'screenHeight': screenSize.height,
      'isBubbleSheet': isBubbleSheet,
      'maskBoxWidth': boxW,
      'maskBoxHeight': boxH,
      'examId': _scannedSheetData?['examId']?.toString(),
      'correctionType': _scannedSheetData?['correctionType'],
    });

    final studentName = _scannedSheetData?['studentName']?.toUpperCase() ??
        'ALUNO DESCONHECIDO';

    Map<String, dynamic>? aiResult;
    try {
      aiResult = await showScannerOperationDialog<Map<String, dynamic>>(
        context: context,
        loadingTitle: 'Analisando Prova',
        loadingMessage: 'A Inteligência Artificial está calculando a nota...',
        loadingDetail: 'Aluno(a): $studentName',
        successTitle: 'Correção Concluída!',
        successMessage: 'O resultado está pronto para validação.',
        operation: () async {
          // 1. Recorta a imagem
          final cropStopwatch = Stopwatch()..start();
          final processedImage = isBubbleSheet
              ? _buildBubbleSheetPassthroughImage(
                  bytes: fullImageBytes,
                  source: kIsWeb ? 'web_camera' : 'camera_package',
                  screenSize: screenSize,
                  boxW: boxW,
                  boxH: boxH,
                  originalImage: kOmrPerformanceDebug
                      ? img.decodeImage(fullImageBytes)
                      : null,
                )
              : await compute(processImageForUpload, {
                  'bytes': fullImageBytes,
                  'screenW': screenSize.width,
                  'screenH': screenSize.height,
                  'boxW': boxW,
                  'boxH': boxH,
                  'isBubbleSheet': false,
                  'source': kIsWeb ? 'web_camera' : 'camera_package',
                });
          cropStopwatch.stop();
          final croppedBytes = processedImage['bytes'] as Uint8List;
          if (kOmrPerformanceDebug && mounted) {
            setState(() => _webPickedPreviewBytes = croppedBytes);
          }
          _logOmrPerformance('sheet_crop_completed', {
            'correlationId': correlationId,
            'cropMs': cropStopwatch.elapsedMilliseconds,
            'cropMode': processedImage['cropMode'],
            'source': processedImage['source'],
            'originalWidth': processedImage['originalWidth'],
            'originalHeight': processedImage['originalHeight'],
            'croppedBytes': croppedBytes.length,
            'croppedWidth': processedImage['croppedWidth'],
            'croppedHeight': processedImage['croppedHeight'],
            'cropRect': {
              'x': processedImage['cropX'],
              'y': processedImage['cropY'],
              'width': processedImage['cropWidth'],
              'height': processedImage['cropHeight'],
            },
            'removedPercent': {
              'left': processedImage['removedLeftPercent'],
              'right': processedImage['removedRightPercent'],
              'top': processedImage['removedTopPercent'],
              'bottom': processedImage['removedBottomPercent'],
            },
            'correctionType': _scannedSheetData?['correctionType'],
            'totalQuestions': _scannedSheetData?['totalQuestions'],
          });

          // 2. Envia para a IA
          final omrStopwatch = Stopwatch()..start();
          final result = await ExamApiService().processOmrImage(
            imageBytes: croppedBytes,
            token: token!,
            correctionType: isBubbleSheet ? 'BUBBLE_SHEET' : 'DIRECT_GRADE',
            examId: _scannedSheetData?['examId'],
            correlationId: correlationId,
          );
          omrStopwatch.stop();
          _logOmrPerformance('sheet_omr_completed', {
            'correlationId': correlationId,
            'omrRequestMs': omrStopwatch.elapsedMilliseconds,
            'scanTotalMs': _scanTotalStopwatch?.elapsedMilliseconds,
            'apiCorrelationId': result['correlationId'],
            'apiPerformance': result['performance'],
            'success': result['success'],
          });
          return result;
        },
      );
      debugPrint(
        '[ExamScanner] GABARITO: processamento finalizado. '
        'resultado=${aiResult != null}',
      );
    } catch (e, stackTrace) {
      debugPrint('[ExamScanner] GABARITO: erro no processamento: $e');
      debugPrint('$stackTrace');
      _isCapturingPhoto = false;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyOmrError(e),
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _currentState = ScannerState.takingPhoto);
      return;
    }

    _isCapturingPhoto = false;

    if (aiResult != null && mounted) {
      final detectedGrade = _extractOmrGrade(aiResult);
      final details = _extractCorrectionDetails(aiResult);
      final summary = _extractCorrectionSummary(aiResult);

      await _showGradeConfirmationModal(
        _scannedQrCodeUuid!,
        _scannedSheetData!,
        autoDetectedGrade: detectedGrade,
        correctionDetails: details,
        correctionSummary: summary,
        aiResult: aiResult,
      );
    } else {
      if (mounted) setState(() => _currentState = ScannerState.takingPhoto);
    }
  }

  Future<void> _startPhotoCameraFromUserGesture() async {
    if (!kIsWeb || _webCameraController.isStarting || _isCapturingPhoto) {
      return;
    }

    debugPrint('[ExamScanner] GABARITO: botao Iniciar camera clicado.');
    _webPickedPreviewBytes = null;

    if (_webCameraController.shouldUseDomOverlay) {
      await _captureSheetWithWebDomOverlay();
      return;
    }

    debugPrint('[ExamScanner] GABARITO: usando camera embutida web.');

    try {
      await _initPhotoCamera();
    } catch (e) {
      debugPrint('[ExamScanner] Erro ao iniciar camera web do gabarito: $e');
    }

    if (!mounted) return;

    final message = _webCameraController.errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _captureSheetWithWebDomOverlay() async {
    if (_isCapturingPhoto) return;

    _isCapturingPhoto = true;
    debugPrint('[ExamScanner] GABARITO: abrindo overlay HTML.');

    final isBubbleSheet =
        _scannedSheetData?['correctionType'] == 'BUBBLE_SHEET';
    final studentName = _scannedSheetData?['studentName']?.toString() ?? '';

    try {
      final bytes = await _webCameraController.captureWithDomOverlay(
        isBubbleSheet: isBubbleSheet,
        studentName: studentName,
      );

      if (!mounted) {
        _isCapturingPhoto = false;
        return;
      }

      if (bytes == null) {
        _isCapturingPhoto = false;
        setState(() => _currentState = ScannerState.takingPhoto);
        return;
      }

      debugPrint(
        '[ExamScanner] GABARITO: tamanho da imagem capturada: '
        '${bytes.length} bytes',
      );
      debugPrint('[ExamScanner] GABARITO: imagem enviada ao Flutter.');
      setState(() {
        _webPickedPreviewBytes = bytes;
      });
      debugPrint('[ExamScanner] GABARITO: captura realizada.');
      await _processCapturedSheetImage(bytes);
    } catch (e) {
      debugPrint('[ExamScanner] GABARITO: erro na camera embutida web/iOS: $e');
      _isCapturingPhoto = false;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nao foi possivel abrir a camera embutida. Use Safari em HTTPS ou tente o fallback.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _currentState = ScannerState.takingPhoto);
    }
  }

  // 👇 LÓGICA ATUALIZADA DA GALERIA COM O NOVO POP-UP
  Future<void> _pickPhotoFromGalleryFallback() async {
    if (_isCapturingPhoto) return;

    debugPrint('[ExamScanner] GABARITO: fallback galeria clicado.');
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
    img.Image? originalImage;
    if (kOmrPerformanceDebug) {
      originalImage = img.decodeImage(fullImageBytes);
    }
    _webPickedPreviewBytes = fullImageBytes;
    final correlationId = _activeCorrelationId ?? _newCorrelationId();
    _activeCorrelationId = correlationId;
    _scanTotalStopwatch ??= Stopwatch()..start();
    _logOmrPerformance('gallery_image_selected', {
      'correlationId': correlationId,
      'fullImageBytes': fullImageBytes.length,
      'originalWidth': originalImage?.width,
      'originalHeight': originalImage?.height,
      'fileName': pickedFile.name,
    });

    if (!mounted) {
      _isCapturingPhoto = false;
      return;
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

    _logOmrPerformance('gallery_processing_started', {
      'correlationId': correlationId,
      'screenWidth': screenSize.width,
      'screenHeight': screenSize.height,
      'isBubbleSheet': isBubbleSheet,
      'maskBoxWidth': boxW,
      'maskBoxHeight': boxH,
      'examId': _scannedSheetData?['examId']?.toString(),
      'correctionType': _scannedSheetData?['correctionType'],
    });

    Map<String, dynamic>? aiResult;
    try {
      aiResult = await showScannerOperationDialog<Map<String, dynamic>>(
        context: context,
        loadingTitle: 'Analisando Prova',
        loadingMessage: 'A Inteligência Artificial está calculando a nota...',
        loadingDetail: 'Aluno(a): $studentName',
        successTitle: 'Correção Concluída!',
        successMessage: 'O resultado está pronto para validação.',
        operation: () async {
          final cropStopwatch = Stopwatch()..start();
          final processedImage = isBubbleSheet
              ? _buildBubbleSheetPassthroughImage(
                  bytes: fullImageBytes,
                  source: 'gallery',
                  screenSize: screenSize,
                  boxW: boxW,
                  boxH: boxH,
                  originalImage: originalImage,
                )
              : await compute(processImageForUpload, {
                  'bytes': fullImageBytes,
                  'screenW': screenSize.width,
                  'screenH': screenSize.height,
                  'boxW': boxW,
                  'boxH': boxH,
                  'isBubbleSheet': false,
                  'source': 'gallery',
                });
          cropStopwatch.stop();
          final croppedBytes = processedImage['bytes'] as Uint8List;
          if (kOmrPerformanceDebug && mounted) {
            setState(() => _webPickedPreviewBytes = croppedBytes);
          }
          _logOmrPerformance('gallery_crop_completed', {
            'correlationId': correlationId,
            'cropMs': cropStopwatch.elapsedMilliseconds,
            'cropMode': processedImage['cropMode'],
            'source': processedImage['source'],
            'originalWidth': processedImage['originalWidth'],
            'originalHeight': processedImage['originalHeight'],
            'croppedBytes': croppedBytes.length,
            'croppedWidth': processedImage['croppedWidth'],
            'croppedHeight': processedImage['croppedHeight'],
            'cropRect': {
              'x': processedImage['cropX'],
              'y': processedImage['cropY'],
              'width': processedImage['cropWidth'],
              'height': processedImage['cropHeight'],
            },
            'removedPercent': {
              'left': processedImage['removedLeftPercent'],
              'right': processedImage['removedRightPercent'],
              'top': processedImage['removedTopPercent'],
              'bottom': processedImage['removedBottomPercent'],
            },
            'correctionType': _scannedSheetData?['correctionType'],
            'totalQuestions': _scannedSheetData?['totalQuestions'],
          });

          final omrStopwatch = Stopwatch()..start();
          final result = await ExamApiService().processOmrImage(
            imageBytes: croppedBytes,
            token: token!,
            correctionType: isBubbleSheet ? 'BUBBLE_SHEET' : 'DIRECT_GRADE',
            examId: _scannedSheetData?['examId'],
            correlationId: correlationId,
          );
          omrStopwatch.stop();
          _logOmrPerformance('gallery_omr_completed', {
            'correlationId': correlationId,
            'omrRequestMs': omrStopwatch.elapsedMilliseconds,
            'scanTotalMs': _scanTotalStopwatch?.elapsedMilliseconds,
            'apiCorrelationId': result['correlationId'],
            'apiPerformance': result['performance'],
            'success': result['success'],
          });
          return result;
        },
      );
    } catch (e, stackTrace) {
      debugPrint('[ExamScanner] GABARITO: erro no processamento: $e');
      debugPrint('$stackTrace');
      _isCapturingPhoto = false;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyOmrError(e),
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _currentState = ScannerState.takingPhoto);
      return;
    }

    _isCapturingPhoto = false;

    if (aiResult != null && mounted) {
      final detectedGrade = _extractOmrGrade(aiResult);
      final details = _extractCorrectionDetails(aiResult);
      final summary = _extractCorrectionSummary(aiResult);

      await _showGradeConfirmationModal(
        _scannedQrCodeUuid!,
        _scannedSheetData!,
        autoDetectedGrade: detectedGrade,
        correctionDetails: details,
        correctionSummary: summary,
        aiResult: aiResult,
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

  Widget _buildQrCameraLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        debugPrint(
          '[ExamScanner] QR preview host size='
          '${constraints.maxWidth}x${constraints.maxHeight} kIsWeb=$kIsWeb',
        );
        if (kIsWeb && _hasStartedQrScanner) {
          scheduleQrPreviewRepair(reason: 'qr-layer-build');
        }

        return MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
          placeholderBuilder: (_) => const ColoredBox(color: Colors.black),
          errorBuilder: (context, error) {
            debugPrint('[ExamScanner] Erro no MobileScanner QR: $error');
            return const ColoredBox(
              color: Colors.black,
              child: Center(
                child: Text(
                  'Nao foi possivel iniciar a camera.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWebCapturePlaceholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDomOverlay = _usesWebDomOverlayFlow;
        final hasCapturedPreview = _webPickedPreviewBytes != null;
        final platformViewActive =
            kIsWeb && !useDomOverlay && !hasCapturedPreview;
        final fullBlackCoverActive =
            !hasCapturedPreview && !_webCameraController.isStarted;

        _logSheetVisualState(
          'build camera gabarito',
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          platformViewActive: platformViewActive,
          fullBlackCoverActive: useDomOverlay ? false : fullBlackCoverActive,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            if (hasCapturedPreview)
              Image.memory(
                _webPickedPreviewBytes!,
                fit: BoxFit.cover,
              )
            else if (useDomOverlay)
              _buildWebDomOverlayPlaceholder()
            else
              Stack(
                fit: StackFit.expand,
                children: [
                  buildEmbeddedWebCameraView(_webCameraController),
                  if (_webCameraController.isStarting)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  if (!_webCameraController.isStarted)
                    _buildSheetCameraCardPlaceholder(),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildWebDomOverlayPlaceholder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        _buildSheetCameraCardPlaceholder(),
      ],
    );
  }

  Widget _buildSheetCameraCardPlaceholder() {
    return Center(
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
              "Camera do gabarito",
              style: GoogleFonts.saira(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            Text(
              _webCameraController.errorMessage ??
                  _webCameraController.statusMessage ??
                  "Toque em Iniciar camera para abrir a previa dentro da tela e alinhar as quatro ancoras pela mascara.",
              style: TextStyle(
                color: _webCameraController.errorMessage == null
                    ? Colors.white70
                    : Colors.redAccent,
                fontSize: 14.sp,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _logSheetVisualState(
    String reason, {
    double? width,
    double? height,
    bool? platformViewActive,
    bool? fullBlackCoverActive,
  }) {
    final now = DateTime.now();
    if (_lastSheetVisualLogAt != null &&
        now.difference(_lastSheetVisualLogAt!) < const Duration(seconds: 1)) {
      return;
    }

    _lastSheetVisualLogAt = now;
    debugPrint(
      '[ExamScanner] GABARITO: tela montada. '
      'reason=$reason '
      'estado atual da tela=$_currentState '
      'card visivel=${_currentState == ScannerState.takingPhoto} '
      'overlay preto ativo? ${fullBlackCoverActive ?? false} '
      'platformViewAtivo=${platformViewActive ?? false} '
      'domOverlayFlow=$_usesWebDomOverlayFlow '
      'cameraStarted=${_webCameraController.isStarted} '
      'cameraStarting=${_webCameraController.isStarting} '
      'previewCapturado=${_webPickedPreviewBytes != null} '
      'host=${width ?? 0}x${height ?? 0}',
    );
  }

  double? _readNumericValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  int? _readIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _extractOmrGrade(Map<String, dynamic> aiResult) {
    return _readNumericValue(aiResult['grade']) ??
        _readNumericValue(aiResult['objectiveGrade']) ??
        _readNumericValue(aiResult['score']);
  }

  Map<String, dynamic>? _extractCorrectionSummary(
    Map<String, dynamic> aiResult,
  ) {
    for (final key in const [
      'correctionSummary',
      'correctionDetailsPayload',
      'correctionDetails',
    ]) {
      final value = aiResult[key];
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }

    final questionResults = aiResult['questionResults'];
    if (questionResults is List) {
      return {
        'totalQuestions': aiResult['totalQuestions'],
        'correctCount': aiResult['correctCount'],
        'wrongCount': aiResult['wrongCount'],
        'blankCount': aiResult['blankCount'],
        'multipleCount': aiResult['multipleCount'],
        'uncertainCount': aiResult['uncertainCount'],
        'notDetectedCount': aiResult['notDetectedCount'],
        'studentAnswers': aiResult['studentAnswers'],
        'answerKey': aiResult['answerKey'],
        'questionResults': questionResults,
      };
    }

    return null;
  }

  List<dynamic>? _extractCorrectionDetails(Map<String, dynamic> aiResult) {
    final legacyDetails = aiResult['correctionDetails'];
    if (legacyDetails is List) return legacyDetails;

    final summary = _extractCorrectionSummary(aiResult);
    final questionResults = summary?['questionResults'];
    if (questionResults is List) return questionResults;

    final topLevelResults = aiResult['questionResults'];
    if (topLevelResults is List) return topLevelResults;

    return null;
  }

  List<Map<String, dynamic>>? _extractPersistableAnswers(
    Map<String, dynamic>? aiResult,
    List<dynamic>? correctionDetails,
  ) {
    if (aiResult == null) return null;

    final persisted = aiResult['persistableAnswers'];
    if (persisted is List) {
      return persisted
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    final source = correctionDetails ?? _extractCorrectionDetails(aiResult);
    if (source == null) return null;

    return source
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<double?> _showGradeConfirmationModal(
    String qrCodeUuid,
    Map<String, dynamic> sheetData, {
    double? autoDetectedGrade,
    List<dynamic>? correctionDetails,
    Map<String, dynamic>? correctionSummary,
    Map<String, dynamic>? aiResult,
    bool fromManualMode = false,
  }) async {
    final TextEditingController gradeController = TextEditingController(
      text:
          autoDetectedGrade != null ? autoDetectedGrade.toStringAsFixed(1) : '',
    );
    bool isSaving = false;
    double? finalReturnedGrade;
    final isFileDiagnosticSaveBlocked = kIsWeb && kOmrFileDiagnostic;

    final schoolName =
        Provider.of<SchoolProvider>(context, listen: false).school?.name ??
            'Academy Hub';
    final totalQuestions =
        _readIntValue(correctionSummary?['totalQuestions']) ??
            _readIntValue(aiResult?['totalQuestions']);
    final correctCount = _readIntValue(correctionSummary?['correctCount']) ??
        _readIntValue(aiResult?['correctCount']);
    final wrongCount = _readIntValue(correctionSummary?['wrongCount']) ??
        _readIntValue(aiResult?['wrongCount']);
    final blankCount = _readIntValue(correctionSummary?['blankCount']) ??
        _readIntValue(aiResult?['blankCount']);
    final multipleCount = _readIntValue(correctionSummary?['multipleCount']) ??
        _readIntValue(aiResult?['multipleCount']);
    final uncertainCount =
        _readIntValue(correctionSummary?['uncertainCount']) ??
            _readIntValue(aiResult?['uncertainCount']);
    final notDetectedCount =
        _readIntValue(correctionSummary?['notDetectedCount']) ??
            _readIntValue(aiResult?['notDetectedCount']);

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
                      if (correctCount != null && totalQuestions != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: Center(
                            child: Text(
                              'Acertos: $correctCount/$totalQuestions',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                                fontWeight: FontWeight.w700,
                                fontSize: 13.sp,
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
                                    final marked = detail['studentMarked'] ??
                                        detail['studentAnswer'] ??
                                        detail['markedOption'];
                                    final correctAns = detail['correctAnswer'];
                                    final status = detail['status']
                                        ?.toString()
                                        .toLowerCase();
                                    final debugStatus = detail['debugStatus']
                                        ?.toString()
                                        .toLowerCase();
                                    final hasLowConfidence =
                                        status == 'ambiguous' ||
                                            status == 'uncertain' ||
                                            status == 'low_confidence' ||
                                            debugStatus == 'low_confidence';
                                    final hasMultipleMarking =
                                        status == 'multiple' ||
                                            marked == 'MULTIPLE' ||
                                            debugStatus == 'multiple';
                                    final isBlank =
                                        status == 'blank' || marked == null;
                                    final isNotDetected =
                                        status == 'not_detected' ||
                                            marked == 'NOT_DETECTED';
                                    final earnedPoints =
                                        detail['earnedPoints'] ??
                                            detail['points'] ??
                                            0;
                                    final subtitleText = hasMultipleMarking
                                        ? 'Multipla marcacao'
                                        : (isNotDetected
                                            ? 'Questao nao detectada com seguranca.'
                                            : (isBlank
                                                ? (hasLowConfidence
                                                    ? 'Leitura incerta. Revisar manualmente.'
                                                    : 'Em branco')
                                                : (hasLowConfidence
                                                    ? 'Marcou $marked - baixa confianca. Revisar manualmente.'
                                                    : (isCorrect
                                                        ? 'Acertou (Marcou $marked)'
                                                        : 'Errou (Marcou $marked, era $correctAns)'))));

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
                                        subtitleText,
                                        style: TextStyle(
                                          color: isCorrect
                                              ? Colors.green
                                              : (isBlank
                                                  ? Colors.orange
                                                  : Colors.red),
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      trailing: Text(
                                        '+$earnedPoints pts',
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
                      if (isFileDiagnosticSaveBlocked) ...[
                        SizedBox(height: 12.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            'Modo diagnostico por arquivo: processamento concluido sem gravar nota.',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
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
                              onPressed: isSaving || isFileDiagnosticSaveBlocked
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
                                        final objectiveGrade =
                                            _readNumericValue(
                                                  aiResult?['objectiveGrade'],
                                                ) ??
                                                finalGrade;
                                        final answers =
                                            _extractPersistableAnswers(
                                          aiResult,
                                          correctionDetails,
                                        );

                                        await ExamApiService()
                                            .scanAndGradeSheet(
                                          qrCodeUuid: qrCodeUuid,
                                          grade: finalGrade,
                                          objectiveGrade: objectiveGrade,
                                          answers: answers,
                                          correctionDetails: correctionSummary,
                                          totalQuestions: totalQuestions,
                                          correctCount: correctCount,
                                          wrongCount: wrongCount,
                                          blankCount: blankCount,
                                          multipleCount: multipleCount,
                                          uncertainCount: uncertainCount,
                                          notDetectedCount: notDetectedCount,
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
                                  : Text(
                                      isFileDiagnosticSaveBlocked
                                          ? "Salvar bloqueado"
                                          : "Confirmar",
                                      style: const TextStyle(
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

    if (_currentState == ScannerState.scanningQR &&
        mounted &&
        (!kIsWeb || _hasStartedQrScanner)) {
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
            _buildQrCameraLayer()
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
        final needsWebQrStart = kIsWeb && !_hasStartedQrScanner;
        final qrInstruction = needsWebQrStart
            ? 'Toque em Iniciar camera para ler o QR Code dentro da tela.'
            : '1º Passo: Aponte para o QR Code';

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 24.w),
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      _qrScannerErrorMessage ?? qrInstruction,
                      style: TextStyle(
                        color: _qrScannerErrorMessage == null
                            ? Colors.white
                            : Colors.redAccent,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (kIsWeb && kOmrFileDiagnostic) ...[
                    SizedBox(height: 14.h),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 24.w),
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.45),
                        ),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _diagnosticQrUuidController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Cole o UUID extraido do QR',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          ElevatedButton.icon(
                            onPressed: _runFileQrDiagnostic,
                            icon: const Icon(PhosphorIcons.file_search),
                            label: const Text('Validar QR por arquivo'),
                          ),
                        ],
                      ),
                    ),
                  ] else if (needsWebQrStart) ...[
                    SizedBox(height: 14.h),
                    ElevatedButton.icon(
                      onPressed:
                          _isStartingQrScanner ? null : _startScannerSafely,
                      icon: _isStartingQrScanner
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(PhosphorIcons.camera),
                      label: Text(
                        _isStartingQrScanner
                            ? 'Iniciando...'
                            : 'Iniciar camera',
                      ),
                    ),
                  ],
                ],
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
        final webCameraReady = kIsWeb && _webCameraController.isStarted;
        final webCameraBusy = kIsWeb && _webCameraController.isStarting;
        final photoInstruction = kIsWeb
            ? (kOmrFileDiagnostic
                ? 'Selecione a imagem local do gabarito para o teste web.'
                : webCameraReady
                    ? 'Encaixe as 4 ancoras pretas dentro da linha verde'
                    : 'Toque em Iniciar camera para alinhar o gabarito dentro da mascara')
            : 'Encaixe as 4 ancoras pretas dentro da linha verde';

        if (kIsWeb) {
          _logSheetVisualState(
            'overlay gabarito/card visivel',
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            platformViewActive:
                !_usesWebDomOverlayFlow && _webPickedPreviewBytes == null,
            fullBlackCoverActive: false,
          );
        }

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
                      _webCameraController.errorMessage ?? photoInstruction,
                      style: TextStyle(
                        color: _webCameraController.errorMessage == null
                            ? Colors.white
                            : Colors.redAccent,
                        fontSize: 12.sp,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  if (kIsWeb)
                    Column(
                      children: [
                        if (kOmrFileDiagnostic)
                          ElevatedButton.icon(
                            onPressed: _isCapturingPhoto
                                ? null
                                : _pickPhotoFromGalleryFallback,
                            icon: const Icon(PhosphorIcons.image),
                            label: Text(
                              _isCapturingPhoto
                                  ? 'Processando...'
                                  : 'Selecionar imagem de gabarito',
                            ),
                          )
                        else if (!webCameraReady)
                          ElevatedButton.icon(
                            onPressed: webCameraBusy || _isCapturingPhoto
                                ? null
                                : _startPhotoCameraFromUserGesture,
                            icon: webCameraBusy
                                ? SizedBox(
                                    width: 18.w,
                                    height: 18.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(PhosphorIcons.camera),
                            label: Text(
                              _isCapturingPhoto
                                  ? 'Processando...'
                                  : webCameraBusy
                                      ? 'Iniciando...'
                                      : 'Iniciar camera',
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: _isCapturingPhoto
                                ? null
                                : _takePhotoAndSendToAI,
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
                        if (!kOmrFileDiagnostic) ...[
                          SizedBox(height: 14.h),
                          TextButton.icon(
                            onPressed: _isCapturingPhoto
                                ? null
                                : _pickPhotoFromGalleryFallback,
                            icon: const Icon(
                              PhosphorIcons.image,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Escolher da galeria (fallback)",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
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
