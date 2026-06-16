// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

html.DivElement? _qrPreviewOverlay;
html.VideoElement? _qrPreviewVideo;
html.MediaStream? _qrPreviewStream;
final List<StreamSubscription<html.Event>> _qrPreviewSubscriptions = [];

void scheduleQrPreviewRepair({String reason = ''}) {
  if (!kIsWeb) return;

  void runRepair(String step) {
    try {
      final repaired = _repairQrPreviewVideos();
      debugPrint(
        '[ExamScanner] QR web preview repair step=$step reason=$reason videos=$repaired',
      );
    } catch (error) {
      debugPrint('[ExamScanner] QR web preview repair failed: $error');
    }
  }

  runRepair('immediate');
  unawaited(Future<void>.delayed(
    const Duration(milliseconds: 150),
    () => runRepair('150ms'),
  ));
  unawaited(Future<void>.delayed(
    const Duration(milliseconds: 500),
    () => runRepair('500ms'),
  ));
  unawaited(Future<void>.delayed(
    const Duration(milliseconds: 1200),
    () => runRepair('1200ms'),
  ));
}

void showQrPreviewOverlay({String reason = ''}) {
  if (!kIsWeb) return;

  if (_qrPreviewOverlay != null && _qrPreviewStream?.active == true) {
    try {
      final attached = _attachQrPreviewOverlay(reason: '$reason/already-active');
      debugPrint(
        '[QR CAMERA WEB] overlay attach reason=$reason alreadyActive attached=$attached',
      );
    } catch (error) {
      debugPrint('[QR CAMERA WEB] overlay attach failed: $error');
    }
    return;
  }

  void runAttach(String step) {
    try {
      final attached = _attachQrPreviewOverlay(reason: '$reason/$step');
      debugPrint(
        '[QR CAMERA WEB] overlay attach step=$step reason=$reason attached=$attached',
      );
    } catch (error) {
      debugPrint('[QR CAMERA WEB] overlay attach failed: $error');
    }
  }

  runAttach('immediate');
  unawaited(Future<void>.delayed(
    const Duration(milliseconds: 150),
    () => runAttach('150ms'),
  ));
  unawaited(Future<void>.delayed(
    const Duration(milliseconds: 500),
    () => runAttach('500ms'),
  ));
  unawaited(Future<void>.delayed(
    const Duration(milliseconds: 1200),
    () => runAttach('1200ms'),
  ));
}

void hideQrPreviewOverlay({String reason = ''}) {
  if (!kIsWeb) return;

  for (final subscription in _qrPreviewSubscriptions) {
    unawaited(subscription.cancel());
  }
  _qrPreviewSubscriptions.clear();

  _qrPreviewVideo?.pause();
  _qrPreviewVideo?.srcObject = null;
  _qrPreviewVideo = null;
  _qrPreviewStream = null;

  _qrPreviewOverlay?.remove();
  _qrPreviewOverlay = null;

  debugPrint('[QR CAMERA WEB] overlay removed reason=$reason');
}

int _repairQrPreviewVideos() {
  final videos = html.document.querySelectorAll('video');
  var repaired = 0;

  for (final node in videos) {
    if (node is! html.VideoElement) continue;

    node
      ..autoplay = true
      ..muted = true
      ..defaultMuted = true
      ..controls = false
      ..setAttribute('autoplay', 'true')
      ..setAttribute('muted', 'true')
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');

    node.style
      ..display = 'block'
      ..visibility = 'visible'
      ..opacity = '1'
      ..width = '100%'
      ..height = '100%'
      ..minWidth = '1px'
      ..minHeight = '1px'
      ..objectFit = 'cover'
      ..backgroundColor = 'transparent';

    _repairPreviewAncestor(node.parent);
    _repairPreviewAncestor(node.parent?.parent);
    _repairPreviewAncestor(node.parent?.parent?.parent);

    if (node.paused) {
      unawaited(node.play().catchError((Object error) {
        debugPrint('[ExamScanner] QR web video.play repair failed: $error');
      }));
    }

    repaired += 1;
  }

  return repaired;
}

bool _attachQrPreviewOverlay({required String reason}) {
  final stream = _findActiveQrVideoStream();
  if (stream == null) {
    debugPrint('[QR CAMERA WEB] no MobileScanner video stream yet reason=$reason');
    return false;
  }

  if (_qrPreviewOverlay == null) {
    _createQrPreviewOverlay(reason: reason);
  }

  final video = _qrPreviewVideo;
  if (video == null) return false;

  if (!identical(_qrPreviewStream, stream)) {
    _qrPreviewStream = stream;
    _configureQrOverlayVideo(video);
    video.srcObject = stream;
    debugPrint('[QR CAMERA WEB] srcObject attached from MobileScanner reason=$reason');
  }

  _logQrOverlayVideoState(video, 'before-play/$reason');
  unawaited(video.play().then((_) {
    _logQrOverlayVideoState(video, 'after-play/$reason');
  }).catchError((Object error) {
    debugPrint('[QR CAMERA WEB] overlay video.play failed: $error');
  }));

  return true;
}

html.MediaStream? _findActiveQrVideoStream() {
  final videos = html.document.querySelectorAll('video');

  for (final node in videos) {
    if (node is! html.VideoElement) continue;

    _configureQrOverlayVideo(node);
    final srcObject = node.srcObject;
    if (srcObject is html.MediaStream && srcObject.active == true) {
      final tracks = srcObject.getVideoTracks();
      if (tracks.isNotEmpty) {
        debugPrint(
          '[QR CAMERA WEB] MobileScanner stream found '
          'videoWidth=${node.videoWidth} videoHeight=${node.videoHeight} '
          'tracks=${tracks.length}',
        );
        return srcObject;
      }
    }
  }

  return null;
}

void _createQrPreviewOverlay({required String reason}) {
  final body = html.document.body;
  if (body == null) return;

  hideQrPreviewOverlay(reason: 'replace/$reason');

  final overlay = html.DivElement()
    ..id = 'academyhub-qr-camera-overlay'
    ..style.position = 'fixed'
    ..style.left = '0'
    ..style.top = '0'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.width = '100vw'
    ..style.height = '100vh'
    ..style.backgroundColor = '#000'
    ..style.overflow = 'hidden'
    ..style.zIndex = '2147483646'
    ..style.touchAction = 'none'
    ..style.fontFamily = 'Arial, sans-serif';

  final video = html.VideoElement();
  _configureQrOverlayVideo(video);

  final frame = html.DivElement()
    ..style.position = 'absolute'
    ..style.left = '50%'
    ..style.top = '50%'
    ..style.transform = 'translate(-50%, -50%)'
    ..style.border = '3px solid #C8A2C8'
    ..style.borderRadius = '16px'
    ..style.boxSizing = 'border-box'
    ..style.boxShadow = '0 0 0 9999px rgba(0, 0, 0, 0.54)'
    ..style.zIndex = '2'
    ..style.pointerEvents = 'none';
  _applyQrFrameSize(frame);

  final statusText = html.DivElement()
    ..text = 'Aponte para o QR Code'
    ..style.position = 'absolute'
    ..style.left = '24px'
    ..style.right = '24px'
    ..style.bottom = 'calc(42px + env(safe-area-inset-bottom))'
    ..style.zIndex = '3'
    ..style.padding = '10px 14px'
    ..style.borderRadius = '18px'
    ..style.backgroundColor = 'rgba(0, 0, 0, 0.78)'
    ..style.color = '#fff'
    ..style.fontSize = '14px'
    ..style.fontWeight = '700'
    ..style.textAlign = 'center'
    ..style.lineHeight = '1.35';

  _qrPreviewSubscriptions.add(
    html.window.onResize.listen((_) => _applyQrFrameSize(frame)),
  );

  overlay.children.addAll([video, frame, statusText]);
  body.append(overlay);

  _qrPreviewOverlay = overlay;
  _qrPreviewVideo = video;

  debugPrint('[QR CAMERA WEB] overlay created reason=$reason');
}

void _configureQrOverlayVideo(html.VideoElement video) {
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

void _applyQrFrameSize(html.DivElement frame) {
  final viewportWidth = (html.window.innerWidth ?? 0).toDouble();
  final viewportHeight = (html.window.innerHeight ?? 0).toDouble();
  if (viewportWidth <= 0 || viewportHeight <= 0) return;

  final scanWindowSize = viewportWidth * 0.70;
  final maxSize = viewportHeight * 0.62;
  final size = scanWindowSize > maxSize ? maxSize : scanWindowSize;

  frame.style
    ..width = '${size}px'
    ..height = '${size}px';
}

void _logQrOverlayVideoState(html.VideoElement video, String reason) {
  final rect = video.getBoundingClientRect();
  debugPrint(
    '[QR CAMERA WEB] video=$reason '
    'videoWidth=${video.videoWidth} '
    'videoHeight=${video.videoHeight} '
    'readyState=${video.readyState} '
    'paused=${video.paused} '
    'rect=${rect.width}x${rect.height} '
    'display=${video.style.display} '
    'visibility=${video.style.visibility} '
    'opacity=${video.style.opacity}',
  );
}

void _repairPreviewAncestor(html.Element? element) {
  if (element == null) return;

  element.style
    ..display = 'block'
    ..visibility = 'visible'
    ..opacity = '1'
    ..width = '100%'
    ..height = '100%'
    ..minWidth = '1px'
    ..minHeight = '1px'
    ..overflow = 'hidden'
    ..backgroundColor = 'transparent';
}
