import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:handicraft_app/data/business_database.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({
    super.key,
    required this.cameras,
    required this.repository,
    required this.onInventoryChanged,
  });

  final List<CameraDescription> cameras;
  final BusinessRepository repository;
  final Future<void> Function() onInventoryChanged;

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  CameraController? _controller;
  YoloModel? _model;
  List<Detection> _detections = [];
  Size? _imageSize;
  bool _isDetecting = false;
  bool _isAddingToInventory = false;
  bool _initializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (widget.cameras.isEmpty) {
        throw StateError('No cameras are available on this device.');
      }
      final model = await YoloModel.load(
        modelPath: 'assets/best.tflite',
        labelsPath: 'assets/labels.txt',
        accelerator: Accelerator.gpu,
        numThreads: 2,
      );
      if (!mounted) {
        await model.dispose();
        return;
      }
      _model = model;

      final camera = widget.cameras.firstWhere(
        (description) => description.lensDirection == CameraLensDirection.back,
        orElse: () => widget.cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
      await _startCameraStream();
    } catch (error, stackTrace) {
      debugPrint('Could not initialize product detection: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _initializing = false;
          _errorMessage = 'Could not start detection: $error';
        });
      }
    }
  }

  Future<void> _detectFrame(CameraImage image) async {
    try {
      final controller = _controller;
      final model = _model;
      if (controller == null || model == null) return;
      final result = await model.detectFrame(
        CameraFrame(
          width: image.width,
          height: image.height,
          format: Platform.isAndroid ? FrameFormat.nv21 : FrameFormat.bgra8888,
          planes: [
            for (final plane in image.planes)
              FramePlane(
                bytes: plane.bytes,
                bytesPerRow: plane.bytesPerRow,
                bytesPerPixel: plane.bytesPerPixel ?? 1,
              ),
          ],
          rotation: Platform.isAndroid
              ? CameraFrame.rotationFor(
                  sensorOrientation: controller.description.sensorOrientation,
                  deviceOrientation: CameraFrame.degreesFor(
                    controller.value.deviceOrientation.name,
                  ),
                  frontCamera:
                      controller.description.lensDirection ==
                      CameraLensDirection.front,
                )
              : 0,
        ),
        options: const DetectionOptions(
          confidenceThreshold: 0.4,
          iouThreshold: 0.4,
        ),
      );
      if (mounted && result != null) {
        setState(() {
          _imageSize = result.imageSize;
          _detections = result.detections;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Product detection failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _errorMessage = 'Detection failed: $error');
      }
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _startCameraStream() async {
    final controller = _controller;
    if (!mounted ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }
    try {
      await controller.startImageStream((image) {
        if (_isDetecting || _errorMessage != null) return;
        _isDetecting = true;
        unawaited(_detectFrame(image));
      });
    } catch (error, stackTrace) {
      debugPrint('Could not start camera stream: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _errorMessage = 'Could not start camera: $error');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    unawaited(_model?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final counts = <String, int>{};
    for (final detection in _detections) {
      counts.update(detection.label, (count) => count + 1, ifAbsent: () => 1);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Product detection')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
            )
          : controller == null || !controller.value.isInitialized
          ? const Center(child: Text('Camera is not available.'))
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final widgetSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(controller),
                          ..._buildBoxes(widgetSize, controller),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.74),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _errorMessage ??
                                    (counts.isEmpty
                                        ? 'Point the camera at a handicraft'
                                        : 'Detected ${counts.values.fold<int>(0, (sum, count) => sum + count)} item(s)'),
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          if (counts.isNotEmpty)
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  bottom: 86,
                                ),
                                child: FilledButton.icon(
                                  onPressed: _isAddingToInventory
                                      ? null
                                      : () => _addToInventory(counts),
                                  icon: _isAddingToInventory
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.inventory_2_outlined),
                                  label: Text(
                                    _isAddingToInventory
                                        ? 'Adding...'
                                        : 'Add to inventory',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Text(
                    'Detection runs on this device. Results are not saved as sales.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _addToInventory(Map<String, int> counts) async {
    if (_isAddingToInventory || counts.isEmpty || !mounted) return;
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add detected products?'),
        content: Text(
          counts.entries
              .map((entry) => '${entry.key}: +${entry.value}')
              .join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add to inventory'),
          ),
        ],
      ),
    );
    if (confirmation != true || !mounted) return;

    setState(() => _isAddingToInventory = true);
    try {
      await widget.repository.addDetectedStock(counts);
      await widget.onInventoryChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Detected products added to inventory')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Could not add detected products to inventory: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add products: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToInventory = false);
    }
  }

  List<Widget> _buildBoxes(Size widgetSize, CameraController controller) {
    final imageSize = _imageSize;
    if (imageSize == null || imageSize.isEmpty) return [];
    final mapper = BoxMapper(
      imageSize: imageSize,
      widgetSize: widgetSize,
      fit: BoxFit.cover,
      mirror: controller.description.lensDirection == CameraLensDirection.front,
    );
    return _detections.map((detection) {
      final box = mapper.mapRect(detection.box);
      return Positioned(
        left: box.left,
        top: box.top,
        width: box.width,
        height: box.height,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.redAccent, width: 2),
          ),
          alignment: Alignment.topLeft,
          child: Text(
            '${detection.label} ${(detection.confidence * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              backgroundColor: Colors.redAccent,
            ),
          ),
        ),
      );
    }).toList();
  }
}
