import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_journal/core/logging/app_logger.dart';

class VideoProcessor {
  VideoProcessor._();

  static Future<List<String>> extractThumbnails({
    required String videoPath,
    required double duration,
  }) async {
    final List<String> thumbnailPaths = [];
    try {
      final tempDir = await getTemporaryDirectory();
      final prefix = 'thumb_${DateTime.now().millisecondsSinceEpoch}';
      final pattern = p.join(tempDir.path, '${prefix}_%d.jpg');
      
      // Extract 8 frames evenly spaced
      final command = '-y -i "$videoPath" -vf "fps=8/$duration,scale=120:120" -vframes 8 "$pattern"';
      
      AppLogger.info(LogCategory.editor, 'Extracting thumbnails with command: $command');
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode != null && returnCode.isValueSuccess()) {
        for (int i = 1; i <= 8; i++) {
          final filePath = p.join(tempDir.path, '${prefix}_$i.jpg');
          if (File(filePath).existsSync()) {
            thumbnailPaths.add(filePath);
          }
        }
        
        // Fill up to 8 if fewer were generated
        if (thumbnailPaths.isNotEmpty) {
          while (thumbnailPaths.length < 8) {
            thumbnailPaths.add(thumbnailPaths.last);
          }
        }
        AppLogger.info(LogCategory.editor, 'Successfully extracted ${thumbnailPaths.length} thumbnails.');
      } else {
        final logs = await session.getLogs();
        AppLogger.error(LogCategory.editor, 'FFmpeg thumbnail extraction failed. Logs: ${logs.join("\n")}');
      }
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.editor, 'Error during thumbnail extraction', e, stackTrace);
    }
    return thumbnailPaths;
  }

  static Future<String?> trimVideo({
    required String inputPath,
    required double startSeconds,
    required double endSeconds,
    String? overlayPath,
    double? videoWidth,
    double? videoHeight,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputName = 'REC_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final outputPath = p.join(tempDir.path, outputName);

      final duration = endSeconds - startSeconds;
      String command;

      if (overlayPath != null && videoWidth != null && videoHeight != null) {
        // Overlay drawings/stickers and re-encode H.264
        command = '-y -ss $startSeconds -i "$inputPath" -i "$overlayPath" -t $duration '
            '-filter_complex "[1:v]scale=${videoWidth.toInt()}:${videoHeight.toInt()}[ovrl];[0:v][ovrl]overlay=0:0" '
            '-map 0:v -map 0:a? -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a copy "$outputPath"';
      } else {
        // Execute stream-copy trimming (extremely fast and keyframe-accurate)
        command = '-y -ss $startSeconds -i "$inputPath" -t $duration -c copy "$outputPath"';
      }
      
      AppLogger.info(LogCategory.editor, 'Processing video with command: $command');
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode != null && returnCode.isValueSuccess()) {
        AppLogger.info(LogCategory.editor, 'Video processed successfully to: $outputPath');
        return outputPath;
      } else {
        final logs = await session.getLogs();
        AppLogger.error(LogCategory.editor, 'FFmpeg processing failed. Logs: ${logs.join("\n")}');
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.editor, 'Error during video processing', e, stackTrace);
      return null;
    }
  }
}
