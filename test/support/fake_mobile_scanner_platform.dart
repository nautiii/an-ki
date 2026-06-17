import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A test double for [MobileScannerPlatform] that never touches the camera.
///
/// It renders an empty placeholder instead of a live preview and lets tests
/// push barcode captures through [emit] without going through platform
/// channels (which are unavailable in unit tests).
class FakeMobileScannerPlatform extends MobileScannerPlatform {
  final StreamController<BarcodeCapture?> _barcodes =
      StreamController<BarcodeCapture?>.broadcast();

  int startCalls = 0;
  int stopCalls = 0;

  /// Installs this fake as the active platform implementation.
  static FakeMobileScannerPlatform install() {
    final fake = FakeMobileScannerPlatform();
    MobileScannerPlatform.instance = fake;
    return fake;
  }

  void emit(BarcodeCapture capture) => _barcodes.add(capture);

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => const Stream<TorchState>.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream<double>.empty();

  @override
  Widget buildCameraView() => const SizedBox.expand();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    startCalls++;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      numberOfCameras: 1,
      size: Size(1920, 1080),
    );
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {
    await _barcodes.close();
  }

  @override
  Future<Set<CameraLensType>> getSupportedLenses() async => <CameraLensType>{
    CameraLensType.any,
  };

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> setZoomScale(double zoomScale) async {}

  @override
  Future<void> resetZoomScale() async {}

  @override
  Future<void> setFocusPoint(Offset position) async {}

  @override
  Future<void> toggleTorch() async {}
}
