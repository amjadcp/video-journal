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
import 'package:video_journal/features/folders/presentation/folder_selector_sheet.dart'; // We will create this next
import 'package:video_journal/shared/enums/enums.dart';

class MediaEditorScreen extends ConsumerStatefulWidget {
  final String mediaPath;
  final AssetType mediaType;

  const MediaEditorScreen({
    super.key,
    required this.mediaPath,
    required this.mediaType,
  });

  @override
  ConsumerState<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends ConsumerState<MediaEditorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  
  // Editor States
  int _rotationQuarterTurns = 0;
  PhotoFilter _selectedFilter = PhotoFilter.none;
  Color _drawColor = Colors.greenAccent;
  List<DrawingPath> _paths = [];
  final List<StickerData> _stickers = [];
  
  // Video-specific states
  VideoPlayerController? _videoPlayerController;
  double _videoStart = 0.0;
  double _videoEnd = 0.0;
  bool _isSaving = false;

  final GlobalKey<DrawingCanvasState> _canvasKey = GlobalKey<DrawingCanvasState>();

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == AssetType.video) {
      _initVideo();
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_videoPlayerListener);
    _videoPlayerController?.dispose();
    super.dispose();
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
    final controller = VideoPlayerController.file(File(widget.mediaPath));
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

  Future<void> _saveMedia() async {
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
        // Video trim
        if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
          final totalDuration = _videoPlayerController!.value.duration.inMilliseconds / 1000.0;
          if (_videoStart > 0.1 || _videoEnd < totalDuration - 0.1) {
            final trimmed = await VideoProcessor.trimVideo(
              inputPath: widget.mediaPath,
              startSeconds: _videoStart,
              endSeconds: _videoEnd,
            );
            savedPath = trimmed ?? widget.mediaPath;
          } else {
            savedPath = widget.mediaPath;
          }
        } else {
          savedPath = widget.mediaPath;
        }
      }

      if (mounted) {
        // Open the save target selector (Home vs Folder)
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => FolderSelectorSheet(
            mediaPath: savedPath,
            mediaType: widget.mediaType,
          ),
        ).then((saved) {
          if (saved == true && mounted) {
            Navigator.pop(context, true); // Pop back to capture / home screen
          }
        });
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
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: () => _canvasKey.currentState?.undo()),
          IconButton(icon: const Icon(Icons.clear_all), onPressed: () => _canvasKey.currentState?.clear()),
          IconButton(icon: const Icon(Icons.text_fields), onPressed: () => _addText(false)),
          IconButton(icon: const Icon(Icons.emoji_emotions_outlined), onPressed: () => _addText(true)),
          if (!isVideo) IconButton(icon: const Icon(Icons.rotate_right), onPressed: _rotate),
        ],
      ),
      body: Stack(
        children: [
          // Media Workspace
          Center(
            child: RepaintBoundary(
              key: _repaintKey,
              child: RotatedBox(
                quarterTurns: _rotationQuarterTurns,
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(_selectedFilter.matrix),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Video Player / Image view
                      if (isVideo && _videoPlayerController != null)
                        AspectRatio(
                          aspectRatio: _videoPlayerController!.value.aspectRatio,
                          child: VideoPlayer(_videoPlayerController!),
                        )
                      else if (!isVideo)
                        Image.file(File(widget.mediaPath), fit: BoxFit.contain),

                      // Drawing Canvas Layer
                      Positioned.fill(
                        child: DrawingCanvas(
                          key: _canvasKey,
                          currentColor: _drawColor,
                          onPathsUpdated: (updatedPaths) => _paths = updatedPaths,
                        ),
                      ),

                      // Stickers Layer
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
          ),

          // Bottom Editor Toolbar (Filters, Trimming, Color picker, Save)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Video Trim Slider or Photo Filter List
                if (isVideo && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
                  VideoTrimmer(
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
                  )
                else if (!isVideo)
                  FilterSelector(
                    selectedFilter: _selectedFilter,
                    onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
                  ),

                // Save action bar
                SafeArea(
                  top: false,
                  child: Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Swipe up for filters',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        _isSaving
                            ? const CircularProgressIndicator(color: Colors.greenAccent)
                            : FloatingActionButton.extended(
                                onPressed: _saveMedia,
                                label: const Text('Save'),
                                icon: const Icon(Icons.check),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
