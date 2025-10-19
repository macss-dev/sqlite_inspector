import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqlite_inspector/sqlite_inspector.dart'; // your local package

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    // Start the inspector in debug mode
    await SqliteInspector.start();
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Database? db1; // example.db
  Database? db2; // example2.db

  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() {
    super.initState();
    _initDatabases();
  }

  Future<void> _initDatabases() async {
    final dbPath = await getDatabasesPath();

    // === Primera base de datos: example.db ===
    final path1 = join(dbPath, 'example.db');
    db1 = await openDatabase(
      path1,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE notes(id INTEGER PRIMARY KEY, title TEXT, content TEXT)',
        );
        await db.insert('notes', {
          'title': 'First note',
          'content': 'Hello world!',
        });
        await db.insert('notes', {
          'title': 'Second note',
          'content': 'SQLite is cool.',
        });
      },
    );

    // === Segunda base de datos: example2.db ===
    final path2 = join(dbPath, 'example2.db');
    db2 = await openDatabase(
      path2,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE tasks(id INTEGER PRIMARY KEY, name TEXT, done INTEGER)',
        );
        await db.insert('tasks', {'name': 'Buy groceries', 'done': 0});
        await db.insert('tasks', {'name': 'Walk the dog', 'done': 1});
      },
    );

    // Cargar los datos iniciales
    await _loadNotes();
    await _loadTasks();
  }

  Future<void> _loadNotes() async {
    if (db1 == null) return;
    final data = await db1!.query('notes', orderBy: 'id');
    setState(() => notes = data);
  }

  Future<void> _loadTasks() async {
    if (db2 == null) return;
    final data = await db2!.query('tasks', orderBy: 'id');
    setState(() => tasks = data);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SQLite Inspector Test',
      home: Scaffold(
        appBar: AppBar(title: const Text('SQLite Example (Two DBs)')),
        body: notes.isEmpty && tasks.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  const ListTile(
                    title: Text(
                      'Notes from example.db',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...notes.map(
                    (n) => ListTile(
                      title: Text(n['title']),
                      subtitle: Text(n['content']),
                    ),
                  ),
                  const Divider(),
                  const ListTile(
                    title: Text(
                      'Tasks from example2.db',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...tasks.map(
                    (t) => CheckboxListTile(
                      title: Text(t['name']),
                      value: t['done'] == 1,
                      onChanged: null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
