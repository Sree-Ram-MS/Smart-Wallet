import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

String _mimeForExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    default:
      return 'image/png';
  }
}

/// On the web there is no file system: the picked image is stored inline as a
/// `data:` URI so it survives reloads and travels with the Drive backup.
Future<String> persistPickedImage({
  required String folder,
  required String sourceName,
  String? sourcePath,
  Future<Uint8List> Function()? readBytes,
  String prefix = '',
}) async {
  if (readBytes == null) {
    throw ArgumentError('readBytes is required on the web');
  }
  final bytes = await readBytes();
  final ext = sourceName.contains('.') ? sourceName.split('.').last : 'png';
  return 'data:${_mimeForExt(ext)};base64,${base64Encode(bytes)}';
}

/// Image provider for a stored image reference. Supports `data:` URIs and
/// http(s)/blob URLs. Native file paths (from a phone backup) can't be read
/// on the web, so they return null and callers fall back to the emoji.
ImageProvider? localImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('data:')) {
    try {
      return MemoryImage(UriData.parse(path).contentAsBytes());
    } catch (_) {
      return null;
    }
  }
  if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:')) {
    return NetworkImage(path);
  }
  return null;
}

bool localImageExists(String? path) => localImageProvider(path) != null;

/// On the web file_picker always returns bytes (path is unavailable).
Future<Uint8List?> readPickedBytes({String? path, Uint8List? bytes}) async => bytes;

/// Triggers a browser download of [bytes] as [fileName].
Future<void> shareOrDownloadFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? subject,
  String? text,
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Future<void>.delayed(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
}

List<int> gzipEncode(List<int> data) => GZipEncoder().encode(data) ?? <int>[];

List<int> gzipDecode(List<int> data) => GZipDecoder().decodeBytes(data);

bool isNetworkError(Object error) {
  final s = error.toString();
  return s.contains('ClientException') ||
      s.contains('XMLHttpRequest') ||
      s.contains('Failed to fetch') ||
      s.contains('NetworkError');
}
