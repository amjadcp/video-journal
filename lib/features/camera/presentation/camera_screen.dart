import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_journal/core/logging/app_logger.dart';
import 'package:video_journal/features/media_editor/presentation/media_editor_screen.dart';
import 'package:video_journal/shared/enums/enums.dart';

// Provider to retrieve list of available cameras
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return await availableCameras();
});

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (context) => const CameraScreen(),
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
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
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

      final controller = CameraController(
        cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );

      _controller = controller;
      await controller.initialize();
      if (mounted) {
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
        ),
      ),
    ).then((_) {
      // Re-initialize camera when returning from editor if disposed
      if (_controller == null || !_controller!.value.isInitialized) {
        _initializeCamera();
      }
    });
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
            // Camera Preview View
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),

            // Top action buttons (Back, Switch Camera)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (_cameras != null && _cameras!.length > 1 && !_isRecording)
                    IconButton(
                      icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 28),
                      onPressed: _toggleCamera,
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
                  // Mode Selector (Photo vs Video)
                  if (!_isRecording)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _captureMode = AssetType.photo;
                              });
                            },
                            child: Text(
                              'PHOTO',
                              style: TextStyle(
                                color: _captureMode == AssetType.photo ? Colors.greenAccent : Colors.white60,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _captureMode = AssetType.video;
                              });
                            },
                            child: Text(
                              'VIDEO',
                              style: TextStyle(
                                color: _captureMode == AssetType.video ? Colors.greenAccent : Colors.white60,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Shutter Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Sized box to balance layout
                      const SizedBox(width: 48),

                      // Capture Button
                      GestureDetector(
                        onTap: _capture,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 76,
                          width: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording
                                  ? Colors.red
                                  : (_captureMode == AssetType.video ? Colors.redAccent : Colors.white),
                            ),
                            child: _isRecording
                                ? const Icon(Icons.stop, color: Colors.white, size: 28)
                                : null,
                          ),
                        ),
                      ),

                      // Mode Indicator Icon (video camera or photo camera)
                      SizedBox(
                        width: 48,
                        child: Icon(
                          _captureMode == AssetType.video ? Icons.videocam : Icons.photo_camera,
                          color: Colors.white54,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
