import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Copies [sourcePath] into `<app docs>/evidence/` and returns the new path.
/// Falls back to the original path if the copy fails.
Future<String> persistEvidenceFile(String sourcePath, String fileName) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final evidenceDir = Directory('${dir.path}/evidence');
    await evidenceDir.create(recursive: true);
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest =
        File('${evidenceDir.path}/${DateTime.now().microsecondsSinceEpoch}_$safe');
    await File(sourcePath).copy(dest.path);
    return dest.path;
  } catch (_) {
    return sourcePath;
  }
}
