import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Provides database open and filesystem helpers.
class DbProvider {
  final Directory dbDir;

  DbProvider(this.dbDir);

  /// Open a database by filename or absolute path.
  Database open(String dbName) {
    final path = _resolveDbPath(dbName);
    final db = sqlite3.open(path);
    db.execute('PRAGMA busy_timeout = 3000;');
    return db;
  }

  String _resolveDbPath(String dbName) {
    if (dbName.startsWith('/')) return dbName;
    return '${dbDir.path}/$dbName';
  }

  /// List probable sqlite database files in the db directory.
  List<Map<String, dynamic>> listDatabases() {
    if (!dbDir.existsSync()) return const [];
    final files = dbDir.listSync().whereType<File>().where((f) {
      final name = f.uri.pathSegments.last;
      if (name.endsWith('.db') || name.endsWith('.sqlite')) return true;
      try {
        final b = f.openSync(mode: FileMode.read)..setPositionSync(0);
        final hdr = b.readSync(16);
        b.closeSync();
        return String.fromCharCodes(hdr).startsWith('SQLite format 3');
      } catch (_) {
        return false;
      }
    }).toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files
        .map((f) => {
              'name': f.uri.pathSegments.last,
              'path': f.path,
              'sizeBytes': f.lengthSync(),
            })
        .toList();
  }
}
