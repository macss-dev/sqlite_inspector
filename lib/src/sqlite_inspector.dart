import 'dart:io';

import 'auth.dart';
import 'server.dart';

/// Public API for the sqlite inspector package.
///
/// This is a small, stable wrapper that exposes simple static start/stop
/// methods and delegates the actual HTTP work to [InspectorServer].
class SqliteInspector {
  static InspectorServer? _server;

  /// Override del directorio de bases de datos, útil para tests en PC.
  static Directory? _dbDirOverride;

  /// Start the inspector server.
  ///
  /// - [port]: TCP port to bind on loopback (default 7111).
  /// - [allowSchema]: whether DDL and PRAGMA changes are allowed.
  /// - [token]: optional debug token required in the `x-debug-token` header.
  static Future<void> start({
    int port = 7111,
    bool allowSchema = false,
    String? token,
    String? dbDirOverride,
  }) async {
    if (_server != null) return;

    // Try to discover package name and database directory on Android-like
    // environments. If discovery fails, fallback to a temporary directory.
    final pkg = guessPackageName() ?? 'unknown';

    /// If a dbDirOverride is provided (tests), use it.
    _dbDirOverride = (dbDirOverride != null) ? Directory(dbDirOverride) : null;

    Directory dbDir;
    try {
      dbDir = detectDbDir(pkg);
    } catch (_) {
      dbDir = Directory.systemTemp;
    }

    _server = await InspectorServer.start(
      port: port,
      allowSchema: allowSchema,
      token: token,
      packageName: pkg,
      dbDir: dbDir,
    );
  }

  /// Stop the running inspector server, if any.
  static Future<void> stop() async {
    await _server?.stop();
    _server = null;
  }

  /// Whether the inspector is currently running.
  static bool get isRunning => _server != null;

  /// Detect a reasonable database directory for the given package name.
  /// If tests provided an override via [_dbDirOverride], return that.
  static Directory detectDbDir(String pkg) {
    if (_dbDirOverride != null) return _dbDirOverride!;

    final candidates = [
      '/data/user/0/$pkg/databases',
      '/data/data/$pkg/databases',
    ];
    for (final p in candidates) {
      final d = Directory(p);
      if (d.existsSync()) return d;
    }

    final d = Directory('/data/data/$pkg/databases');
    d.createSync(recursive: true);
    return d;
  }
}
