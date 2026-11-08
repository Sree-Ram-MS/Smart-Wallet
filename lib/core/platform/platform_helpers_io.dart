import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

/// Copies a picked image into the app documents folder [folder] and returns
/// the stored path. On native the original file at [sourcePath] is copied
/// (unchanged behaviour); [readBytes] is only used if there is no path.
Future<String> persistPickedImage({
  required String folder,
  required String sourceName,
  String? sourcePath,
  Future<Uint8List> Function()? readBytes,
  String prefix = '',
}) async {
  final appDir = await getApplicationDocumentsDirectory();
  final dir = Directory('${appDir.path}/$folder');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final ext = (sourcePath ?? sourceName).split('.').last;
  final targetPath = '${dir.path}/$prefix${const Uuid().v4()}.$ext';
  if (sourcePath != null) {
    await File(sourcePath).copy(targetPath);
  } else if (readBytes != null) {
    await File(targetPath).writeAsBytes(await readBytes());
  } else {
    throw ArgumentError('No image source given');
  }
  return targetPath;
}

/// Image provider for a locally stored image reference: a file path,
/// `file://` URI or a `data:` URI (images picked on the web version).
/// Returns null if the image cannot be found.
ImageProvider? localImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('data:')) {
    try {
      return MemoryImage(UriData.parse(path).contentAsBytes());
    } catch (_) {
      return null;
    }
  }
  final file = File(path.replaceFirst('file://', ''));
  if (file.existsSync()) return FileImage(file);
  return null;
}

/// Whether [path] points to a usable local image.
bool localImageExists(String? path) => localImageProvider(path) != null;

/// Reads the bytes of a file chosen with file_picker.
Future<Uint8List?> readPickedBytes({String? path, Uint8List? bytes}) async {
  if (bytes != null) return bytes;
  if (path == null) return null;
  return File(path).readAsBytes();
}

/// Saves [bytes] to the app documents folder and opens the share sheet.
Future<void> shareOrDownloadFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? subject,
  String? text,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      subject: subject,
      text: text,
    ),
  );
}

List<int> gzipEncode(List<int> data) => gzip.encode(data);

List<int> gzipDecode(List<int> data) => gzip.decode(data);

/// True if [error] looks like a network failure (no connection).
bool isNetworkError(Object error) =>
    error is SocketException ||
    error is HttpException ||
    error.toString().contains('ClientException') ||
    error.toString().contains('SocketException');
