import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// ─── Detection result emitted each processing cycle ───────────────────────────

class DetectionResult {
  /// A face is visible in frame.
  final bool faceFound;

  /// Head Euler Y within ±15° (facing camera).
  final bool facingCamera;

  /// Both eye-open probabilities ≥ 0.65.
  final bool eyesOpen;

  /// Smile probability from ML Kit (0–1).
  final double smileProbability;

  /// Wave motion detected by frame-differencing tracker.
  final bool waving;

  /// Mean pixel-luminance difference (0–1), for debug overlay.
  final double motionLevel;

  /// Composite eye-contact signal.
  bool get eyeContact => faceFound && facingCamera && eyesOpen;

  /// Smile threshold met.
  bool get smiling => smileProbability >= 0.70;

  const DetectionResult({
    required this.faceFound,
    required this.facingCamera,
    required this.eyesOpen,
    required this.smileProbability,
    required this.waving,
    required this.motionLevel,
  });

  static const DetectionResult empty = DetectionResult(
    faceFound: false,
    facingCamera: false,
    eyesOpen: false,
    smileProbability: 0,
    waving: false,
    motionLevel: 0,
  );
}

// ─── Wave gesture tracker ─────────────────────────────────────────────────────

class _WaveTracker {
  static const int _minReversals = 2;
  static const int _windowMs = 2500;
  static const double _minShift = 0.04;

  final _timestamps = <int>[];
  final _centroids = <double>[];
  int _reversals = 0;
  int? _lastDir;

  void update(double centroidX, int tsMs) {
    _centroids.add(centroidX);
    _timestamps.add(tsMs);

    final cutoff = tsMs - _windowMs;
    while (_timestamps.isNotEmpty && _timestamps.first < cutoff) {
      _timestamps.removeAt(0);
      _centroids.removeAt(0);
    }

    if (_centroids.length >= 2) {
      final delta = _centroids.last - _centroids[_centroids.length - 2];
      if (delta.abs() >= _minShift) {
        final dir = delta > 0 ? 1 : -1;
        if (_lastDir != null && dir != _lastDir) _reversals++;
        _lastDir = dir;
      }
    }

    if (_timestamps.length <= 1) _reversals = 0;
  }

  bool get isWaving => _reversals >= _minReversals;

  void reset() {
    _centroids.clear();
    _timestamps.clear();
    _reversals = 0;
    _lastDir = null;
  }
}

// ─── Main detection service ───────────────────────────────────────────────────

class SocialDetectionService {
  SocialDetectionService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  late final FaceDetector _faceDetector;
  final _waveTracker = _WaveTracker();

  final _controller = StreamController<DetectionResult>.broadcast();
  Stream<DetectionResult> get results => _controller.stream;

  // Tiny luma grid for frame differencing
  static const int _lumaW = 20;
  static const int _lumaH = 15;
  Uint8List? _prevLuma;

  // Throttle
  static const int _intervalMs = 120;
  int _lastMs = 0;
  bool _busy = false;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Feed every camera image from [CameraController.startImageStream].
  void processFrame(CameraImage image, InputImageRotation rotation) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_busy || now - _lastMs < _intervalMs) return;
    _busy = true;
    _lastMs = now;
    _process(image, rotation, now).whenComplete(() => _busy = false);
  }

  /// Reset wave tracker when moving to a new level.
  void resetWave() => _waveTracker.reset();

  /// Dispose detector and stream. Call in screen's dispose().
  Future<void> dispose() async {
    await _faceDetector.close();
    await _controller.close();
  }

  // ── Processing ────────────────────────────────────────────────────────────

  Future<void> _process(
      CameraImage image, InputImageRotation rotation, int tsMs) async {
    try {
      final inputImage = _toInputImage(image, rotation);
      if (inputImage == null) { 
        debugPrint('[Social Detection] InputImage is null!');
        _emit(DetectionResult.empty); 
        return; 
      }

      final faces = await _faceDetector.processImage(inputImage);
      //debugPrint('[Social Detection] processed frame. Found ${faces.length} faces.');

      bool faceFound = faces.isNotEmpty;
      bool facingCamera = false;
      bool eyesOpen = false;
      double smileProb = 0.0;

      Face? mainFace;
      if (faceFound) {
        mainFace = faces.reduce((a, b) =>
            a.boundingBox.width * a.boundingBox.height >
                    b.boundingBox.width * b.boundingBox.height
                ? a : b);

        final eulerY = mainFace.headEulerAngleY ?? 90.0;
        facingCamera = eulerY.abs() < 15.0;

        final lo = mainFace.leftEyeOpenProbability ?? 0.0;
        final ro = mainFace.rightEyeOpenProbability ?? 0.0;
        eyesOpen = lo >= 0.65 && ro >= 0.65;

        smileProb = mainFace.smilingProbability ?? 0.0;
      }

      final (motionLevel, centroidX) = _computeMotion(image, mainFace);
      bool waving = false;
      // Since we now threshold absolute noise, overall motionLevel is much lower
      if (motionLevel > 0.005) {
        _waveTracker.update(centroidX, tsMs);
        waving = _waveTracker.isWaving;
      }

      _emit(DetectionResult(
        faceFound: faceFound,
        facingCamera: facingCamera,
        eyesOpen: eyesOpen,
        smileProbability: smileProb,
        waving: waving,
        motionLevel: motionLevel,
      ));
    } catch (e, stack) {
      debugPrint('[Social Detection] EXCEPTION in _process: $e\n$stack');
      _emit(DetectionResult.empty);
    }
  }

  // ── Frame differencing ────────────────────────────────────────────────────

  (double, double) _computeMotion(CameraImage image, Face? mainFace) {
    try {
      final luma = _extractLuma(image);
      if (luma == null) return (0.0, 0.5);
      if (_prevLuma == null || _prevLuma!.length != luma.length) {
        _prevLuma = luma;
        return (0.0, 0.5);
      }

      double sum = 0.0;
      double weightedX = 0.0;
      double totalWeight = 0.0;

      // ── Map face bounding box to luma grid to ignore face motion ──
      int minFgy = _lumaH, maxFgy = -1;
      int minFgx = _lumaW, maxFgx = -1;

      if (mainFace != null) {
        final r = mainFace.boundingBox;
        minFgx = (r.left / image.width * _lumaW).floor().clamp(0, _lumaW - 1);
        maxFgx = (r.right / image.width * _lumaW).ceil().clamp(0, _lumaW - 1);
        minFgy = (r.top / image.height * _lumaH).floor().clamp(0, _lumaH - 1);
        maxFgy = (r.bottom / image.height * _lumaH).ceil().clamp(0, _lumaH - 1);
      }

      for (int y = 0; y < _lumaH; y++) {
        for (int x = 0; x < _lumaW; x++) {
          // Skip pixels that fall inside the mapped face bounding box
          if (x >= minFgx && x <= maxFgx && y >= minFgy && y <= maxFgy) {
            continue;
          }

          final i = y * _lumaW + x;
          final d = (_prevLuma![i] - luma[i]).abs().toDouble();
          
          // Ignore small pixel value changes (camera sensor noise)
          // Otherwise, noise will pull the centroid towards the center (0.5)
          if (d < 15.0) continue;

          sum += d;
          weightedX += x * d;
          totalWeight += d;
        }
      }

      _prevLuma = luma;
      final mean = sum / (_lumaW * _lumaH * 255.0);
      final cx = totalWeight > 0 ? weightedX / (totalWeight * _lumaW) : 0.5;
      return (mean, cx);
    } catch (e) {
      debugPrint('[Social Detection] EXCEPTION in _computeMotion: $e');
      return (0.0, 0.5);
    }
  }

  Uint8List? _extractLuma(CameraImage image) {
    try {
      Uint8List rawY;
      int srcW, srcH, rowStride;

      if (image.format.group == ImageFormatGroup.yuv420 || image.format.group == ImageFormatGroup.nv21) {
        final plane = image.planes[0];
        rawY = plane.bytes;
        srcW = image.width;
        srcH = image.height;
        rowStride = plane.bytesPerRow;
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        final plane = image.planes[0];
        srcW = image.width;
        srcH = image.height;
        rowStride = plane.bytesPerRow;
        rawY = Uint8List(srcW * srcH);
        for (int r = 0; r < srcH; r++) {
          for (int c = 0; c < srcW; c++) {
            // BGRA: extract G channel as luminance proxy
            rawY[r * srcW + c] = plane.bytes[r * rowStride + c * 4 + 1];
          }
        }
      } else {
        return null;
      }

      final out = Uint8List(_lumaW * _lumaH);
      final xStep = srcW / _lumaW;
      final yStep = srcH / _lumaH;
      for (int gy = 0; gy < _lumaH; gy++) {
        for (int gx = 0; gx < _lumaW; gx++) {
          final sx = (gx * xStep).toInt().clamp(0, srcW - 1);
          final sy = (gy * yStep).toInt().clamp(0, srcH - 1);
          final idx = sy * rowStride + sx;
          if (idx < rawY.length) out[gy * _lumaW + gx] = rawY[idx];
        }
      }
      return out;
    } catch (e) {
      debugPrint('[Social Detection] EXCEPTION in _extractLuma: $e');
      return null;
    }
  }

  // ── InputImage conversion ─────────────────────────────────────────────────

  InputImage? _toInputImage(CameraImage image, InputImageRotation rotation) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      
      final InputImageMetadata metadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: image.format.group == ImageFormatGroup.bgra8888 
            ? InputImageFormat.bgra8888 
            : InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('[Social Detection] EXCEPTION in _toInputImage: $e');
      return null;
    }
  }

  void _emit(DetectionResult r) {
    if (!_controller.isClosed) _controller.add(r);
  }
}
