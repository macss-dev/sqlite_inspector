# AGENTS.md — How to Use `sqlite_inspector`

Purpose: enable debug‑time inspection of on‑device SQLite databases via a tiny HTTP server embedded in your Flutter/Dart app. It is dev‑only, loopback‑bound, and designed to work with curl, scripts, or the VS Code “SQLite Inspector” extension.

## Capabilities
- Starts a local HTTP server (default `127.0.0.1:7111`).
- Lists databases, tables, and schema metadata.
- Executes `SELECT` and transactional DML (`INSERT/UPDATE/DELETE`).
- Optional token auth via `x-debug-token` header.
- DDL is blocked by default; can be toggled at runtime.

## Install
Add to your `pubspec.yaml` (dev only) and ensure the required SQLite libs:

```yaml
dependencies:
  sqlite3_flutter_libs: ^0.5.40

dev_dependencies:
  sqlite_inspector: ^0.0.3
```

Then fetch packages:

```bash
flutter pub get
```

## Start/Stop API
Import and start the server in debug builds only:

```dart
import 'package:flutter/foundation.dart';
import 'package:sqlite_inspector/sqlite_inspector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    await SqliteInspector.start(
      // Optional:
      // port: 7111,
      // allowSchema: false,
      // token: 'my_secret',
      // dbDirOverride: null, // e.g., a desktop test folder
    );
  }

  runApp(const MyApp());
}
```

- `SqliteInspector.start({port=7111, allowSchema=false, token, dbDirOverride})`
- `SqliteInspector.stop()`
- `SqliteInspector.isRunning`

Database directory resolution:
- Android defaults: `/data/user/0/<package>/databases` or `/data/data/<package>/databases`.
- If unresolved, uses a temporary directory.
- For desktop/tests, pass `dbDirOverride` to point at a local folder.

## Verify Locally (Android)
Forward the device port and hit health:

```bash
adb forward tcp:7111 tcp:7111
curl http://127.0.0.1:7111/v1/health
```

Expected JSON:

```json
{"ok":true,"version":"0.1.0","package":"<pkg>","port":7111,"allowSchema":false}
```

If `token` is set, include `-H 'x-debug-token: <token>'` in all requests.

## HTTP Endpoints
Base URL: `http://127.0.0.1:<port>`

- GET `/v1/health` → `{ ok, version, package, port, allowSchema }`
- GET `/v1/databases` → `[{ name, path, sizeBytes }]`
- GET `/v1/tables?db=<name>[&withCount=1]` → `{ tables: [{ name, type, rowCount? }] }`
- GET `/v1/schema?db=<name>&table=<t>` → `{ createSql, columns, indexes, foreignKeys }`
- GET `/v1/data-version?db=<name>` → `{ dataVersion }`
- POST `/v1/query` → body `{ db, sql, params?, limit?, offset? }` → `{ columns, rows, rowCount, truncated }`
- POST `/v1/exec` → body `{ db, sql, params? }` → `{ changes }`
- POST `/v1/batch` → body `{ db, statements: [{ sql, params? }...], transaction?: true }` → `{ changesTotal }`
- POST `/v1/config` → body `{ allowSchema?: bool }` → `{ ok, allowSchema }`

Authentication (optional): add header `x-debug-token: <token>` if configured.

### Request/Response Examples
Query data:

```bash
curl -X POST http://127.0.0.1:7111/v1/query \
  -H 'Content-Type: application/json' \
  -d '{"db":"appdata.db","sql":"SELECT id,name FROM users LIMIT 5"}'
```

Modify data:

```bash
curl -X POST http://127.0.0.1:7111/v1/exec \
  -H 'Content-Type: application/json' \
  -d '{"db":"appdata.db","sql":"INSERT INTO users(name) VALUES(?)","params":["Alice"]}'
```

Batch statements (transactional):

```bash
curl -X POST http://127.0.0.1:7111/v1/batch \
  -H 'Content-Type: application/json' \
  -d '{
    "db":"appdata.db",
    "transaction":true,
    "statements":[
      {"sql":"UPDATE users SET name=? WHERE id=?","params":["Bob",1]},
      {"sql":"DELETE FROM users WHERE id=?","params":[2]}
    ]
  }'
```

Enable DDL at runtime:

```bash
curl -X POST http://127.0.0.1:7111/v1/config \
  -H 'Content-Type: application/json' \
  -d '{"allowSchema":true}'
```

### Data Encoding Notes
- BLOB values are returned as `{ "__blob__": base64, "length": N }`.
- Non‑map JSON request bodies are rejected with `400`.

## Behavior and Errors
- Binding: loopback only (`127.0.0.1`). No remote exposure.
- Auth: if `token` is set and header is missing/invalid → `401 unauthorized`.
- Validation failures → `400 bad request`.
- Unknown route → `404 not found`.
- Unhandled exception → `500 error: <message>`.
- DDL guard: when `allowSchema=false`, statements containing `ALTER/CREATE/DROP/TRUNCATE/REINDEX/VACUUM` or sensitive `PRAGMA` are rejected with `400`.

## VS Code Integration
- Install the VS Code extension “SQLite Inspector”.
- Connect device (`adb devices`) and run your app in debug.
- Command Palette → `SQLite Inspector: Connect (ADB)`.
- Browse databases, tables, and run SQL from VS Code.

## Security Guidelines
- Use only in `kDebugMode`. Do not include or start it in release builds.
- Prefer setting a `token` when running on shared machines.
- Keep `allowSchema=false` unless you explicitly need schema changes.

## Agent Checklist
- Ensure `sqlite3_flutter_libs >= 0.5.40` is present.
- Start server in debug mode via `SqliteInspector.start(...)`.
- If on Android, run `adb forward tcp:7111 tcp:7111` to access from host.
- Include `x-debug-token` if configured.
- Use the documented endpoints to list DBs, inspect schema, and run queries.
- Stop the server via `SqliteInspector.stop()` when done (optional during app shutdown).

