import 'dart:async';
import 'dart:io';

import 'auth.dart';
import 'db_provider.dart';
import 'queries.dart';
import 'utils.dart';

/// Lightweight HTTP inspector server for local sqlite files.
class InspectorServer {
  HttpServer? _server;
  bool allowSchema;
  final String? token;
  final String packageName;
  final Directory dbDir;

  late final DbProvider _provider;
  late final Queries _queries;

  InspectorServer._(this._server, this.allowSchema, this.token,
      this.packageName, this.dbDir) {
    _provider = DbProvider(dbDir);
    _queries = Queries(_provider);
  }

  /// Start server with explicit packageName and dbDir so the public API can
  /// control where databases are discovered. If dbDir is omitted, a temporary
  /// directory is used (useful for tests).
  static Future<InspectorServer> start({
    int port = 7111,
    bool allowSchema = false,
    String? token,
    String packageName = 'unknown',
    Directory? dbDir,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final instance = InspectorServer._(
        server, allowSchema, token, packageName, dbDir ?? Directory.systemTemp);
    server.listen(instance._handle, onError: (e) {});
    return instance;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  bool get isRunning => _server != null;

  Future<void> _handle(HttpRequest r) async {
    final auth = Auth(token);
    if (!auth.check(r)) {
      r.response.statusCode = HttpStatus.unauthorized;
      r.response.write('unauthorized');
      await r.response.close();
      return;
    }

    try {
      final uri = r.uri;
      if (r.method == 'GET' && uri.path == '/v1/health') {
        return Utils.writeJson(r, {
          'ok': true,
          'version': '0.1.0',
          'package': packageName,
          'port': (_server?.port ?? 0),
          'allowSchema': allowSchema
        });
      }

      if (r.method == 'GET' && uri.path == '/v1/databases') {
        final dbs = _provider.listDatabases();
        return Utils.writeJson(r, dbs);
      }

      if (r.method == 'GET' && uri.path == '/v1/tables') {
        final db = uri.queryParameters['db'];
        if (db == null) return Utils.writeBad(r, 'missing db');
        final withCount = (uri.queryParameters['withCount'] == '1');
        final res = _queries.tables(db, withCount: withCount);
        return Utils.writeJson(r, {'tables': res});
      }

      if (r.method == 'GET' && uri.path == '/v1/schema') {
        final db = uri.queryParameters['db'];
        final table = uri.queryParameters['table'];
        if (db == null || table == null) {
          return Utils.writeBad(r, 'missing db/table');
        }
        final res = _queries.schema(db, table);
        return Utils.writeJson(r, res);
      }

      if (r.method == 'GET' && uri.path == '/v1/data-version') {
        final db = uri.queryParameters['db'];
        if (db == null) return Utils.writeBad(r, 'missing db');
        final dv = _queries.dataVersion(db);
        return Utils.writeJson(r, {'dataVersion': dv});
      }

      if (r.method == 'POST' && uri.path == '/v1/query') {
        final body = await Utils.readJson(r);
        final db = body['db'] as String?;
        final sql = body['sql'] as String?;
        final params = (body['params'] as List?) ?? const [];
        final limit = (body['limit'] as int?) ?? 0;
        final offset = (body['offset'] as int?) ?? 0;
        if (db == null || sql == null) {
          return Utils.writeBad(r, 'missing db/sql');
        }
        final res =
            _queries.runSelect(db, sql, params, limit: limit, offset: offset);
        return Utils.writeJson(r, res);
      }

      if (r.method == 'POST' && uri.path == '/v1/exec') {
        final body = await Utils.readJson(r);
        final db = body['db'] as String?;
        final sql = body['sql'] as String?;
        final params = (body['params'] as List?) ?? const [];
        if (db == null || sql == null) {
          return Utils.writeBad(r, 'missing db/sql');
        }
        if (!allowSchema && _looksSchemaSql(sql)) {
          return Utils.writeBad(r, 'DDL not allowed');
        }
        final changes = _queries.runExec(db, sql, params);
        return Utils.writeJson(r, {'changes': changes});
      }

      if (r.method == 'POST' && uri.path == '/v1/batch') {
        final body = await Utils.readJson(r);
        final db = body['db'] as String?;
        final stmts = (body['statements'] as List?)?.cast<Map>() ?? const [];
        final doTx = (body['transaction'] as bool?) ?? true;
        if (db == null || stmts.isEmpty) {
          return Utils.writeBad(r, 'missing db/statements');
        }
        if (!allowSchema) {
          for (final s in stmts) {
            final sql = (s['sql'] as String?) ?? '';
            if (_looksSchemaSql(sql)) {
              return Utils.writeBad(r, 'DDL not allowed');
            }
          }
        }
        final changes = _queries.runBatch(db, stmts, doTx: doTx);
        return Utils.writeJson(r, {'changesTotal': changes});
      }

      if (r.method == 'POST' && uri.path == '/v1/config') {
        final body = await Utils.readJson(r);
        if (body.containsKey('allowSchema')) {
          allowSchema = body['allowSchema'] == true;
        }
        if (body.containsKey('token')) {
          // token can't be mutated per-instance in this simplified server: ignore
        }
        return Utils.writeJson(r, {'ok': true, 'allowSchema': allowSchema});
      }

      r.response.statusCode = HttpStatus.notFound;
      r.response.write('not found');
      await r.response.close();
    } catch (e) {
      r.response.statusCode = HttpStatus.internalServerError;
      r.response.write('error: $e');
      await r.response.close();
    }
  }

  bool _looksSchemaSql(String sql) {
    final s = sql.toUpperCase();
    const ddl = [
      'ALTER ',
      'CREATE ',
      'DROP ',
      'TRUNCATE ',
      'REINDEX ',
      'VACUUM '
    ];
    for (final k in ddl) {
      if (s.contains(k)) return true;
    }
    if (RegExp(r'\bPRAGMA\s+(JOURNAL_MODE|WAL|SYNCHRONOUS|ENCODING)\b')
        .hasMatch(s)) {
      return true;
    }
    return false;
  }
}
