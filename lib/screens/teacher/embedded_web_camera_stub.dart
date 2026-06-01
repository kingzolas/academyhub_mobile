import 'dart:typed_data';

import 'package:flutter/widgets.dart';

class EmbeddedWebCameraController extends ChangeNotifier {
  bool get isSupported => false;
  bool get isStarted => false;
  bool get isStarting => false;
  bool get isSecureContext => false;
  bool get hasMediaDevices => false;
  bool get isIos => false;
  bool get isSafari => false;
  bool get shouldUseDomOverlay => false;
  String? get errorMessage => null;
  String? get statusMessage => null;
  String? get technicalError => null;

  Future<void> start() async {
    throw UnsupportedError('Camera web disponivel apenas no Flutter Web.');
  }

  Future<Uint8List> captureFrame() async {
    throw UnsupportedError('Camera web disponivel apenas no Flutter Web.');
  }

  Future<Uint8List?> captureWithDomOverlay({
    required bool isBubbleSheet,
    required String studentName,
  }) async {
    throw UnsupportedError('Camera web disponivel apenas no Flutter Web.');
  }

  void logHostSize({
    required double width,
    required double height,
    required String reason,
  }) {}

  Future<void> stop() async {}
}

Widget buildEmbeddedWebCameraView(
  EmbeddedWebCameraController controller,
) {
  return const SizedBox.shrink();
}
