// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

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
