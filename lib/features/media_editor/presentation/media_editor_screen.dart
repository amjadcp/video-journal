import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:video_journal/core/logging/app_logger.dart';
import 'package:video_journal/features/media_editor/domain/video_processor.dart';
import 'package:video_journal/features/media_editor/presentation/widgets/drawing_canvas.dart';
import 'package:video_journal/features/media_editor/presentation/widgets/filter_selector.dart';
import 'package:video_journal/features/media_editor/presentation/widgets/text_sticker_overlay.dart';
import 'package:video_journal/features/media_editor/presentation/widgets/video_trimmer.dart';
import 'package:video_journal/features/folders/presentation/folder_selector_sheet.dart';
import 'package:video_journal/features/journal/presentation/journal_controller.dart';
import 'package:video_journal/shared/enums/enums.dart';
import 'package:video_journal/features/media_editor/presentation/widgets/crop_overlay.dart';
import 'package:image/image.dart' as img;

class MediaEditorScreen extends ConsumerStatefulWidget {
  final String mediaPath;
  final AssetType mediaType;
  final String? folderId;
  final String? folderName;

  const MediaEditorScreen({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    this.folderId,
    this.folderName,
  });

  @override
  ConsumerState<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends ConsumerState<MediaEditorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _overlayRepaintKey = GlobalKey();
  
  // Editor States
  late String _currentPath;
  int _rotationQuarterTurns = 0;
  PhotoFilter _selectedFilter = PhotoFilter.none;
  Color _drawColor = Colors.greenAccent;
  List<DrawingPath> _paths = [];
  final List<StickerData> _stickers = [];
  
  // Photo-specific crop state
  bool _isCropMode = false;
  Rect _currentCropRect = const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9);
  double? _imageAspectRatio;

  // Video-specific states
  VideoPlayerController? _videoPlayerController;
  double _videoStart = 0.0;
  double _videoEnd = 0.0;
  bool _isSaving = false;

  // Caption and destination state
  late TextEditingController _captionController;
  String? _targetFolderId;
  late String _targetFolderName;

  final GlobalKey<DrawingCanvasState> _canvasKey = GlobalKey<DrawingCanvasState>();

  @override
  void initState() {
    super.initState();
    _currentPath = widget.mediaPath;
    _captionController = TextEditingController();
    _targetFolderId = widget.folderId;
    _targetFolderName = widget.folderName ?? 'Home Journal';
    
    if (widget.mediaType == AssetType.photo) {
      _loadPhotoAspectRatio();
    } else {
      _initVideo();
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoPlayerController?.removeListener(_videoPlayerListener);
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _loadPhotoAspectRatio() async {
    try {
      final bytes = await File(_currentPath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null && mounted) {
        setState(() {
          _imageAspectRatio = image.width / image.height;
        });
      }
    } catch (e) {
      AppLogger.warning(LogCategory.editor, 'Failed to decode image aspect ratio: $e');
    }
  }

  void _videoPlayerListener() {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.isInitialized || !controller.value.isPlaying) return;

    final position = controller.value.position.inMilliseconds / 1000.0;
    
    // Loop back to start if it exceeds end trim
    if (position >= _videoEnd) {
      controller.seekTo(Duration(milliseconds: (_videoStart * 1000).toInt()));
    }
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.file(File(_currentPath));
    _videoPlayerController = controller;
    try {
      await controller.initialize();
      setState(() {
        _videoEnd = controller.value.duration.inMilliseconds / 1000.0;
      });
      controller.setLooping(false); // Loop manually within the trim range
      controller.addListener(_videoPlayerListener);
      await controller.seekTo(Duration(milliseconds: (_videoStart * 1000).toInt()));
      controller.play();
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.editor, 'Failed to initialize video player', e, stackTrace);
    }
  }

  void _rotate() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _addText(bool isEmoji) {
    String text = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEmoji ? 'Add Emoji' : 'Add Text'),
        content: TextField(
          autofocus: true,
          maxLength: isEmoji ? 2 : 50,
          onChanged: (val) => text = val,
          decoration: InputDecoration(
            hintText: isEmoji ? '😀' : 'Enter caption text',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Add'),
            onPressed: () {
              if (text.trim().isNotEmpty) {
                setState(() {
                  _stickers.add(StickerData(
                    id: const Uuid().v4(),
                    text: text,
                    color: isEmoji ? Colors.white : _drawColor,
                    isEmoji: isEmoji,
                    position: const Offset(100, 200),
                  ));
                });
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _applyCrop() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await File(_currentPath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        // Calculate crop bounds
        final x = (_currentCropRect.left * image.width).toInt();
        final y = (_currentCropRect.top * image.height).toInt();
        final w = (_currentCropRect.width * image.width).toInt();
        final h = (_currentCropRect.height * image.height).toInt();

        final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);

        final tempDir = await getTemporaryDirectory();
        final fileName = 'crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final croppedFile = File('${tempDir.path}/$fileName');
        
        await croppedFile.writeAsBytes(img.encodeJpg(cropped, quality: 90));

        setState(() {
          _currentPath = croppedFile.path;
          _imageAspectRatio = cropped.width / cropped.height;
          _isCropMode = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.editor, 'Failed to crop photo', e, stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to crop photo. Please try again.')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<String?> _captureOverlayPng() async {
    try {
      final boundary = _overlayRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      
      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'overlay_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);
      return file.path;
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.editor, 'Failed to capture overlay PNG', e, stackTrace);
      return null;
    }
  }

  Future<void> _saveAndSend() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      String savedPath;
      if (widget.mediaType == AssetType.photo) {
        // Capture RepaintBoundary screenshot for photos (flattens filters, drawings, stickers)
        final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) throw Exception('Boundary not found');
        
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final tempDir = await getTemporaryDirectory();
        final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(pngBytes);
        savedPath = file.path;
      } else {
        // Video trim and burn-in overlays
        String? overlayPath;
        double? videoWidth;
        double? videoHeight;

        final hasDrawing = _paths.isNotEmpty;
        final hasStickers = _stickers.isNotEmpty;

        if (hasDrawing || hasStickers) {
          overlayPath = await _captureOverlayPng();
          if (_videoPlayerController != null) {
            videoWidth = _videoPlayerController!.value.size.width;
            videoHeight = _videoPlayerController!.value.size.height;
          }
        }

        if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
          final totalDuration = _videoPlayerController!.value.duration.inMilliseconds / 1000.0;
          final isTrimmed = _videoStart > 0.1 || _videoEnd < totalDuration - 0.1;

          if (isTrimmed || overlayPath != null) {
            final processed = await VideoProcessor.trimVideo(
              inputPath: _currentPath,
              startSeconds: _videoStart,
              endSeconds: _videoEnd,
              overlayPath: overlayPath,
              videoWidth: videoWidth,
              videoHeight: videoHeight,
            );
            savedPath = processed ?? _currentPath;
          } else {
            savedPath = _currentPath;
          }
        } else {
          savedPath = _currentPath;
        }
      }

      // Save to database direct flow
      if (_targetFolderId == null) {
        await ref.read(journalControllerProvider.notifier).saveAssetToHomeList(
              mediaPath: savedPath,
              type: widget.mediaType,
              caption: _captionController.text,
            );
      } else {
        await ref.read(journalControllerProvider.notifier).saveAssetToFolder(
              mediaPath: savedPath,
              type: widget.mediaType,
              folderId: _targetFolderId!,
              caption: _captionController.text,
            );
      }

      if (mounted) {
        Navigator.pop(context, true); // Return success to home
      }
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.editor, 'Failed to save media', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save edited media. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.mediaType == AssetType.video;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: _isCropMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _isCropMode = false),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: _isCropMode
            ? [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.white),
                  onPressed: _applyCrop,
                ),
              ]
            : [
                IconButton(icon: const Icon(Icons.undo), onPressed: () => _canvasKey.currentState?.undo()),
                IconButton(icon: const Icon(Icons.clear_all), onPressed: () => _canvasKey.currentState?.clear()),
                IconButton(icon: const Icon(Icons.text_fields), onPressed: () => _addText(false)),
                IconButton(icon: const Icon(Icons.emoji_emotions_outlined), onPressed: () => _addText(true)),
                if (!isVideo) ...[
                  IconButton(
                    icon: const Icon(Icons.crop),
                    onPressed: () => setState(() => _isCropMode = true),
                  ),
                  IconButton(icon: const Icon(Icons.rotate_right), onPressed: _rotate),
                ],
              ],
      ),
      body: Column(
        children: [
          // Media Workspace
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _repaintKey,
                child: RotatedBox(
                  quarterTurns: _rotationQuarterTurns,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Video Player / Image view with precise boundaries
                      if (isVideo && _videoPlayerController != null)
                        AspectRatio(
                          aspectRatio: _videoPlayerController!.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_videoPlayerController!),
                              // Overlay RepaintBoundary wraps drawings & stickers
                              Positioned.fill(
                                child: RepaintBoundary(
                                  key: _overlayRepaintKey,
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: DrawingCanvas(
                                            key: _canvasKey,
                                            currentColor: _drawColor,
                                            onPathsUpdated: (updatedPaths) => _paths = updatedPaths,
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: TextStickerOverlay(
                                            stickers: _stickers,
                                            onUpdateSticker: (id, pos, scale) {},
                                            onDeleteSticker: (id) {
                                              setState(() {
                                                _stickers.removeWhere((s) => s.id == id);
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (!isVideo && _imageAspectRatio != null)
                        AspectRatio(
                          aspectRatio: _imageAspectRatio!,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.file(File(_currentPath), fit: BoxFit.fill),
                              // Transparent overlay for photo
                              Positioned.fill(
                                child: RepaintBoundary(
                                  key: _overlayRepaintKey,
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: DrawingCanvas(
                                            key: _canvasKey,
                                            currentColor: _drawColor,
                                            onPathsUpdated: (updatedPaths) => _paths = updatedPaths,
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: TextStickerOverlay(
                                            stickers: _stickers,
                                            onUpdateSticker: (id, pos, scale) {},
                                            onDeleteSticker: (id) {
                                              setState(() {
                                                _stickers.removeWhere((s) => s.id == id);
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_isCropMode)
                                Positioned.fill(
                                  child: CropOverlay(
                                    onCropRectChanged: (rect) {
                                      _currentCropRect = rect;
                                    },
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Editor Toolbar & Action bar
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Video Trim Slider or Photo Filter List
              if (!_isCropMode) ...[
                if (isVideo && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
                  VideoTrimmer(
                    videoPath: _currentPath,
                    totalDurationSeconds: _videoPlayerController!.value.duration.inMilliseconds / 1000.0,
                    onTrimStart: () {
                      _videoPlayerController?.pause();
                    },
                    onTrimEnd: (start, end) {
                      _videoPlayerController?.seekTo(Duration(milliseconds: (start * 1000).toInt()));
                      _videoPlayerController?.play();
                    },
                    onTrimChanged: (start, end) {
                      final startChanged = (start - _videoStart).abs() > 0.01;
                      final endChanged = (end - _videoEnd).abs() > 0.01;
                      
                      _videoStart = start;
                      _videoEnd = end;
                      
                      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
                        if (startChanged) {
                          _videoPlayerController!.seekTo(Duration(milliseconds: (start * 1000).toInt()));
                        } else if (endChanged) {
                          _videoPlayerController!.seekTo(Duration(milliseconds: (end * 1000).toInt()));
                        }
                      }
                    },
                  ),
              ],

              // Save direct action bar
              if (!_isCropMode) _buildBottomBar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Destination Capsule
            GestureDetector(
              onTap: () async {
                final result = await showModalBottomSheet<Map<String, dynamic>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => FolderSelectorSheet(
                    mediaPath: _currentPath,
                    mediaType: widget.mediaType,
                    selectOnly: true,
                  ),
                );
                if (result != null && mounted) {
                  setState(() {
                    _targetFolderId = result['id'];
                    _targetFolderName = result['name'] ?? 'Home Journal';
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _targetFolderId == null ? Icons.book : Icons.folder,
                      color: Colors.greenAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _targetFolderName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Caption Text Field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _captionController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Add a caption...',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Send Button
            _isSaving
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.greenAccent),
                    ),
                  )
                : CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.greenAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.black),
                      onPressed: _saveAndSend,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
