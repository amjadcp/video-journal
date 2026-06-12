import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_journal/core/logging/app_logger.dart';

class VideoProcessor {
  VideoProcessor._();

  static Future<String?> trimVideo({
    required String inputPath,
    required double startSeconds,
    required double endSeconds,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputName = 'REC_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final outputPath = p.join(tempDir.path, outputName);

      // Execute stream-copy trimming (extremely fast and keyframe-accurate)
      final duration = endSeconds - startSeconds;
      final command = '-y -ss $startSeconds -i "$inputPath" -t $duration -c copy "$outputPath"';
      
      AppLogger.info(LogCategory.editor, 'Trimming video with command: $command');
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode != null && returnCode.isValueSuccess()) {
        AppLogger.info(LogCategory.editor, 'Video trimmed successfully to: $outputPath');
        return outputPath;
      } else {
        final logs = await session.getLogs();
        AppLogger.error(LogCategory.editor, 'FFmpeg trimming failed. Logs: ${logs.join("\n")}');
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.editor, 'Error during video trimming', e, stackTrace);
      return null;
    }
  }
}
