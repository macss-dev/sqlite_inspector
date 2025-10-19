import 'package:sqlite3/sqlite3.dart';

import 'db_provider.dart';
import 'utils.dart';

/// Query executor helpers: select, exec, batch and metadata queries.
class Queries {
  final DbProvider provider;

  Queries(this.provider);

  Map<String, dynamic> runSelect(String dbName, String sql, List params,
      {int limit = 0, int offset = 0}) {
    var finalSql = sql;
    final bind = [...params];
    if (limit > 0) {
      finalSql =
          'SELECT * FROM ($sql) __t LIMIT ?${offset > 0 ? ' OFFSET ?' : ''}';
      bind.add(limit);
      if (offset > 0) bind.add(offset);
    }
    final db = provider.open(dbName);
    try {
      final stmt = db.prepare(finalSql);
      final rs = stmt.select(bind);
      final columns = rs.columnNames;
      final rows = <List<dynamic>>[];
      for (final Row row in rs) {
        rows.add(columns.map((c) => Utils.encodeCell(row[c])).toList());
      }
      stmt.dispose();
      return {
        'columns': columns,
        'rows': rows,
        'rowCount': rows.length,
        'truncated': false
      };
    } finally {
      db.dispose();
    }
  }

  int runExec(String dbName, String sql, List params) {
    final db = provider.open(dbName);
    try {
      final stmt = db.prepare(sql);
      stmt.execute(params);
      final changes = db.updatedRows;
      stmt.dispose();
      return changes;
    } finally {
      db.dispose();
    }
  }

  int runBatch(String dbName, List<Map> stmts, {required bool doTx}) {
    final db = provider.open(dbName);
    try {
      int changes = 0;
      void runAll() {
        for (final s in stmts) {
          final sql = (s['sql'] as String).trim();
          final params = (s['params'] as List?) ?? const [];
          final st = db.prepare(sql);
          st.execute(params);
          changes += db.updatedRows;
          st.dispose();
        }
      }

      if (doTx) {
        db.execute('BEGIN');
        try {
          runAll();
          db.execute('COMMIT');
        } catch (e) {
          db.execute('ROLLBACK');
          rethrow;
        }
      } else {
        runAll();
      }
      return changes;
    } finally {
      db.dispose();
    }
  }

  int dataVersion(String dbName) {
    final db = provider.open(dbName);
    try {
      final v = db.select('PRAGMA data_version').first.values.first as int;
      return v;
    } finally {
      db.dispose();
    }
  }

  List<Map<String, dynamic>> tables(String dbName, {bool withCount = false}) {
    final db = provider.open(dbName);
    try {
      final rs = db.select(
          "SELECT name, type FROM sqlite_master WHERE type IN ('table','view') AND name NOT LIKE 'sqlite_%' ORDER BY name");
      final out = <Map<String, dynamic>>[];
      for (final row in rs) {
        final m = {'name': row['name'], 'type': row['type']};
        if (withCount && (row['type'] == 'table')) {
          try {
            final c =
                db.select('SELECT COUNT(*) c FROM "${row['name']}"').first['c'];
            m['rowCount'] = c;
          } catch (_) {}
        }
        out.add(m);
      }
      return out;
    } finally {
      db.dispose();
    }
  }

  Map<String, dynamic> schema(String dbName, String table) {
    final db = provider.open(dbName);
    try {
      final create = db
              .select(
                  "SELECT sql FROM sqlite_master WHERE name = ? AND type IN ('table','view')",
                  [table])
              .map((r) => r['sql'] as String?)
              .firstOrNull ??
          '';
      final cols = db
          .select('PRAGMA table_info("$table")')
          .map((r) => {
                'cid': r['cid'],
                'name': r['name'],
                'type': r['type'],
                'notnull': r['notnull'],
                'dflt_value': r['dflt_value'],
                'pk': r['pk'],
              })
          .toList();
      final idxs = db
          .select('PRAGMA index_list("$table")')
          .map((r) => {
                'name': r['name'],
                'unique': r['unique'],
                'origin': r['origin'],
                'partial': r['partial'],
              })
          .toList();
      final fks = db
          .select('PRAGMA foreign_key_list("$table")')
          .map((r) => {
                'id': r['id'],
                'seq': r['seq'],
                'table': r['table'],
                'from': r['from'],
                'to': r['to'],
                'on_update': r['on_update'],
                'on_delete': r['on_delete'],
                'match': r['match'],
              })
          .toList();
      return {
        'createSql': create,
        'columns': cols,
        'indexes': idxs,
        'foreignKeys': fks,
      };
    } finally {
      db.dispose();
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
