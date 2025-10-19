[![pub package](https://img.shields.io/pub/v/sqlite_inspector.svg)](https://pub.dev/packages/sqlite_inspector)

# sqlite_inspector

**Alternative to Android Studio’s Database Inspector — lighter, portable, no Gradle or IDE dependency.**

> Dev-only HTTP inspector for on-device SQLite (debug).  
> Designed to be used together with the **VS Code extension “SQLite Inspector”** via `adb forward`.

---

## ✨ Features

- Minimal, dependency-free **HTTP server** based on `dart:io`.
- Works in **debug builds** of Flutter or pure Dart apps.
- Safe defaults:
  - Loopback-only (`127.0.0.1`) binding.
  - **DDL disabled** by default.
  - Optional token-based authentication.
- Explore on-device databases from VS Code or `curl`.
- REST endpoints for schema, tables, and data queries.
- Transactional DML (`INSERT / UPDATE / DELETE`).
- Batch execution with automatic rollback on error.

---

## 📦 Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  sqlite_inspector: ^0.0.1
````

Or from the command line:

```bash
dart pub add sqlite_inspector
dart pub get
```

---

## 🚀 Quick start

```dart
import 'package:flutter/foundation.dart';
import 'package:sqlite_inspector/sqlite_inspector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    // Start the inspector server on localhost:7111
    await SqliteInspector.start(); // DDL off by default
  }

  runApp(const MyApp());
}
```

Test from your host computer:

```bash
adb forward tcp:7111 tcp:7111
curl http://127.0.0.1:7111/v1/health
```

Expected output:

```json
{"ok":true,"version":"0.1.0","package":"com.example.app","port":7111,"allowSchema":false}
```

---

## 🧭 Endpoints

| Method | Path                             | Description                                |
| ------ | -------------------------------- | ------------------------------------------ |
| `GET`  | `/v1/health`                     | Inspector health & version info            |
| `GET`  | `/v1/databases`                  | List detected `.db` files                  |
| `GET`  | `/v1/tables?db=<name>`           | List tables / views                        |
| `GET`  | `/v1/schema?db=<name>&table=<t>` | Get CREATE TABLE + metadata                |
| `GET`  | `/v1/data-version?db=<name>`     | Current `PRAGMA data_version`              |
| `POST` | `/v1/query`                      | Run `SELECT`, returns JSON rows            |
| `POST` | `/v1/exec`                       | Execute DML (`INSERT`, `UPDATE`, `DELETE`) |
| `POST` | `/v1/batch`                      | Execute multiple statements atomically     |
| `POST` | `/v1/config`                     | Toggle DDL or set token at runtime         |

---

## 🧱 Example queries

### Query data

```bash
curl -X POST http://127.0.0.1:7111/v1/query \
     -H "Content-Type: application/json" \
     -d '{"db":"appdata.db","sql":"SELECT id,name FROM users LIMIT 5"}'
```

### Modify data

```bash
curl -X POST http://127.0.0.1:7111/v1/exec \
     -H "Content-Type: application/json" \
     -d '{"db":"appdata.db","sql":"INSERT INTO users(name) VALUES(?)","params":["Alice"]}'
```

### Enable DDL

```bash
curl -X POST http://127.0.0.1:7111/v1/config \
     -H "Content-Type: application/json" \
     -d '{"allowSchema":true}'
```

---

## 🔒 Security

* **Loopback-only** (`127.0.0.1`) — no external exposure.

* **DDL disabled** by default; enable explicitly via `/v1/config`.

* Optional header authentication:

  ```
  x-debug-token: my_secret
  ```

* Use only in `kDebugMode`; never ship in production builds.

---

## 🧪 Example project

`example/lib/main.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqlite_inspector/sqlite_inspector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    await SqliteInspector.start(); // default port 7111
  }

  runApp(const MaterialApp(home: ExampleHome()));
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('sqlite_inspector running in debug')),
    );
  }
}
```

---

## 🧩 Integration with VS Code

Install the companion **VS Code extension “SQLite Inspector”**:

1. Connect your device (`adb devices`).
2. Run your app in **debug**.
3. In VS Code: → Command Palette → `SQLite Inspector: Connect (ADB)`.
4. Browse databases, tables, and run SQL directly inside VS Code.

---

## 🧭 Roadmap

* Multi-platform support (Android, Desktop, iOS via iproxy).
* Live refresh via `PRAGMA data_version`.
* WebSocket streaming.
* Secure channel & token rotation.
* Possible Flutter Web proxy mode.

---

## 📄 License

MIT © [ccisne.dev](https://ccisne.dev)