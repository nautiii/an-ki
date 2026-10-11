import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A test double for [MobileScannerPlatform] that never touches the camera.
///
/// It renders an empty placeholder instead of a live preview; its barcode
/// stream stays silent: tests call the scanner's `onDetect` themselves.
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
  Future<Set<CameraLensType>> getSupportedLenses({
    CameraFacing? facing,
  }) async => <CameraLensType>{CameraLensType.any};

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
