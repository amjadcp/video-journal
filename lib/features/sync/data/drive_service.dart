import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:video_journal/core/logging/app_logger.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class DriveService {
  DriveService._();

  static drive.DriveApi getDriveApi(String accessToken) {
    final client = GoogleAuthClient({'Authorization': 'Bearer $accessToken'});
    return drive.DriveApi(client);
  }

  static Future<String?> getOrCreateRootFolder(drive.DriveApi api, String folderName) async {
    try {
      AppLogger.info(LogCategory.sync, 'Searching for root folder: $folderName');
      final list = await api.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and trashed = false",
        spaces: 'drive',
      );

      if (list.files != null && list.files!.isNotEmpty) {
        final id = list.files!.first.id;
        AppLogger.info(LogCategory.sync, 'Found existing root folder ID: $id');
        return id;
      }

      // Create new folder
      AppLogger.info(LogCategory.sync, 'Creating new root folder: $folderName');
      final rootFolder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final created = await api.files.create(rootFolder);
      AppLogger.info(LogCategory.sync, 'Root folder created successfully with ID: ${created.id}');
      return created.id;
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.sync, 'Failed to get/create root folder in Drive', e, stackTrace);
      return null;
    }
  }

  static Future<String?> uploadFile({
    required drive.DriveApi api,
    required File file,
    required String name,
    required String mimeType,
    required String parentId,
  }) async {
    try {
      if (!await file.exists()) {
        AppLogger.warning(LogCategory.sync, 'Upload failed: file does not exist at local path');
        return null;
      }

      AppLogger.info(LogCategory.sync, 'Uploading file: $name to parent folder: $parentId');
      final driveFile = drive.File()
        ..name = name
        ..parents = [parentId];

      final media = drive.Media(file.openRead(), await file.length());
      final result = await api.files.create(driveFile, uploadMedia: media);
      AppLogger.info(LogCategory.sync, 'Uploaded file successfully. Drive ID: ${result.id}');
      return result.id;
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.sync, 'Failed uploading file to Drive', e, stackTrace);
      return null;
    }
  }

  static Future<bool> downloadFile({
    required drive.DriveApi api,
    required String fileId,
    required String localSavePath,
  }) async {
    try {
      AppLogger.info(LogCategory.sync, 'Downloading Drive file: $fileId to: $localSavePath');
      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final saveFile = File(localSavePath);
      // Ensure directory exists
      await saveFile.parent.create(recursive: true);

      final IOSink sink = saveFile.openWrite();
      await response.stream.pipe(sink);
      await sink.close();
      AppLogger.info(LogCategory.sync, 'File downloaded successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.sync, 'Failed downloading file from Drive', e, stackTrace);
      return false;
    }
  }

  static Future<List<drive.File>> listFiles(drive.DriveApi api, String folderId) async {
    try {
      final list = await api.files.list(
        q: "'$folderId' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, size, createdTime)',
      );
      return list.files ?? [];
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.sync, 'Failed listing files in folder: $folderId', e, stackTrace);
      return [];
    }
  }
}
