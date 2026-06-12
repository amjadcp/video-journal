import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:video_journal/features/media_editor/domain/video_processor.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '.';
  @override
  Future<String?> getApplicationSupportPath() async => '.';
  @override
  Future<String?> getLibraryPath() async => '.';
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
  @override
  Future<String?> getExternalStoragePath() async => '.';
  @override
  Future<List<String>?> getExternalCachePaths() async => ['.'];
  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async => ['.'];
  @override
  Future<String?> getDownloadsPath() async => '.';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = FakePathProviderPlatform();

  const MethodChannel channel = MethodChannel('flutter.arthenica.com/ffmpeg_kit');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'ffmpegSession') {
        return {
          'sessionId': 1,
          'createTime': DateTime.now().millisecondsSinceEpoch,
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'command': 'ffmpeg mock command',
        };
      }
      if (methodCall.method == 'ffmpegSessionExecute') {
        return null;
      }
      if (methodCall.method == 'abstractSessionGetReturnCode') {
        return 0; // Exit code 0 (Success)
      }
      if (methodCall.method == 'abstractSessionGetState') {
        return 3; // Completed state
      }
      if (methodCall.method == 'abstractSessionGetLogs') {
        return [];
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('VideoProcessor Unit Tests', () {
    test('extractThumbnails returns expected paths format', () async {
      final thumbs = await VideoProcessor.extractThumbnails(
        videoPath: 'test_video.mp4',
        duration: 10.0,
      );
      
      expect(thumbs, isA<List<String>>());
    });

    test('trimVideo returns expected path when successful', () async {
      final trimmed = await VideoProcessor.trimVideo(
        inputPath: 'test_video.mp4',
        startSeconds: 2.0,
        endSeconds: 5.0,
      );
      
      expect(trimmed, isNotNull);
      expect(trimmed!, contains('REC_'));
      expect(trimmed, endsWith('.mp4'));
    });

    test('trimVideo with overlay returns re-encoded output path', () async {
      final trimmed = await VideoProcessor.trimVideo(
        inputPath: 'test_video.mp4',
        startSeconds: 1.0,
        endSeconds: 4.0,
        overlayPath: 'overlay.png',
        videoWidth: 720.0,
        videoHeight: 1280.0,
      );

      expect(trimmed, isNotNull);
      expect(trimmed!, contains('REC_'));
      expect(trimmed, endsWith('.mp4'));
    });
  });
}
