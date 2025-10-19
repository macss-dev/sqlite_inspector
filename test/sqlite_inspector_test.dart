import 'dart:io';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_inspector/sqlite_inspector.dart'; // your package
import '_http.dart';

void main() {
  late Directory tempDir;
  late String dbPath;
  const port = 8123; // fixed port for tests
  final baseUrl = Uri.parse('http://127.0.0.1:$port');

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('sqlite_insp_test_');
    dbPath = '${tempDir.path}/appdata.db';
    // Create a test DB with data and a BLOB
    final db = sqlite3.open(dbPath);
    db.execute(
        'CREATE TABLE user(id INTEGER PRIMARY KEY, name TEXT, photo BLOB)');
    db.execute("INSERT INTO user(name, photo) VALUES ('Alice', x'DEADBEEF')");
    db.execute("INSERT INTO user(name, photo) VALUES ('Bob', NULL)");
    db.execute('CREATE VIEW v_users AS SELECT id, name FROM user');
    db.dispose();

    // Start the server pointing to tempDir as the "databases" directory
    Directory('${tempDir.path}/databases').createSync(recursive: true);
    File(dbPath).renameSync('${tempDir.path}/databases/appdata.db');
    dbPath = '${tempDir.path}/databases/appdata.db';
  });

  tearDownAll(() async {
    await SqliteInspector.stop();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Server without token (DDL OFF by default)', () {
    late HttpJson http;

    setUp(() async {
      // Ensure server is stopped if it was running from other tests
      await SqliteInspector.stop();
      await SqliteInspector.start(
        port: port,
        allowSchema: false,
        token: null,
        dbDirOverride: '${tempDir.path}/databases',
      );
      http = HttpJson(baseUrl);
    });

    test('health OK', () async {
      final h = await http.get('/v1/health');
      expect(h['ok'], true);
      expect(h['allowSchema'], false);
      expect(h['port'], port);
    });

    test('databases lists the DB', () async {
      final dbs = await http.get('/v1/databases');
      expect(dbs, isA<List>());
      final names = (dbs as List).map((e) => (e as Map)['name']).toList();
      expect(names, contains('appdata.db'));
    });

    test('tables and schema work', () async {
      final tables = await http.get('/v1/tables?db=appdata.db');
      final list = tables['tables'] as List;
      final tnames = list.map((e) => (e as Map)['name']).toSet();
      expect(tnames, containsAll(['user', 'v_users']));

      final schema = await http.get('/v1/schema?db=appdata.db&table=user');
      expect(schema['createSql'], contains('CREATE TABLE user'));
      final cols =
          (schema['columns'] as List).map((c) => (c as Map)['name']).toList();
      expect(cols, containsAll(['id', 'name', 'photo']));
    });

    test('SELECT query returns columns, rows and encoded BLOB', () async {
      final r = await http.post('/v1/query', {
        'db': 'appdata.db',
        'sql': 'SELECT id,name,photo FROM user ORDER BY id',
      });
      expect(r['columns'], ['id', 'name', 'photo']);
      expect(r['rowCount'], 2);

      final rows = (r['rows'] as List).cast<List>();
      // Row 1: photo is a BLOB -> object {"__blob__": base64, "length": N}
      final photo0 = (rows[0][2]) as Map?;
      expect(photo0, isA<Map>());
      expect(photo0!['__blob__'], isA<String>());
      expect(photo0['length'], isA<int>());
      // Row 2: NULL
      expect(rows[1][2], isNull);
    });

    test('exec INSERT changes rows', () async {
      final r = await http.post('/v1/exec', {
        'db': 'appdata.db',
        'sql': "INSERT INTO user(name,photo) VALUES('Carol', NULL)"
      });
      expect(r['changes'], greaterThanOrEqualTo(1));

      final q = await http.post('/v1/query',
          {'db': 'appdata.db', 'sql': 'SELECT COUNT(*) AS c FROM user'});
      final count = (q['rows'] as List).first.first;
      expect(count, 3);
    });

    test('transactional batch', () async {
      final r = await http.post('/v1/batch', {
        'db': 'appdata.db',
        'transaction': true,
        'statements': [
          {'sql': "INSERT INTO user(name,photo) VALUES('Dave', NULL)"},
          {'sql': "UPDATE user SET name='AliceX' WHERE name='Alice'"},
        ]
      });
      expect(r['changesTotal'], greaterThanOrEqualTo(2));

      final q = await http.post('/v1/query', {
        'db': 'appdata.db',
        'sql': "SELECT COUNT(*) FROM user WHERE name='AliceX'"
      });
      final n = (q['rows'] as List).first.first;
      expect(n, 1);
    });

    test('DDL is forbidden by default', () async {
      final status = await http.postExpectStatus('/v1/exec',
          {'db': 'appdata.db', 'sql': 'CREATE TABLE t_forbidden(x INT)'});
      expect(status,
          anyOf(400, 500)); // 400 "DDL not allowed" (o 500 si cambiaste manejo)
    });

    test('enable DDL via /config and then CREATE TABLE', () async {
      await http.post('/v1/config', {'allowSchema': true});
      final h = await http.get('/v1/health');
      expect(h['allowSchema'], true);

      final ok = await http.post(
          '/v1/exec', {'db': 'appdata.db', 'sql': 'CREATE TABLE t_ok(x INT)'});
      expect(ok['changes'],
          isA<int>()); // SQLite returns 0 changes for DDL; acceptable that it doesn't fail

      final tables = await http.get('/v1/tables?db=appdata.db');
      final names =
          (tables['tables'] as List).map((e) => (e as Map)['name']).toSet();
      expect(names, contains('t_ok'));
    });
  });

  group('Server with token', () {
    const token = 'secret';
    late HttpJson httpAuth;

    setUp(() async {
      await SqliteInspector.stop();
      await SqliteInspector.start(
        port: port,
        allowSchema: false,
        token: token,
        dbDirOverride: '${tempDir.path}/databases',
      );
      httpAuth = HttpJson(baseUrl, token: token);
    });

    test('without token => 401', () async {
      // Call manually to inspect status
      final client = HttpClient();
      final req = await client.getUrl(baseUrl.resolve('/v1/health'));
      final res = await req.close();
      await res.drain();
      expect(res.statusCode, 401);
    });

    test('with token => OK', () async {
      final h = await httpAuth.get('/v1/health');
      expect(h['ok'], true);
    });
  });
}
