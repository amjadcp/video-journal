import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_journal/core/logging/app_logger.dart';
import 'package:video_journal/features/media_editor/domain/video_processor.dart';

enum TrimmerHandle { none, start, end, both }

class VideoTrimmer extends StatefulWidget {
  final String videoPath;
  final double totalDurationSeconds;
  final Function(double start, double end) onTrimChanged;
  final VoidCallback? onTrimStart;
  final Function(double start, double end)? onTrimEnd;

  const VideoTrimmer({
    super.key,
    required this.videoPath,
    required this.totalDurationSeconds,
    required this.onTrimChanged,
    this.onTrimStart,
    this.onTrimEnd,
  });

  @override
  State<VideoTrimmer> createState() => _VideoTrimmerState();
}

class _CropTrimmerState {} // Placeholder to avoid compilation warnings

class _VideoTrimmerState extends State<VideoTrimmer> {
  late double _startPercent;
  late double _endPercent;

  List<String> _thumbnails = [];
  bool _isLoadingThumbnails = true;
  int _videoSizeBytes = 0;

  TrimmerHandle _activeHandle = TrimmerHandle.none;
  double _dragStartPercentLeft = 0.0;
  double _dragStartPercentRight = 0.0;
  double _dragStartX = 0.0;

  @override
  void initState() {
    super.initState();
    _startPercent = 0.0;
    _endPercent = 1.0;
    _loadVideoSize();
    _loadThumbnails();
  }

  void _loadVideoSize() {
    try {
      final file = File(widget.videoPath);
      if (file.existsSync()) {
        _videoSizeBytes = file.lengthSync();
      }
    } catch (e) {
      AppLogger.warning(LogCategory.editor, 'Failed to read video size: $e');
    }
  }

  Future<void> _loadThumbnails() async {
    setState(() => _isLoadingThumbnails = true);
    final thumbs = await VideoProcessor.extractThumbnails(
      videoPath: widget.videoPath,
      duration: widget.totalDurationSeconds,
    );
    if (mounted) {
      setState(() {
        _thumbnails = thumbs;
        _isLoadingThumbnails = false;
      });
    }
  }

  String _formatDuration(double seconds) {
    final mins = seconds ~/ 60;
    final secs = (seconds % 60).toInt();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatSize(double sizeInBytes) {
    final mb = sizeInBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final trimmedDuration = (_endPercent - _startPercent) * widget.totalDurationSeconds;
    final trimmedSizeBytes = _videoSizeBytes * (_endPercent - _startPercent);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: Colors.black.withOpacity(0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Metadata readouts (Duration, size, audio icon)
          Row(
            children: [
              const Icon(Icons.volume_up, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                '${_formatDuration(trimmedDuration)}  •  ${_formatSize(trimmedSizeBytes)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filmstrip and interactive handles
          LayoutBuilder(
            builder: (context, constraints) {
              final trimmerWidth = constraints.maxWidth;
              final absStart = _startPercent * trimmerWidth;
              final absEnd = _endPercent * trimmerWidth;

              const handleTouchWidth = 24.0;

              return GestureDetector(
                onPanStart: (details) {
                  final x = details.localPosition.dx;
                  _dragStartX = x;
                  _dragStartPercentLeft = _startPercent;
                  _dragStartPercentRight = _endPercent;

                  final distStart = (x - absStart).abs();
                  final distEnd = (x - absEnd).abs();

                  widget.onTrimStart?.call();

                  if (distStart < handleTouchWidth) {
                    _activeHandle = TrimmerHandle.start;
                  } else if (distEnd < handleTouchWidth) {
                    _activeHandle = TrimmerHandle.end;
                  } else if (x > absStart && x < absEnd) {
                    _activeHandle = TrimmerHandle.both;
                  } else {
                    _activeHandle = TrimmerHandle.none;
                  }
                },
                onPanUpdate: (details) {
                  if (_activeHandle == TrimmerHandle.none) return;

                  final deltaX = details.localPosition.dx - _dragStartX;
                  final deltaPercent = deltaX / trimmerWidth;

                  // Enforce a minimum 1 second duration
                  final minPercent = 1.0 / widget.totalDurationSeconds;

                  setState(() {
                    switch (_activeHandle) {
                      case TrimmerHandle.start:
                        _startPercent = (_dragStartPercentLeft + deltaPercent).clamp(0.0, _endPercent - minPercent);
                        break;
                      case TrimmerHandle.end:
                        _endPercent = (_dragStartPercentRight + deltaPercent).clamp(_startPercent + minPercent, 1.0);
                        break;
                      case TrimmerHandle.both:
                        final width = _dragStartPercentRight - _dragStartPercentLeft;
                        double newStart = _dragStartPercentLeft + deltaPercent;
                        if (newStart < 0.0) {
                          newStart = 0.0;
                        } else if (newStart + width > 1.0) {
                          newStart = 1.0 - width;
                        }
                        _startPercent = newStart;
                        _endPercent = newStart + width;
                        break;
                      default:
                        break;
                    }
                  });

                  widget.onTrimChanged(
                    _startPercent * widget.totalDurationSeconds,
                    _endPercent * widget.totalDurationSeconds,
                  );
                },
                onPanEnd: (_) {
                  _activeHandle = TrimmerHandle.none;
                  widget.onTrimEnd?.call(
                    _startPercent * widget.totalDurationSeconds,
                    _endPercent * widget.totalDurationSeconds,
                  );
                },
                child: SizedBox(
                  height: 60,
                  child: Stack(
                    children: [
                      // 1. Filmstrip thumbnails background
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _isLoadingThumbnails
                              ? const Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  children: List.generate(8, (index) {
                                    if (index >= _thumbnails.length) {
                                      return Expanded(
                                        child: Container(color: Colors.grey[900]),
                                      );
                                    }
                                    return Expanded(
                                      child: Image.file(
                                        File(_thumbnails[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }),
                                ),
                        ),
                      ),

                      // 2. Dark masks for out-of-trim regions
                      // Left mask
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: absStart,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      // Right mask
                      Positioned(
                        left: absEnd,
                        top: 0,
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),

                      // 3. Selection Box Border
                      Positioned(
                        left: absStart,
                        top: 0,
                        bottom: 0,
                        width: (absEnd - absStart),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),

                      // 4. Draggable White circle handles in the center of left/right borders
                      // Left Handle Circle
                      Positioned(
                        left: absStart - 8,
                        top: 18,
                        child: Container(
                          width: 16,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Right Handle Circle
                      Positioned(
                        left: absEnd - 8,
                        top: 18,
                        child: Container(
                          width: 16,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
