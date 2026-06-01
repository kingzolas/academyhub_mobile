// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class EmbeddedWebCameraController extends ChangeNotifier {
  EmbeddedWebCameraController()
      : _viewType =
            'academyhub-scanner-camera-${DateTime.now().microsecondsSinceEpoch}' {
    _videoElement = html.VideoElement();
    _configureVideoElement(_videoElement);

    _rootElement = html.DivElement()
      ..style.position = 'relative'
      ..style.display = 'block'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.minWidth = '1px'
      ..style.minHeight = '1px'
      ..style.overflow = 'hidden'
      ..style.backgroundColor = 'transparent'
      ..style.opacity = '1'
      ..style.visibility = 'visible';

    _rootElement.children.add(_videoElement);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId, {Object? params}) => _rootElement,
    );
  }

  late final String _viewType;
  late final html.DivElement _rootElement;
  late final html.VideoElement _videoElement;
  html.MediaStream? _stream;
  html.MediaStream? _domOverlayStream;
  html.DivElement? _activeDomOverlay;
  Completer<Uint8List?>? _domOverlayCompleter;
  final List<StreamSubscription<html.Event>> _domOverlaySubscriptions = [];
  DateTime? _lastHostSizeLogAt;

  bool _isStarting = false;
  bool _isStarted = false;
  bool _isDomOverlayCapturing = false;
  String? _errorMessage;
  String? _statusMessage;
  String? _technicalError;

  String get viewType => _viewType;
  bool get isSupported => true;
  bool get isStarting => _isStarting;
  bool get isStarted => _isStarted;
  bool get shouldUseDomOverlay => isIos;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  String? get technicalError => _technicalError;

  bool get isSecureContext {
    final location = html.window.location;
    final hostname = location.hostname;
    return html.window.isSecureContext == true ||
        location.protocol == 'https:' ||
        hostname == 'localhost' ||
        hostname == '127.0.0.1' ||
        hostname == '[::1]' ||
        hostname == '::1';
  }

  bool get hasMediaDevices => html.window.navigator.mediaDevices != null;

  bool get isIos {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final platform = html.window.navigator.platform?.toLowerCase() ?? '';
    return userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod') ||
        (platform.contains('mac') &&
            html.window.navigator.maxTouchPoints != null &&
            html.window.navigator.maxTouchPoints! > 1);
  }

  bool get isSafari {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('safari') &&
        !userAgent.contains('chrome') &&
        !userAgent.contains('crios') &&
        !userAgent.contains('fxios') &&
        !userAgent.contains('edgios');
  }

  Future<void> start() async {
    if (_isStarting || _isStarted) return;

    _isStarting = true;
    _errorMessage = null;
    _technicalError = null;
    _statusMessage = 'Iniciando camera...';
    notifyListeners();

    _logEnvironment();

    html.MediaStream? stream;
    try {
      stream = await _requestCameraStream(logPrefix: 'GABARITO');
      await _attachStreamToVideo(
        video: _videoElement,
        stream: stream,
        reason: 'GABARITO/flutter-preview',
        rootElement: _rootElement,
        requireVisibleFrame: false,
      );

      _stream = stream;
      _isStarted = true;
      _isStarting = false;
      _statusMessage = null;
      _errorMessage = null;
      _technicalError = null;
      debugPrint(
        '[ExamScannerWebCamera] GABARITO: overlay/preview exibido via HtmlElementView.',
      );
      notifyListeners();
    } on _CameraStartFailure catch (failure) {
      if (stream != null) _stopStream(stream);
      _finishWithError(failure.userMessage, failure.technicalError);
    } catch (error, stackTrace) {
      if (stream != null) _stopStream(stream);
      _finishWithError(
        _friendlyErrorMessage(error),
        '$error\n$stackTrace',
      );
    }
  }

  Future<Uint8List?> captureWithDomOverlay({
    required bool isBubbleSheet,
    required String studentName,
  }) {
    final existingCompleter = _domOverlayCompleter;
    if (existingCompleter != null) return existingCompleter.future;

    debugPrint(
        '[ExamScannerWebCamera] GABARITO: usando camera embutida web/iOS.');
    _logEnvironment();

    final body = html.document.body;
    if (body == null) {
      return Future<Uint8List?>.error(
        StateError('Documento HTML sem body para exibir a camera.'),
      );
    }

    final completer = Completer<Uint8List?>();
    _domOverlayCompleter = completer;
    _isStarting = true;
    _isStarted = false;
    _isDomOverlayCapturing = false;
    _errorMessage = null;
    _technicalError = null;
    _statusMessage = 'Iniciando camera...';
    notifyListeners();

    final overlay = _createDomOverlay(
      isBubbleSheet: isBubbleSheet,
      studentName: studentName,
    );
    _activeDomOverlay = overlay.root;
    body.append(overlay.root);
    debugPrint('[ExamScannerWebCamera] GABARITO: overlay DOM criado.');

    _domOverlaySubscriptions.add(
      html.window.onResize.listen((_) {
        _applyDomOverlayMaskSize(
          overlay.frame,
          isBubbleSheet: isBubbleSheet,
        );
      }),
    );
    _domOverlaySubscriptions.add(
      overlay.cancelButton.onClick.listen((event) {
        event.preventDefault();
        debugPrint('[ExamScannerWebCamera] GABARITO: captura cancelada.');
        _completeDomOverlay(null);
      }),
    );
    _domOverlaySubscriptions.add(
      overlay.captureButton.onClick.listen((event) async {
        event.preventDefault();
        await _captureDomOverlayFrame(overlay);
      }),
    );

    unawaited(_startDomOverlayCamera(overlay));
    return completer.future;
  }

  Future<Uint8List> captureFrame() async {
    if (!_isStarted || _stream == null) {
      throw StateError('Camera web nao iniciada.');
    }

    final bytes = await _captureFrameFromVideo(_videoElement);
    debugPrint('[ExamScannerWebCamera] GABARITO: captura realizada.');
    return bytes;
  }

  Future<void> stop() async {
    _completeDomOverlay(null);

    final stream = _stream;
    if (stream != null) {
      _stopStream(stream);
    }

    _stream = null;
    _videoElement.pause();
    _videoElement.srcObject = null;
    _isStarting = false;
    _isStarted = false;
    _statusMessage = null;
    notifyListeners();
  }

  void _stopStream(html.MediaStream stream) {
    for (final track in stream.getTracks()) {
      track.stop();
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }

  Future<html.MediaStream> _requestCameraStream({
    required String logPrefix,
  }) async {
    if (!isSecureContext) {
      throw _CameraStartFailure(
        'Abra esta pagina em HTTPS para permitir o uso da camera.',
        'Contexto inseguro: ${html.window.location.href}',
      );
    }

    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      throw const _CameraStartFailure(
        'Camera indisponivel neste navegador. Use Safari/Chrome atualizado em HTTPS.',
        'navigator.mediaDevices nao existe neste contexto.',
      );
    }

    const attempts = <_CameraAttempt>[
      _CameraAttempt(
        label: 'camera traseira ideal',
        constraints: {
          'audio': false,
          'video': {
            'facingMode': {'ideal': 'environment'},
            'width': {'ideal': 1920},
            'height': {'ideal': 1080},
          },
        },
      ),
      _CameraAttempt(
        label: 'camera traseira',
        userMessage:
            'Nao encontramos a camera traseira. Tentando camera disponivel.',
        constraints: {
          'audio': false,
          'video': {'facingMode': 'environment'},
        },
      ),
      _CameraAttempt(
        label: 'qualquer camera',
        constraints: {
          'audio': false,
          'video': true,
        },
      ),
    ];

    Object? lastError;
    StackTrace? lastStackTrace;

    for (final attempt in attempts) {
      html.MediaStream? attemptedStream;

      try {
        if (attempt.userMessage != null) {
          _statusMessage = attempt.userMessage;
          notifyListeners();
        }

        debugPrint(
          '[ExamScannerWebCamera] $logPrefix: getUserMedia chamado '
          '(${attempt.label}) constraints=${jsonEncode(attempt.constraints)}',
        );

        attemptedStream = await mediaDevices.getUserMedia(attempt.constraints);
        _logStreamDetails(attemptedStream, '$logPrefix/${attempt.label}');
        return attemptedStream;
      } catch (error, stackTrace) {
        if (attemptedStream != null) {
          _stopStream(attemptedStream);
        }

        lastError = error;
        lastStackTrace = stackTrace;
        debugPrint(
          '[ExamScannerWebCamera] $logPrefix: falha em ${attempt.label}: $error',
        );
      }
    }

    throw _CameraStartFailure(
      _friendlyErrorMessage(lastError),
      '$lastError\n$lastStackTrace',
    );
  }

  Future<void> _attachStreamToVideo({
    required html.VideoElement video,
    required html.MediaStream stream,
    required String reason,
    required html.Element rootElement,
    required bool requireVisibleFrame,
  }) async {
    _configureVideoElement(video);

    video.onLoadedMetadata.first.then((_) {
      _logVideoState(video, rootElement, 'loadedmetadata/$reason');
    });
    video.onCanPlay.first.then((_) {
      _logVideoState(video, rootElement, 'canplay/$reason');
    });

    video.srcObject = stream;

    try {
      await video.play();
      debugPrint('[ExamScannerWebCamera] GABARITO: video.play ok ($reason).');
    } catch (error, stackTrace) {
      throw _CameraStartFailure(
        'A camera foi autorizada, mas a previa nao pode ser exibida. Tente recarregar a pagina ou abrir no Safari.',
        'video.play falhou ($reason): $error\n$stackTrace',
      );
    }

    final hasFrame = await _waitForVideoFrame(video);
    _logVideoState(video, rootElement, 'after-play/$reason');

    if (!hasFrame) {
      final technicalError =
          'Stream ativo, mas videoWidth/videoHeight ficaram 0 apos aguardar frames. reason=$reason';
      debugPrint('[ExamScannerWebCamera] $technicalError');

      if (requireVisibleFrame) {
        throw _CameraStartFailure(
          'A camera foi autorizada, mas a previa nao pode ser exibida. Tente recarregar a pagina ou abrir no Safari.',
          technicalError,
        );
      }

      _errorMessage =
          'A camera foi autorizada, mas a previa nao pode ser exibida. Tente recarregar a pagina ou abrir no Safari.';
      _technicalError = technicalError;
    }
  }

  Future<void> _startDomOverlayCamera(_DomCameraOverlay overlay) async {
    html.MediaStream? stream;

    try {
      stream = await _requestCameraStream(logPrefix: 'GABARITO');
      _domOverlayStream = stream;

      await _attachStreamToVideo(
        video: overlay.video,
        stream: stream,
        reason: 'GABARITO/dom-overlay',
        rootElement: overlay.root,
        requireVisibleFrame: true,
      );

      overlay.statusText.text =
          'Alinhe as quatro ancoras dentro da mascara e toque em Capturar.';
      overlay.captureButton.disabled = false;
      _isStarting = false;
      _isStarted = true;
      _statusMessage = null;
      _errorMessage = null;
      _technicalError = null;
      debugPrint('[ExamScannerWebCamera] GABARITO: overlay/preview exibido.');
      notifyListeners();
    } on _CameraStartFailure catch (failure) {
      if (stream != null) _stopStream(stream);
      _domOverlayStream = null;
      _showDomOverlayError(overlay, failure);
    } catch (error, stackTrace) {
      if (stream != null) _stopStream(stream);
      _domOverlayStream = null;
      _showDomOverlayError(
        overlay,
        _CameraStartFailure(
          _friendlyErrorMessage(error),
          '$error\n$stackTrace',
        ),
      );
    }
  }

  Future<void> _captureDomOverlayFrame(_DomCameraOverlay overlay) async {
    if (_isDomOverlayCapturing || !_isStarted) return;

    debugPrint('[ExamScannerWebCamera] GABARITO: botao Capturar clicado.');
    _isDomOverlayCapturing = true;
    overlay.captureButton.disabled = true;
    overlay.statusText.text = 'Capturando imagem...';

    try {
      final bytes = await _captureFrameFromVideo(overlay.video);
      debugPrint('[ExamScannerWebCamera] GABARITO: captura realizada.');
      _completeDomOverlay(bytes);
    } catch (error, stackTrace) {
      _isDomOverlayCapturing = false;
      overlay.captureButton.disabled = false;
      overlay.statusText.text =
          'Nao foi possivel capturar a imagem. Ajuste o gabarito e tente novamente.';
      _technicalError = '$error\n$stackTrace';
      debugPrint(
        '[ExamScannerWebCamera] GABARITO: erro ao capturar overlay: $error',
      );
      notifyListeners();
    }
  }

  Future<Uint8List> _captureFrameFromVideo(html.VideoElement video) async {
    final hasFrame = await _waitForVideoFrame(video);
    if (!hasFrame) {
      throw StateError(
        'A camera foi autorizada, mas a previa nao possui frame visivel.',
      );
    }

    final width = video.videoWidth;
    final height = video.videoHeight;
    debugPrint(
      '[ExamScannerWebCamera] GABARITO: videoWidth/videoHeight=${width}x$height',
    );

    final canvas = html.CanvasElement(width: width, height: height);
    canvas.context2D.drawImageScaled(video, 0, 0, width, height);
    debugPrint('[ExamScannerWebCamera] GABARITO: canvas recebeu frame.');

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.92);
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex == -1) {
      throw StateError('Nao foi possivel capturar o frame da camera.');
    }

    final bytes = base64Decode(dataUrl.substring(commaIndex + 1));
    debugPrint(
      '[ExamScannerWebCamera] GABARITO: bytes/base64 gerados. '
      'tamanho=${bytes.length} bytes',
    );
    return bytes;
  }

  Future<bool> _waitForVideoFrame(html.VideoElement video) async {
    for (var i = 0; i < 30; i++) {
      if (video.videoWidth > 0 &&
          video.videoHeight > 0 &&
          video.readyState >= html.MediaElement.HAVE_CURRENT_DATA) {
        return true;
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    return false;
  }

  void _configureVideoElement(html.VideoElement video) {
    video
      ..autoplay = true
      ..muted = true
      ..defaultMuted = true
      ..controls = false
      ..setAttribute('autoplay', 'true')
      ..setAttribute('muted', 'true')
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');

    video.style
      ..position = 'absolute'
      ..top = '0'
      ..left = '0'
      ..width = '100%'
      ..height = '100%'
      ..minWidth = '1px'
      ..minHeight = '1px'
      ..objectFit = 'cover'
      ..backgroundColor = 'transparent'
      ..opacity = '1'
      ..visibility = 'visible'
      ..display = 'block'
      ..zIndex = '0'
      ..pointerEvents = 'none';
  }

  _DomCameraOverlay _createDomOverlay({
    required bool isBubbleSheet,
    required String studentName,
  }) {
    final root = html.DivElement()
      ..id = 'academyhub-sheet-camera-overlay'
      ..style.position = 'fixed'
      ..style.left = '0'
      ..style.top = '0'
      ..style.right = '0'
      ..style.bottom = '0'
      ..style.width = '100vw'
      ..style.height = '100vh'
      ..style.backgroundColor = '#000'
      ..style.overflow = 'hidden'
      ..style.zIndex = '2147483647'
      ..style.touchAction = 'none'
      ..style.fontFamily = 'Arial, sans-serif';

    final video = html.VideoElement();
    _configureVideoElement(video);

    final topLabel = html.DivElement()
      ..text = studentName.isEmpty
          ? 'Aluno identificado'
          : 'Aluno identificado: ${studentName.toUpperCase()}'
      ..style.position = 'absolute'
      ..style.left = '16px'
      ..style.right = '16px'
      ..style.top = 'calc(34px + env(safe-area-inset-top))'
      ..style.zIndex = '3'
      ..style.padding = '10px 14px'
      ..style.borderRadius = '14px'
      ..style.backgroundColor = 'rgba(0, 0, 0, 0.72)'
      ..style.color = '#fff'
      ..style.fontSize = '14px'
      ..style.fontWeight = '700'
      ..style.textAlign = 'center'
      ..style.letterSpacing = '0';

    final frame = html.DivElement()
      ..style.position = 'absolute'
      ..style.left = '50%'
      ..style.top = '50%'
      ..style.transform = 'translate(-50%, -50%)'
      ..style.border = '3px solid #4DFF91'
      ..style.borderRadius = '8px'
      ..style.boxSizing = 'border-box'
      ..style.boxShadow = '0 0 0 9999px rgba(0, 0, 0, 0.68)'
      ..style.zIndex = '2'
      ..style.pointerEvents = 'none';
    _applyDomOverlayMaskSize(frame, isBubbleSheet: isBubbleSheet);

    final statusText = html.DivElement()
      ..text = 'Iniciando camera...'
      ..style.position = 'absolute'
      ..style.left = '18px'
      ..style.right = '18px'
      ..style.bottom = 'calc(116px + env(safe-area-inset-bottom))'
      ..style.zIndex = '3'
      ..style.padding = '9px 12px'
      ..style.borderRadius = '14px'
      ..style.backgroundColor = 'rgba(0, 0, 0, 0.76)'
      ..style.color = '#fff'
      ..style.fontSize = '13px'
      ..style.fontWeight = '600'
      ..style.textAlign = 'center'
      ..style.lineHeight = '1.35';

    final controls = html.DivElement()
      ..style.position = 'absolute'
      ..style.left = '16px'
      ..style.right = '16px'
      ..style.bottom = 'calc(28px + env(safe-area-inset-bottom))'
      ..style.zIndex = '3'
      ..style.display = 'flex'
      ..style.justifyContent = 'center'
      ..style.alignItems = 'center'
      ..style.gap = '12px';

    final cancelButton = _createOverlayButton(
      label: 'Cancelar',
      backgroundColor: 'rgba(255, 255, 255, 0.16)',
      textColor: '#fff',
    );
    final captureButton = _createOverlayButton(
      label: 'Capturar',
      backgroundColor: '#fff',
      textColor: '#000',
    )..disabled = true;

    controls.children.addAll([cancelButton, captureButton]);
    root.children.addAll([video, topLabel, frame, statusText, controls]);

    return _DomCameraOverlay(
      root: root,
      video: video,
      frame: frame,
      statusText: statusText,
      captureButton: captureButton,
      cancelButton: cancelButton,
    );
  }

  html.ButtonElement _createOverlayButton({
    required String label,
    required String backgroundColor,
    required String textColor,
  }) {
    return html.ButtonElement()
      ..type = 'button'
      ..text = label
      ..style.minWidth = '124px'
      ..style.height = '52px'
      ..style.border = '0'
      ..style.borderRadius = '26px'
      ..style.backgroundColor = backgroundColor
      ..style.color = textColor
      ..style.fontSize = '16px'
      ..style.fontWeight = '800'
      ..style.letterSpacing = '0'
      ..style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.35)';
  }

  void _applyDomOverlayMaskSize(
    html.DivElement frame, {
    required bool isBubbleSheet,
  }) {
    final viewportWidth = (html.window.innerWidth ?? 0).toDouble();
    final viewportHeight = (html.window.innerHeight ?? 0).toDouble();
    if (viewportWidth <= 0 || viewportHeight <= 0) return;

    final boxWidth =
        isBubbleSheet ? viewportWidth * 0.85 : viewportWidth * 0.90;
    final boxHeight = isBubbleSheet ? boxWidth * 1.05 : boxWidth * 0.55;

    frame.style
      ..width = '${boxWidth}px'
      ..height = '${boxHeight}px';
  }

  void _showDomOverlayError(
    _DomCameraOverlay overlay,
    _CameraStartFailure failure,
  ) {
    _isStarting = false;
    _isStarted = false;
    _errorMessage = failure.userMessage;
    _technicalError = failure.technicalError;
    _statusMessage = null;
    overlay.statusText.text = failure.userMessage;
    overlay.statusText.style.color = '#ffb3b3';
    overlay.captureButton.disabled = true;
    debugPrint('[ExamScannerWebCamera] ${failure.technicalError}');
    notifyListeners();
  }

  void _completeDomOverlay(Uint8List? bytes) {
    final completer = _domOverlayCompleter;
    if (completer == null) return;

    if (bytes != null) {
      debugPrint('[ExamScannerWebCamera] GABARITO: imagem enviada ao Flutter.');
    }
    _cleanupDomOverlay();
    if (!completer.isCompleted) {
      completer.complete(bytes);
    }
  }

  void _cleanupDomOverlay() {
    for (final subscription in _domOverlaySubscriptions) {
      unawaited(subscription.cancel());
    }
    _domOverlaySubscriptions.clear();

    final stream = _domOverlayStream;
    if (stream != null) {
      _stopStream(stream);
      debugPrint('[ExamScannerWebCamera] GABARITO: tracks encerradas.');
    }
    _domOverlayStream = null;

    if (_activeDomOverlay != null) {
      _activeDomOverlay?.remove();
      debugPrint('[ExamScannerWebCamera] GABARITO: overlay removido.');
    }
    _activeDomOverlay = null;
    _domOverlayCompleter = null;
    _isStarting = false;
    _isStarted = false;
    _isDomOverlayCapturing = false;
    _statusMessage = null;
    notifyListeners();
  }

  void _finishWithError(String userMessage, String technicalError) {
    _isStarting = false;
    _isStarted = false;
    _statusMessage = null;
    _errorMessage = userMessage;
    _technicalError = technicalError;
    debugPrint('[ExamScannerWebCamera] $technicalError');
    notifyListeners();
  }

  String _friendlyErrorMessage(Object? error) {
    final text = error?.toString().toLowerCase() ?? '';

    if (text.contains('notallowed') ||
        text.contains('permission') ||
        text.contains('denied')) {
      return 'Nao foi possivel acessar a camera. Verifique a permissao da camera no Safari/iPhone.';
    }

    if (text.contains('notfound') ||
        text.contains('devicesnotfound') ||
        text.contains('overconstrained')) {
      return 'Nao encontramos a camera traseira. Tente novamente ou use o upload como alternativa.';
    }

    if (!isSecureContext) {
      return 'Abra esta pagina em HTTPS para permitir o uso da camera.';
    }

    if (!hasMediaDevices) {
      return 'Camera indisponivel neste navegador. Use Safari/Chrome atualizado em HTTPS.';
    }

    return 'Nao foi possivel acessar a camera. Verifique a permissao da camera no Safari/iPhone.';
  }

  void _logEnvironment() {
    debugPrint(
      '[ExamScannerWebCamera] GABARITO: plataforma=web '
      'isIos=$isIos '
      'isSafari=$isSafari '
      'secureContext=$isSecureContext '
      'mediaDevices=$hasMediaDevices '
      'url=${html.window.location.href} '
      'userAgent=${html.window.navigator.userAgent}',
    );
  }

  void _logStreamDetails(html.MediaStream stream, String reason) {
    final tracks = stream.getVideoTracks();
    debugPrint(
      '[ExamScannerWebCamera] GABARITO: stream recebido ($reason) '
      'active=${stream.active} tracks de video: ${tracks.length}',
    );

    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      debugPrint(
        '[ExamScannerWebCamera] GABARITO: track[$i] label="${track.label}" '
        'enabled=${track.enabled} muted=${track.muted} '
        'readyState=${track.readyState}',
      );
    }
  }

  void _logVideoState(
    html.VideoElement video,
    html.Element rootElement,
    String reason,
  ) {
    final rect = video.getBoundingClientRect();
    final rootRect = rootElement.getBoundingClientRect();
    debugPrint(
      '[ExamScannerWebCamera] GABARITO: video=$reason '
      'videoWidth=${video.videoWidth} '
      'videoHeight=${video.videoHeight} '
      'readyState=${video.readyState} '
      'paused=${video.paused} '
      'videoRect=${rect.width}x${rect.height} '
      'rootRect=${rootRect.width}x${rootRect.height} '
      'display=${video.style.display} '
      'visibility=${video.style.visibility} '
      'opacity=${video.style.opacity}',
    );
  }

  void logHostSize({
    required double width,
    required double height,
    required String reason,
  }) {
    final now = DateTime.now();
    if (_lastHostSizeLogAt != null &&
        now.difference(_lastHostSizeLogAt!) < const Duration(seconds: 2)) {
      return;
    }

    _lastHostSizeLogAt = now;
    debugPrint(
      '[ExamScannerWebCamera] Flutter host $reason size=${width}x$height',
    );
  }
}

Widget buildEmbeddedWebCameraView(
  EmbeddedWebCameraController controller,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      controller.logHostSize(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        reason: 'embedded-preview',
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF000000)),
          Positioned.fill(
            child: HtmlElementView(viewType: controller.viewType),
          ),
        ],
      );
    },
  );
}

class _DomCameraOverlay {
  const _DomCameraOverlay({
    required this.root,
    required this.video,
    required this.frame,
    required this.statusText,
    required this.captureButton,
    required this.cancelButton,
  });

  final html.DivElement root;
  final html.VideoElement video;
  final html.DivElement frame;
  final html.DivElement statusText;
  final html.ButtonElement captureButton;
  final html.ButtonElement cancelButton;
}

class _CameraAttempt {
  const _CameraAttempt({
    required this.label,
    required this.constraints,
    this.userMessage,
  });

  final String label;
  final Map<String, Object?> constraints;
  final String? userMessage;
}

class _CameraStartFailure implements Exception {
  const _CameraStartFailure(this.userMessage, this.technicalError);

  final String userMessage;
  final String technicalError;

  @override
  String toString() => technicalError;
}
