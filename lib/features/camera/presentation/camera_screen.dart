import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_journal/core/logging/app_logger.dart';
import 'package:video_journal/features/media_editor/presentation/media_editor_screen.dart';
import 'package:video_journal/shared/enums/enums.dart';

// Provider to retrieve list of available cameras
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return await availableCameras();
});

enum CameraMode { video, photo }

class CameraScreen extends ConsumerStatefulWidget {
  final String? folderId;
  final String? folderName;

  const CameraScreen({
    super.key,
    this.folderId,
    this.folderName,
  });

  static Route<void> route({String? folderId, String? folderName}) {
    return MaterialPageRoute(
      builder: (context) => CameraScreen(
        folderId: folderId,
        folderName: folderName,
      ),
    );
  }

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isRecording = false;
  AssetType _captureMode = AssetType.photo;
  CameraMode _currentMode = CameraMode.photo;
  bool _isInitializing = false;
  FlashMode _flashMode = FlashMode.off;
  final ImagePicker _picker = ImagePicker();

  // Timer for video recording
  Timer? _timer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing) return;
    setState(() {
      _isInitializing = true;
    });

    try {
      final cameras = await ref.read(availableCamerasProvider.future);
      if (cameras.isEmpty) {
        AppLogger.warning(LogCategory.camera, 'No cameras found on device');
        return;
      }
      _cameras = cameras;

      // Selfie camera (front) should be default on first load
      if (_controller == null) {
        for (int i = 0; i < cameras.length; i++) {
          if (cameras[i].lensDirection == CameraLensDirection.front) {
            _selectedCameraIndex = i;
            break;
          }
        }
      }

      final controller = CameraController(
        cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );

      _controller = controller;
      await controller.initialize();
      if (mounted) {
        try {
          await controller.setFlashMode(_flashMode);
        } catch (_) {}
        setState(() {});
      }
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.camera, 'Failed to initialize camera', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the camera. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _controller?.dispose();
    _controller = null;
    _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
      default:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await controller.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.camera, 'Failed to set flash mode', e, stackTrace);
    }
  }

  void _startTimer() {
    _recordDuration = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = remainingSeconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  Future<void> _pickFromGallery() async {
    try {
      if (_captureMode == AssetType.photo) {
        final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
        if (file != null && mounted) {
          _navigateToEditor(file.path, AssetType.photo);
        }
      } else {
        final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file != null && mounted) {
          _navigateToEditor(file.path, AssetType.video);
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.camera, 'Failed to pick media from gallery', e, stackTrace);
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (_captureMode == AssetType.photo) {
      try {
        final XFile file = await controller.takePicture();
        if (mounted) {
          _navigateToEditor(file.path, AssetType.photo);
        }
      } catch (e, stackTrace) {
        AppLogger.error(LogCategory.camera, 'Failed to capture photo', e, stackTrace);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture photo. Please try again.')),
        );
      }
    } else {
      // Video mode
      if (_isRecording) {
        try {
          _stopTimer();
          final XFile file = await controller.stopVideoRecording();
          setState(() {
            _isRecording = false;
          });
          if (mounted) {
            _navigateToEditor(file.path, AssetType.video);
          }
        } catch (e, stackTrace) {
          AppLogger.error(LogCategory.camera, 'Failed to stop video recording', e, stackTrace);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to stop video recording.')),
          );
        }
      } else {
        try {
          await controller.startVideoRecording();
          _startTimer();
          setState(() {
            _isRecording = true;
          });
        } catch (e, stackTrace) {
          AppLogger.error(LogCategory.camera, 'Failed to start video recording', e, stackTrace);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start video recording.')),
          );
        }
      }
    }
  }

  void _navigateToEditor(String filePath, AssetType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaEditorScreen(
          mediaPath: filePath,
          mediaType: type,
          folderId: widget.folderId,
          folderName: widget.folderName,
        ),
      ),
    ).then((_) {
      // Re-initialize camera when returning from editor if disposed
      if (_controller == null || !_controller!.value.isInitialized) {
        _initializeCamera();
      }
    });
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.auto:
      default:
        return Icons.flash_auto;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Full Screen Camera Preview View
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 1080,
                    height: 1080 * controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  ),
                ),
              ),
            ),

            // Top action buttons (Close, Timer, Flash Toggle)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close Button
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Timer Pill Capsule
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isRecording ? _formatDuration(_recordDuration) : '00:00',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // Flash Button
                  IconButton(
                    icon: Icon(_getFlashIcon(), color: Colors.white, size: 28),
                    onPressed: _toggleFlash,
                  ),
                ],
              ),
            ),

            // Bottom capture interface
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shutter controls row (Gallery, Shutter, Flip Camera)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Gallery Button
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.image, color: Colors.white, size: 24),
                            onPressed: _pickFromGallery,
                          ),
                        ),

                        // Large Shutter Button
                        GestureDetector(
                          onTap: _capture,
                          child: Container(
                            height: 84,
                            width: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: _isRecording ? 32 : 68,
                                width: _isRecording ? 32 : 68,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(_isRecording ? 8 : 34),
                                  color: (_captureMode == AssetType.video)
                                      ? Colors.red
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Swap Camera Button
                        if (_cameras != null && _cameras!.length > 1 && !_isRecording)
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white30),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 24),
                              onPressed: _toggleCamera,
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  // Bottom Mode Sliding Selector
                  if (!_isRecording) ...[
                    const SizedBox(height: 16),
                    _buildModeSelector(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    final modes = [
      {'label': 'Video', 'mode': CameraMode.video},
      {'label': 'Photo', 'mode': CameraMode.photo},
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: modes.map((m) {
          final label = m['label'] as String;
          final mode = m['mode'] as CameraMode;
          final isSelected = _currentMode == mode;

          return GestureDetector(
            onTap: () {
              if (_isRecording) return;
              setState(() {
                _currentMode = mode;
                if (mode == CameraMode.photo) {
                  _captureMode = AssetType.photo;
                } else {
                  _captureMode = AssetType.video;
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: isSelected
                  ? BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
